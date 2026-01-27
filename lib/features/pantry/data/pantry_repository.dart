import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/offline_manager.dart';
import '../../../../core/services/sync_queue_service.dart';
import 'models/pantry_item_model.dart';

part 'pantry_repository.g.dart';

@riverpod
PantryRepository pantryRepository(PantryRepositoryRef ref) {
  return PantryRepository(
    Supabase.instance.client,
    ref.read(syncQueueServiceProvider),
    ref.read(offlineManagerProvider),
  );
}

class PantryRepository {
  final SupabaseClient _client;
  final SyncQueueService _syncQueueService;
  final OfflineManager _offlineManager;

  PantryRepository(this._client, this._syncQueueService, this._offlineManager);

  // Offline-First: Stream from Local DB
  Stream<List<Map<String, dynamic>>> watchPantryItems(
      {String? householdId}) async* {
    final box = Hive.box<PantryItemModel>('pantry_items');

    // Emit initial value
    yield _boxToMapList(box, householdId);

    // Emit updates
    yield* box.watch().map((_) {
      return _boxToMapList(box, householdId);
    });
  }

  // Sync: Fetch Remote -> Update Local
  Future<void> syncPantryItems() async {
    try {
      final response = await _client
          .from('pantry_items')
          .select()
          .order('created_at', ascending: false);

      final remoteItems = List<Map<String, dynamic>>.from(response);
      final box = Hive.box<PantryItemModel>('pantry_items');

      // Preserve local-only items (temp IDs) that haven't synced yet
      final tempItems =
          box.values.where((i) => i.id.startsWith('temp_')).toList();

      await box.clear();

      final models =
          remoteItems.map((json) => PantryItemModel.fromJson(json)).toList();
      await box.addAll(models);

      // Deduplicate: Remove temp items that match incoming remote items (by name)
      final uniqueTempItems = tempItems.where((temp) {
        final isDuplicate = remoteItems.any((remote) {
          final remoteName = (remote['name'] ?? '').toString().toLowerCase();
          final tempName = temp.name.toLowerCase();
          // Pantry doesn't usually use household, but if it did, we'd check it.
          // For now, assume User ID is implicit filter so name match is enough.
          return remoteName == tempName;
        });
        return !isDuplicate;
      }).toList();

      await box.addAll(uniqueTempItems);
    } catch (e) {
      // If sync fails (offline), we just silently fail and keep local data
      // Rethrow if you want UI to show a toast, but usually we just want silent sync
      // unless it is an explicit user "refresh" action.
      rethrow;
    }
  }

  List<Map<String, dynamic>> _boxToMapList(
      Box<PantryItemModel> box, String? householdId) {
    // Sort by created_at desc to match server order
    final items = box.values.toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Optional: Filter if we want separate personal/household views,
    // but typically pantry is unified or filtered by UI.
    // If householdId is provided, should we SHOW shared items?
    // User request implies they are "Adding to household".
    // If we filter, we need to match logic.
    // Assuming we want to show everything unless specifically filtered.
    // But consistent with Vault, let's filter if param provided?
    // Actually, usually we want to see My Personal + My Household.
    // Let's filter: Show if mine OR (in my household).
    // But 'householdId' param usually implies "Show items for this household".
    // Let's keep it simple: if valid householdId is passed, include items with that ID.
    // AND include items with NO householdId (personal)? Or separate?
    // ChefMind logic seems to be "Personal Vault" vs "Household Vault".
    // Pantry is usually unified.
    // Let's just return all for now to avoid hiding items,
    // UNLESS we want to strictly filter.
    // Given the previous code didn't filter, let's return all but now include householdId in JSON.
    // Wait, if I'm offline, I need to see the items I just added with householdId.

    return items.map((e) => e.toJson()).toList();
  }

  // Legacy/Direct fetch support (optional, can delegate to sync)
  Future<List<Map<String, dynamic>>> getPantryItems() async {
    await syncPantryItems();
    return _boxToMapList(Hive.box<PantryItemModel>('pantry_items'), null);
  }

  // FIXED Batch Implementation
  Future<void> addIngredients_Batch(List<String> ingredients) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final List<Map<String, dynamic>> payload = [];
    final box = Hive.box<PantryItemModel>('pantry_items');

    for (var name in ingredients) {
      final newId = const Uuid().v4();
      payload.add({
        'id': newId,
        'user_id': userId,
        'name': name,
        'category': 'Uncategorized',
      });

      // Optimistic
      box.add(PantryItemModel(
        id: newId,
        userId: userId,
        name: name,
        category: 'Uncategorized',
        createdAt: DateTime.now(),
      ));
    }

