import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'models/sync_operation_model.dart';

part 'sync_queue_service.g.dart';

@Riverpod(keepAlive: true)
SyncQueueService syncQueueService(SyncQueueServiceRef ref) {
  return SyncQueueService(Supabase.instance.client);
}

class SyncQueueService {
  final SupabaseClient _client;
  static const String _boxName = 'sync_queue';

  SyncQueueService(this._client);

  Future<void> init() async {
    if (!Hive.isAdapterRegistered(200)) {
      Hive.registerAdapter(SyncOperationAdapter());
    }
    await Hive.openBox<SyncOperation>(_boxName);
  }

  Future<void> queueOperation(
      String table, String action, Map<String, dynamic> payload) async {
    final box = Hive.box<SyncOperation>(_boxName);
    final op = SyncOperation(
      id: const Uuid().v4(),
      table: table,
      action: action,
      payload: payload,
      timestamp: DateTime.now(),
    );
    await box.add(op);
    print("Offline Op Queued: $action on $table");
  }

  Future<void> processQueue() async {
    final box = Hive.box<SyncOperation>(_boxName);
    print(
        "DEBUG SyncQueue: Checking queue... ${box.length} operations pending.");
    if (box.isEmpty) {
      print("DEBUG SyncQueue: Queue is empty, nothing to process.");
      return;
    }

    print("DEBUG SyncQueue: Processing ${box.length} operations...");

    // Process in order
    final ops = box.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final op in ops) {
      try {
        print(
            "DEBUG SyncQueue: Processing op ${op.id} - ${op.action} on ${op.table}");
        print("DEBUG SyncQueue: Payload = ${op.payload}");
        await _performOperation(op);
        await op.delete(); // Remove from queue on success
        print("DEBUG SyncQueue: Op ${op.id} SUCCESS");
      } catch (e) {
        print("Sync Failed for Op ${op.id}: $e");

        // FIX: Discard operations with invalid UUID syntax (legacy temp IDs or BigInt mismatch)
        // Code 22P02 is Postgres "invalid input syntax"
        final msg = e.toString();
        if (msg.contains('22P02')) {
          if (msg.contains('temp_') ||
              (msg.contains('type bigint') && op.table == 'shopping_cart')) {
            print(
                "DEBUG SyncQueue: Discarding invalid legacy op ${op.id} to unblock queue.");
            await op.delete();
            continue; // Proceed to next op
          }
        }

        // Decide: Stop? Skip? Retry later?
        // For now, we stop to preserve order dependency.
        return;
      }
    }
    print("Sync Queue Processed.");
  }

  Future<void> _performOperation(SyncOperation op) async {
    final query = _client.from(op.table);

    // 1. Recursive Clean: convert any "null" strings to actual nulls
    // 2. Wrap in Map.from to ensure it's mutable
    final payload = _cleanPayload(Map<String, dynamic>.from(op.payload));

    bool isInvalidId(dynamic val) =>
        val == null || val.toString() == "null" || val.toString().isEmpty;

    switch (op.action) {
      case 'insert':
        await query.insert(payload);
        break;
      case 'update':
        final id = payload['id'];
        if (!isInvalidId(id)) {
          await query.update(payload).eq('id', id);
        } else {
          print(
              "SyncQueue: Skipping update on ${op.table} due to invalid ID: $id");
        }
        break;
      case 'upsert':
        await query.upsert(payload);
        break;
      case 'delete':
        // Handle optional storage cleanup if path is provided
        final storagePath = payload['image_path'];
        if (storagePath != null && storagePath.toString().isNotEmpty) {
          try {
            print(
                "SyncQueue: Cleaning up storage for deleted item: $storagePath");
            await _client.storage
                .from('images')
                .remove([storagePath.toString()]);
          } catch (e) {
            print("SyncQueue: Storage cleanup failed (non-critical): $e");
          }
        }

        if (op.table == 'saved_recipes') {
          final targetId = payload['recipe_id'] ?? payload['id'];
          if (!isInvalidId(targetId)) {
            await query.delete().eq('recipe_id', targetId);
          } else {
            print(
                "SyncQueue: Skipping delete on saved_recipes due to invalid ID: $targetId");
          }
          break;
        }

        final id = payload['id'];
        if (!isInvalidId(id)) {
          await query.delete().eq('id', id);
        } else {
          print(
              "SyncQueue: Skipping delete on ${op.table} due to invalid ID: $id");
        }
        break;
      case 'delete_by_recipe_id':
        // Handle optional storage cleanup
        final storagePath = payload['image_path'];
        if (storagePath != null && storagePath.toString().isNotEmpty) {
          try {
            print(
                "SyncQueue: Cleaning up storage for deleted item: $storagePath");
            await _client.storage
                .from('images')
                .remove([storagePath.toString()]);
          } catch (e) {
            print("SyncQueue: Storage cleanup failed (non-critical): $e");
          }
        }

        final recipeId = payload['recipe_id'];
        if (!isInvalidId(recipeId)) {
          await query.delete().eq('recipe_id', recipeId);
        } else {
          print(
              "SyncQueue: Skipping delete_by_recipe_id due to invalid recipeId: $recipeId");
        }
        break;
      case 'rpc':
        final func = payload['_rpc_function'];
        payload.remove('_rpc_function');
        if (func != null) {
          await _client.rpc(func, params: payload);
        }
        break;
    }
  }

  Map<String, dynamic> _cleanPayload(Map<String, dynamic> payload) {
    return payload.map((key, value) {
      if (value is String && value == "null") {
        return MapEntry(key, null);
      }
      if (value is Map<String, dynamic>) {
        return MapEntry(key, _cleanPayload(value));
      }
      if (value is List) {
        return MapEntry(
            key,
            value
                .map((e) => e is Map<String, dynamic>
                    ? _cleanPayload(e)
                    : (e == "null" ? null : e))
                .toList());
      }
      return MapEntry(key, value);
    });
  }
}
