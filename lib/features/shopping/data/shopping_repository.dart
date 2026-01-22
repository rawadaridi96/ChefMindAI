import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/offline_manager.dart';
import '../../../../core/services/sync_queue_service.dart';

import 'models/shopping_item_model.dart';

part 'shopping_repository.g.dart';

@Riverpod(keepAlive: true)
ShoppingRepository shoppingRepository(ShoppingRepositoryRef ref) {
  final repo = ShoppingRepository(
    Supabase.instance.client,
    ref.read(syncQueueServiceProvider),
    ref.read(offlineManagerProvider),
  );
  // Subscribe to realtime once when repository is created
  repo.subscribeToRealtime();
  return repo;
}

class ShoppingRepository {
  final SupabaseClient _client;
  final SyncQueueService _syncQueueService;
  final OfflineManager _offlineManager;

  ShoppingRepository(
      this._client, this._syncQueueService, this._offlineManager);

  // Offline-First: Stream from Local DB
  Stream<List<Map<String, dynamic>>> watchCartItems(
      {String? householdId}) async* {
    final box = Hive.box<ShoppingItemModel>('shopping_items');

    // Emit initial
    yield _filterBox(box, householdId);

    // Emit updates
    yield* box.watch().map((_) {
      return _filterBox(box, householdId);
    });
  }

  List<Map<String, dynamic>> _filterBox(
      Box<ShoppingItemModel> box, String? householdId) {
    final items = box.values.toList();
    // Sort by isBought asc, then createdAt desc
    items.sort((a, b) {
      if (a.isBought != b.isBought) return a.isBought ? 1 : -1;
      return b.createdAt.compareTo(a.createdAt);
    });

    return items
        .where((i) => householdId != null
            ? i.householdId == householdId
            : i.householdId == null)
        .map((e) => e.toJson())
        .toList();
  }

  StreamSubscription? _realtimeSubscription;

  // Sync
  Future<void> syncCartItems() async {
    try {
      // Fetch ALL items for this user (RLS filters rows)
      final response = await _client.from('shopping_cart').select();
      final remoteItems = List<Map<String, dynamic>>.from(response);
      await _updateLocalBoxFromRemote(remoteItems);

      // Fallback: If sync succeeded, we're definitely online.
      // Process any queued operations (connectivity detection may be unreliable)
      print(
          "DEBUG syncCartItems: Sync succeeded, processing any pending queue...");
      await _syncQueueService.processQueue();
    } catch (e) {
      print("DEBUG syncCartItems: Sync failed (likely offline): $e");
      // Don't rethrow on sync fail (offline), just silent
    }
  }

  void subscribeToRealtime() {
    if (_realtimeSubscription != null) return;

    print("DEBUG Realtime: Subscribing to shopping_cart stream...");
    _realtimeSubscription = _client
        .from('shopping_cart')
        .stream(primaryKey: ['id']).listen((remoteItems) {
      print("DEBUG Realtime: Received ${remoteItems.length} items from stream");
      _updateLocalBoxFromRemote(remoteItems);
    }, onError: (e) {
      print("Realtime Error: $e");
    });
  }