    if (!_offlineManager.hasConnection) {
      for (var item in payload) {
        await _syncQueueService.queueOperation('pantry_items', 'upsert', item);
      }
      return;
    }

    try {
      await _client.from('pantry_items').upsert(payload);
    } catch (_) {
      for (var item in payload) {
        await _syncQueueService.queueOperation('pantry_items', 'upsert', item);
      }
    }

    // No need to re-sync immediately if we used correct UUIDs
  }

  Future<String> addIngredient(String name, String category,
      {String? imageUrl}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return '';

    // Optimistic Update
    final box = Hive.box<PantryItemModel>('pantry_items');
    final newId = const Uuid().v4(); // Valid UUID
    final model = PantryItemModel(
      id: newId,
      userId: userId,
      name: name,
      category: category,
      createdAt: DateTime.now(),
      imageUrl: imageUrl,
    );
    box.add(model);

    final payload = {
      'id': newId, // Allow client to specify ID
      'user_id': userId,
      'name': name,
      'category': category,
      'image_url': imageUrl,
    };

    if (!_offlineManager.hasConnection) {
      await _syncQueueService.queueOperation('pantry_items', 'upsert', payload);
      return newId;
    }

    try {
      await _client.from('pantry_items').upsert(payload);
      // No need to sync immediately if we trust our generated ID
      // await syncPantryItems();
    } catch (_) {
      // Fallback to queue if network fails
      await _syncQueueService.queueOperation('pantry_items', 'upsert', payload);
    }
    return newId;
  }

  Future<void> updateImage(String id, String imageUrl) async {
    final box = Hive.box<PantryItemModel>('pantry_items');
    try {
      final item = box.values.firstWhere((e) => e.id == id);
      // Create copy with new image
      final newItem = PantryItemModel(
        id: item.id,
        userId: item.userId,
        name: item.name,
        category: item.category,
        createdAt: item.createdAt,
        householdId: item.householdId,
        imageUrl: imageUrl,
      );
      if (item.key != null) await box.put(item.key, newItem);
    } catch (_) {}

    // Remote Update
    // Only proceed if ID is NOT temporary
    if (!id.startsWith('temp_')) {
      if (!_offlineManager.hasConnection) {
        await _syncQueueService.queueOperation('pantry_items', 'update', {
          'id': id,
          'image_url': imageUrl,
        });
        return;
      }

      try {
        await _client
            .from('pantry_items')
            .update({'image_url': imageUrl}).eq('id', id);
      } catch (_) {
        await _syncQueueService.queueOperation('pantry_items', 'update', {
          'id': id,
          'image_url': imageUrl,
        });
      }
    }
  }

  Future<void> deleteItem(String id) async {
    // Optimistic Delete
    // Finding the key is tricky if ID is remote string.
    // Hive keys are usually auto-increment int if using add(), or we can useput(id, val).
    // Our sync uses addAll so keys are ints.
    // We filter by content ID.

    final box = Hive.box<PantryItemModel>('pantry_items');
    final itemToDelete = box.values.firstWhere((e) => e.id == id,
        orElse: () =>
            // Return dummy if not found to prevent crash
            PantryItemModel(
                id: '',
                userId: '',
                name: '',
                category: '',
                createdAt: DateTime.now()));

    if (itemToDelete.id.isNotEmpty && itemToDelete.isInBox) {
      await itemToDelete.delete();
    }

    if (!_offlineManager.hasConnection) {
      // If ID is int (local only temp ID), we don't queue delete for server?
      // But here ID is usually String (remote ID) for existing items.
      // If we just added it offline, it has a temp ID.
      // If we try to delete a temp item, we should cancel its 'insert' op in queue if possible.
      // But simple approach: Queue delete. If ID is garbage, server ignores it.
      // BETTER: Check if ID is likely valid UUID or Int.
      // Current PantryItemModel adapter reads ID as String.
      await _syncQueueService
          .queueOperation('pantry_items', 'delete', {'id': id});
      return;
    }

    try {
      await _client.from('pantry_items').delete().eq('id', id);
    } catch (_) {
      await _syncQueueService
          .queueOperation('pantry_items', 'delete', {'id': id});
    }
    // sync not strictly needed if delete successful, but good assurance
    // await syncPantryItems();
  }
}
