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
        // Decide: Stop? Skip? Retry later?
        // For now, we stop to preserve order dependency.
        return;
      }
    }
    print("Sync Queue Processed.");
  }

  Future<void> _performOperation(SyncOperation op) async {
    final query = _client.from(op.table);

    switch (op.action) {
      case 'insert':
        await query.insert(Map<String, dynamic>.from(op.payload));
        break;
      case 'update':
        // Expecting 'id' in payload to identify row
        final id = op.payload['id'];
        if (id != null) {
          // Remove ID from update payload if strictly update?
          // For simplicity we pass payload.
          await query
              .update(Map<String, dynamic>.from(op.payload))
              .eq('id', id);
        }
        break;
      case 'upsert':
        await query.upsert(Map<String, dynamic>.from(op.payload));
        break;
      case 'delete':
        final id = op.payload['id'];
        if (id != null) {
          await query.delete().eq('id', id);
        }
        break;
      case 'delete_by_recipe_id':
        // Special case for saved_recipes which uses recipe_id as identifier
        final recipeId = op.payload['recipe_id'];
        if (recipeId != null) {
          await query.delete().eq('recipe_id', recipeId);
        }
        break;
      case 'rpc':
        // Payload should have 'function_name' and 'params'
        final func = op.payload['_rpc_function'];
        final params = Map<String, dynamic>.from(op.payload)
          ..remove('_rpc_function');
        if (func != null) {
          await _client.rpc(func, params: params);
        }
        break;
    }
  }
}