  void unsubscribeRealtime() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
  }

  Future<void> _updateLocalBoxFromRemote(
      List<Map<String, dynamic>> remoteItems) async {
    final box = Hive.box<ShoppingItemModel>('shopping_items');

    // Preserve local-only items (temp IDs) that haven't synced yet
    final tempItems =
        box.values.where((i) => i.id.startsWith('temp_')).toList();

    await box.clear();

    final models =
        remoteItems.map((json) => ShoppingItemModel.fromJson(json)).toList();
    await box.addAll(models);

    // Deduplicate: Remove temp items that match incoming remote items (by name + household)
    final uniqueTempItems = tempItems.where((temp) {
      final isDuplicate = remoteItems.any((remote) {
        final remoteName = (remote['item_name'] ?? '').toString().toLowerCase();
        final tempName = temp.itemName.toLowerCase();
        final remoteHousehold = remote['household_id'];
        final tempHousehold = temp.householdId;

        // Match if names are same AND household context is same
        return remoteName == tempName && remoteHousehold == tempHousehold;
      });
      return !isDuplicate;
    }).toList();

    // Create NEW instances to avoid HiveObject key conflicts
    // (Old instances still reference their previous keys after box.clear())
    final freshTempItems = uniqueTempItems
        .map((old) => ShoppingItemModel(
              id: old.id,
              userId: old.userId,
              itemName: old.itemName,
              amount: old.amount,
              isBought: old.isBought,
              recipeSource: old.recipeSource,
              householdId: old.householdId,
              createdAt: old.createdAt,
            ))
        .toList();

    await box.addAll(freshTempItems);
  }

  // Legacy fetch (helper)
  Future<List<Map<String, dynamic>>> getItems() async {
    await syncCartItems();
    final box = Hive.box<ShoppingItemModel>('shopping_items');
    return box.values.map((e) => e.toJson()).toList(); // No filtering?
    // Actually getItems isn't used much if we stream.
  }

  Future<void> addItem(String name, String amount, String category,
      {String? recipeSource, String? householdId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    // Optimistic Hive
    final box = Hive.box<ShoppingItemModel>('shopping_items');
    final tempId = "temp_${DateTime.now().millisecondsSinceEpoch}";
    final model = ShoppingItemModel(
      id: tempId,
      userId: userId,
      itemName: name,
      amount: amount,
      isBought: false,
      householdId: householdId,
      recipeSource: recipeSource,
      createdAt: DateTime.now(),
    );
    box.add(model);

    final data = {
      'user_id': userId,
      'item_name': name,
      'amount': amount,
      'category': category,
      'is_bought': false,
      if (householdId != null) 'household_id': householdId,
      if (recipeSource != null) 'recipe_source': recipeSource,
    };

    // Remote or Queue
    if (!_offlineManager.hasConnection) {
      print("DEBUG Repo addItem: OFFLINE - Queuing insert. Data: $data");
      await _syncQueueService.queueOperation('shopping_cart', 'insert', data);
      return;
    }

    print("DEBUG Repo addItem: ONLINE - Inserting directly. Data: $data");

    try {
      await _client.from('shopping_cart').insert(data);
      await syncCartItems();
    } catch (_) {
      // Fallback to queue on failure
      await _syncQueueService.queueOperation('shopping_cart', 'insert', data);
    }
  }

  Future<void> updateAmount(dynamic id, String newAmount) async {
    // Optimistic
    final box = Hive.box<ShoppingItemModel>('shopping_items');
    final strId = id.toString();
    try {
      print(
          "RefDebug: updateAmount called with id: $id (${id.runtimeType}), newAmount: $newAmount");
      final item = box.values.firstWhere((e) => e.id == strId);
      // We can't modify HiveObject fields directly if they are final.
      // We need to replace the object OR make fields mutable in model.
      // My model fields are final. So replace.
      final newItem = ShoppingItemModel(
          id: item.id,
          userId: item.userId,
          itemName: item.itemName,
          amount: newAmount,
          isBought: item.isBought,
          recipeSource: item.recipeSource,
          householdId: item.householdId,
          createdAt: item.createdAt);
      // Replace in box?
      // box.put(item.key, newItem); // .key is available on HiveObject
      // If item is HiveObject, it has .key
      final key = item.key;
      if (key != null) await box.put(key, newItem);
    } catch (_) {}

    if (id is int || int.tryParse(strId) != null) {
      // Ensure we use the numeric ID for backend operations
      final intId = id is int ? id : int.parse(strId);

      if (!_offlineManager.hasConnection) {
        await _syncQueueService.queueOperation(
            'shopping_cart', 'update', {'id': intId, 'amount': newAmount});
        return;
      }
      try {
        await _client
            .from('shopping_cart')
            .update({'amount': newAmount}).eq('id', intId);
      } catch (_) {
        await _syncQueueService.queueOperation(
            'shopping_cart', 'update', {'id': intId, 'amount': newAmount});
      }
    }
    // No sync needed if update worked, but alignment is good.
  }

  Future<void> updateAmountAndSource(dynamic id, String newAmount,
      {String? newSource}) async {
    final box = Hive.box<ShoppingItemModel>('shopping_items');
    final strId = id.toString();
    try {
      final item = box.values.firstWhere((e) => e.id == strId);
      final newItem = ShoppingItemModel(
          id: item.id,
          userId: item.userId,
          itemName: item.itemName,
          amount: newAmount,
          isBought: item.isBought,
          recipeSource: newSource ?? item.recipeSource,
          householdId: item.householdId,
          createdAt: item.createdAt);
      if (item.key != null) await box.put(item.key, newItem);
    } catch (e) {
      print("Error updating amount in Hive: $e");
    }

    final Map<String, dynamic> updates = {'amount': newAmount};
    if (newSource != null) {
      updates['recipe_source'] = newSource;
    }

    if (id is int || int.tryParse(strId) != null) {
      final intId = id is int ? id : int.parse(strId);
      if (!_offlineManager.hasConnection) {
        final payload = {'id': intId, ...updates};
        await _syncQueueService.queueOperation(
            'shopping_cart', 'update', payload);
        return;
      }
      try {
        await _client.from('shopping_cart').update(updates).eq('id', intId);
      } catch (_) {
        final payload = {'id': intId, ...updates};
        await _syncQueueService.queueOperation(
            'shopping_cart', 'update', payload);
      }
    }
  }

  Future<void> toggleStatus(dynamic id, bool isBought) async {
    final box = Hive.box<ShoppingItemModel>('shopping_items');
    final strId = id.toString();
    try {
      final item = box.values.firstWhere((e) => e.id == strId);
      final newItem = ShoppingItemModel(
          id: item.id,
          userId: item.userId,
          itemName: item.itemName,
          amount: item.amount,
          isBought: isBought,
          recipeSource: item.recipeSource,
          householdId: item.householdId,
          createdAt: item.createdAt);
      if (item.key != null) await box.put(item.key, newItem);
    } catch (_) {}

    if (id is int || int.tryParse(strId) != null) {
      final intId = id is int ? id : int.parse(strId);

      if (!_offlineManager.hasConnection) {
        await _syncQueueService.queueOperation(
            'shopping_cart', 'update', {'id': intId, 'is_bought': isBought});
        return;
      }
      try {
        await _client
            .from('shopping_cart')
            .update({'is_bought': isBought}).eq('id', intId);
      } catch (_) {
        await _syncQueueService.queueOperation(
            'shopping_cart', 'update', {'id': intId, 'is_bought': isBought});
      }
    }
  }

  Future<void> deleteItem(dynamic id) async {
    final box = Hive.box<ShoppingItemModel>('shopping_items');
    final strId = id.toString();
    try {
      final item = box.values.firstWhere((e) => e.id == strId);
      await box.delete(item.key);
    } catch (_) {}

    if (id is int || int.tryParse(strId) != null) {
      final intId = id is int ? id : int.parse(strId);
      if (!_offlineManager.hasConnection) {
        await _syncQueueService
            .queueOperation('shopping_cart', 'delete', {'id': intId});
        return;
      }
      try {
        await _client.from('shopping_cart').delete().eq('id', intId);
      } catch (_) {
        await _syncQueueService
            .queueOperation('shopping_cart', 'delete', {'id': intId});
      }
    }
  }

  Future<void> clearBoughtItems({String? householdId}) async {
    // Local Clear
    final box = Hive.box<ShoppingItemModel>('shopping_items');
    final itemsToDelete = box.values.where((i) {
      if (!i.isBought) return false;
      if (householdId != null) return i.householdId == householdId;
      return i.householdId == null;
    }).toList();

    final keysToDelete = itemsToDelete.map((e) => e.key).toList();
    await box.deleteAll(keysToDelete);

    // Remote Clear or Queue
    if (!_offlineManager.hasConnection) {
      for (final item in itemsToDelete) {
        // Only queue if ID is likely remote (not temp)
        // Similar check to deleteItem (int vs String ID logic)
        // If ID is int (from old DB), we treat as valid to try deleting.
        if (!item.id.toString().startsWith('temp_')) {
          await _syncQueueService
              .queueOperation('shopping_cart', 'delete', {'id': item.id});
        }
      }
      return;
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    var query = _client.from('shopping_cart').delete().eq('is_bought', true);
    if (householdId != null) {
      await query.eq('household_id', householdId);
    } else {
      await query.eq('user_id', userId).filter('household_id', 'is', 'null');
    }
  }

  Future<void> clearAllItems({String? householdId}) async {
    final box = Hive.box<ShoppingItemModel>('shopping_items');
    final itemsToDelete = box.values.where((i) {
      if (householdId != null) return i.householdId == householdId;
      return i.householdId == null;
    }).toList();

    final keysToDelete = itemsToDelete.map((e) => e.key).toList();
    await box.deleteAll(keysToDelete);

    if (!_offlineManager.hasConnection) {
      for (final item in itemsToDelete) {
        if (!item.id.toString().startsWith('temp_')) {
          await _syncQueueService
              .queueOperation('shopping_cart', 'delete', {'id': item.id});
        }
      }
      return;
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    var query = _client.from('shopping_cart').delete();
    if (householdId != null) {
      await query.eq('household_id', householdId);
    } else {
      await query.eq('user_id', userId).filter('household_id', 'is', 'null');
    }
  }
}
