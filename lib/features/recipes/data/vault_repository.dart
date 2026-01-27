import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/offline_manager.dart';
import '../../../../core/services/sync_queue_service.dart';

import 'models/saved_recipe_model.dart';

part 'vault_repository.g.dart';

@Riverpod(keepAlive: true)
VaultRepository vaultRepository(VaultRepositoryRef ref) {
  final repo = VaultRepository(
    Supabase.instance.client,
    ref.read(syncQueueServiceProvider),
    ref.read(offlineManagerProvider),
  );
  // Subscribe to realtime once when repository is created
  repo.subscribeToRealtime();
  return repo;
}

class VaultRepository {
  final SupabaseClient _client;
  final SyncQueueService _syncQueueService;
  final OfflineManager _offlineManager;

  VaultRepository(this._client, this._syncQueueService, this._offlineManager);

  // Offline-First: Stream from Local DB
  Stream<List<Map<String, dynamic>>> watchSavedRecipes(
      {String? householdId}) async* {
    final box = Hive.box<SavedRecipeModel>('saved_recipes');
    yield _filterBox(box, householdId);
    yield* box.watch().map((_) => _filterBox(box, householdId));
  }

  List<Map<String, dynamic>> _filterBox(
      Box<SavedRecipeModel> box, String? householdId) {
    final items = box.values.toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return items
        .where((r) => householdId != null
            ? r.householdId == householdId
            : r.householdId == null)
        .map((e) {
      // Reconstruct the 'row' expected by UI
      // UI expects { 'id':..., 'recipe_id':..., 'title':..., 'recipe_json':... }
      // Merge ID/Image updates from model if JSON is stale?
      // Actually, we should trust the model fields if we update them.
      // But currently model stores blob in 'recipeJson'.
      return {
        'id': e.id,
        'user_id': e.userId,
        'recipe_id': e.recipeId,
        'household_id': e.householdId,
        'title': e.title,
        'recipe_json': e.recipeJson,
        'created_at': e.createdAt.toIso8601String(),
        'is_shared': e.isShared,
      };
    }).toList();
  }

  Future<void> updateRecipeImage(String recipeId, String imageUrl) async {
    // 1. Update Local Hive
    final box = Hive.box<SavedRecipeModel>('saved_recipes');
    final p = box.values.firstWhere((e) => e.recipeId == recipeId);

    // Update JSON blob
    final newJson = Map<String, dynamic>.from(p.recipeJson);
    newJson['image'] = imageUrl;
    newJson['thumbnail'] = imageUrl; // Update both to be sure

    // Create updated model (Hive objects are immutable-ish if we use copyWith pattern, or just replace)
    final newModel = SavedRecipeModel(
        id: p.id,
        userId: p.userId,
        recipeId: p.recipeId,
        title: p.title,
        recipeJson: newJson,
        householdId: p.householdId,
        createdAt: p.createdAt,
        isShared: p.isShared);

    // Replace in box
    // To replace, we need key. box.values gives values.
    // If we use key:
    final key = box.keyAt(box.values.toList().indexOf(p));
    await box.put(key, newModel);

    // 2. Update Backend
    if (!_offlineManager.hasConnection) {
      // Queue
      await _syncQueueService.queueOperation('saved_recipes', 'update_image',
          {'recipe_id': recipeId, 'image_url': imageUrl});
      return;
    }

    try {
      // We need to update the 'recipe_json' column in Supabase
      await _client
          .from('saved_recipes')
          .update({'recipe_json': newJson}).eq('recipe_id', recipeId);
    } catch (e) {
      // Queue fallback
      await _syncQueueService.queueOperation('saved_recipes', 'update_image',
          {'recipe_id': recipeId, 'image_url': imageUrl});
    }
  }

  StreamSubscription? _realtimeSubscription;

  void subscribeToRealtime() {
    if (_realtimeSubscription != null) return;

    print("DEBUG Vault Realtime: Subscribing to saved_recipes stream...");
    _realtimeSubscription = _client
        .from('saved_recipes')
        .stream(primaryKey: ['recipe_id']).listen((remoteItems) {
      print(
          "DEBUG Vault Realtime: Received ${remoteItems.length} items from stream");
      _updateLocalBoxFromRemote(remoteItems);
    }, onError: (e) {
      print("Vault Realtime Error: $e");
    });
  }

  void unsubscribeRealtime() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
  }

  // Sync
  Future<void> syncSavedRecipes() async {
    try {
      final response = await _client.from('saved_recipes').select();
      final remoteItems = List<Map<String, dynamic>>.from(response);
      await _updateLocalBoxFromRemote(remoteItems);

      // Fallback: If sync succeeded, we're definitely online.
      // Process any queued operations
      print(
          "DEBUG syncSavedRecipes: Sync succeeded, processing any pending queue...");
      await _syncQueueService.processQueue();
    } catch (e) {
      print("DEBUG syncSavedRecipes: Sync failed (likely offline): $e");
    }
  }

  Future<void> _updateLocalBoxFromRemote(
      List<Map<String, dynamic>> remoteItems) async {
    final box = Hive.box<SavedRecipeModel>('saved_recipes');

    // Preserve local-only items (temp IDs) that haven't synced yet
    final tempItems =
        box.values.where((i) => i.id.startsWith('temp_')).toList();

    await box.clear();
    final models =
        remoteItems.map((json) => SavedRecipeModel.fromJson(json)).toList();
    await box.addAll(models);

    // Deduplicate: Remove temp items that match incoming remote items (by title + household)
    final uniqueTempItems = tempItems.where((temp) {
      final isDuplicate = remoteItems.any((remote) {
        final remoteTitle = (remote['title'] ?? '').toString().toLowerCase();
        final tempTitle = temp.title.toLowerCase();
        final remoteHousehold = remote['household_id'];
        final tempHousehold = temp.householdId;
        final remoteRecipeId = remote['recipe_id'];

        return (remoteTitle == tempTitle && remoteHousehold == tempHousehold) ||
            (remoteRecipeId != null && remoteRecipeId == temp.recipeId);
      });
      return !isDuplicate;
    }).toList();

    // Create NEW instances to avoid HiveObject key conflicts
    final freshTempItems = uniqueTempItems
        .map((old) => SavedRecipeModel(
              id: old.id,
              userId: old.userId,
              recipeId: old.recipeId,
              title: old.title,
              recipeJson: old.recipeJson,
              householdId: old.householdId,
              createdAt: old.createdAt,
              isShared: old.isShared,
            ))
        .toList();

    await box.addAll(freshTempItems);
  }

  Future<void> saveRecipe(Map<String, dynamic> recipe,
      {String? householdId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    // Ensure we have a recipe_id
    final recipeId = recipe['id'] ?? const Uuid().v4();
    recipe['id'] = recipeId;

    // Optimistic Hive
    final box = Hive.box<SavedRecipeModel>('saved_recipes');
    // We need a unique ID for Hive. New items don't have row ID 'id' yet.
    // Use recipeId as temp ID? Or generate one.
    // SavedRecipeModel.id is "String id" (Row ID).
    final tempRowId = "temp_${const Uuid().v4()}";

    final model = SavedRecipeModel(
      id: tempRowId,
      userId: userId,
      recipeId: recipeId,
      title: recipe['title'],
      recipeJson: recipe,
      householdId: householdId,
      createdAt: DateTime.now(),
      isShared: householdId != null, // simplified
    );
    box.add(model);

    final payload = {
      'user_id': userId,
      'recipe_id': recipeId,
      'title': recipe['title'],
      'recipe_json': recipe,
      'household_id': householdId,
    };

    if (!_offlineManager.hasConnection) {
      await _syncQueueService.queueOperation(
          'saved_recipes', 'upsert', payload);
      return;
    }

    try {
      await _client.from('saved_recipes').upsert(payload);
      await syncSavedRecipes();
    } catch (_) {
      await _syncQueueService.queueOperation(
          'saved_recipes', 'upsert', payload);
    }
  }

  Map<String, dynamic> generateLinkMetadata(String url,
      {String? title, String? thumbnail}) {
    final linkId = const Uuid().v4();
    final linkTitle = title?.isNotEmpty == true ? title! : url;

    String? platform;
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) {
      platform = 'YouTube';
    } else if (lowerUrl.contains('instagram.com')) {
      platform = 'Instagram';
    } else if (lowerUrl.contains('tiktok.com')) {
      platform = 'TikTok';
    } else if (lowerUrl.contains('snapchat.com')) {
      platform = 'Snapchat';
    } else if (lowerUrl.contains('facebook.com') ||
        lowerUrl.contains('fb.watch')) {
      platform = 'Facebook';
    } else if (lowerUrl.contains('twitter.com') || lowerUrl.contains('x.com')) {
      platform = 'X (Twitter)';
    } else if (lowerUrl.contains('pinterest.com')) {
      platform = 'Pinterest';
    } else {
      platform = 'Web';
    }

    return {
      'id': linkId,
      'type': 'link',
      'url': url,
      'title': linkTitle,
      'platform': platform,
      'thumbnail': thumbnail,
      'saved_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> saveLink(String url, {String? title, String? thumbnail}) async {
    final linkData =
        generateLinkMetadata(url, title: title, thumbnail: thumbnail);
    await saveRecipe(linkData);
  }

  // Legacy fetch
  Future<List<Map<String, dynamic>>> getSavedRecipes(
      {String? householdId}) async {
    await syncSavedRecipes();
    final box = Hive.box<SavedRecipeModel>('saved_recipes');
    return _filterBox(box, householdId);
  }

  Stream<List<Map<String, dynamic>>> getSavedRecipesStream(
      {String? householdId}) {
    return watchSavedRecipes(householdId: householdId);
  }

  Future<void> deleteRecipe(String recipeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    print("DEBUG deleteRecipe: Attempting to delete recipe_id=$recipeId");

    // Optimistic Delete
    final box = Hive.box<SavedRecipeModel>('saved_recipes');

    // Find by recipe_id
    final matching = box.values.where((e) => e.recipeId == recipeId).toList();
    print(
        "DEBUG deleteRecipe: Found ${matching.length} matching items in Hive");

    final itemToDelete = matching.isNotEmpty ? matching.first : null;

    if (itemToDelete != null && itemToDelete.isInBox) {
      // --- IMAGE CLEANUP ---
      // Check if the recipe has a Supabase Storage image and delete it
      try {
        final recipeJson = itemToDelete.recipeJson;
        final String? imageUrl = recipeJson['image'] ?? recipeJson['thumbnail'];

        if (imageUrl != null &&
            imageUrl.contains('/storage/v1/object/public/images/')) {
          print(
              "DEBUG deleteRecipe: Detected Supabase Storage image. Attempting cleanup...");
          // Extract path: recipes/filename.ext or recipe_photos/filename.ext
          // URL format: .../public/images/recipe_photos/uuid.png
          final pathParts = imageUrl.split('/public/images/');
          if (pathParts.length > 1) {
            final storagePath = pathParts[1];
            print("DEBUG deleteRecipe: Deleting storage object: $storagePath");
            // Perform delete (Swallow errors for now to ensure recipe deletion continues)
            await _client.storage.from('images').remove([storagePath]);
            print("DEBUG deleteRecipe: Storage cleanup successful");
          }
        }
      } catch (storageErr) {
        print(
            "DEBUG deleteRecipe: Storage cleanup failed (non-critical): $storageErr");
      }

      print("DEBUG deleteRecipe: Deleting from Hive - id=${itemToDelete.id}");
      await itemToDelete.delete();
    } else {
      print("DEBUG deleteRecipe: Item not found in Hive or already deleted");
    }

    if (!_offlineManager.hasConnection) {
      // Find storage path if exists
      String? storagePath;
      try {
        final recipeJson = itemToDelete?.recipeJson;
        final String? imageUrl =
            recipeJson?['image'] ?? recipeJson?['thumbnail'];
        if (imageUrl != null &&
            imageUrl.contains('/storage/v1/object/public/images/')) {
          final pathParts = imageUrl.split('/public/images/');
          if (pathParts.length > 1) storagePath = pathParts[1];
        }
      } catch (_) {}

      // Queue delete by recipe_id (id column doesn't exist in DB)
      await _syncQueueService
          .queueOperation('saved_recipes', 'delete_by_recipe_id', {
        'recipe_id': recipeId,
        if (storagePath != null) 'image_path': storagePath,
      });
      return;
    }

    try {
      // Delete from Supabase Database
      await _client.from('saved_recipes').delete().eq('recipe_id', recipeId);
      print("DEBUG deleteRecipe: Server delete successful");
    } catch (e) {
      print("DEBUG deleteRecipe: Delete failed, queuing: $e");
      // Queue for retry when online
      await _syncQueueService.queueOperation(
          'saved_recipes', 'delete_by_recipe_id', {'recipe_id': recipeId});
    }
  }

  Future<void> shareRecipe(String recipeId, {String? householdId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    String? targetHouseholdId = householdId;

    if (targetHouseholdId == null) {
      // Try to fetch household ID from cache first (offline-safe)
      try {
        final box = Hive.box('app_prefs');
        final cached = box.get('household_data');
        if (cached != null) {
          targetHouseholdId = cached['id'];
        }
      } catch (_) {}

      // If still null and online, try fetching from server
      if (targetHouseholdId == null && _offlineManager.hasConnection) {
        try {
          final profile = await _client
              .from('profiles')
              .select('household_id')
              .eq('id', userId)
              .single();
          targetHouseholdId = profile['household_id'];
        } catch (_) {}
      }
    }

    if (targetHouseholdId == null) {
      throw Exception("You are not part of a household.");
    }

    // 1. Fetch Source Recipe (Local or Remote)
    Map<String, dynamic>? sourceData;
    final box = Hive.box<SavedRecipeModel>('saved_recipes');

    try {
      // Try local first
      final localSource = box.values.firstWhere((e) => e.recipeId == recipeId);
      sourceData = {
        'title': localSource.title,
        'recipe_json': localSource.recipeJson
      };
    } catch (_) {}

    if (sourceData == null && _offlineManager.hasConnection) {
      final source = await _client
          .from('saved_recipes')
          .select()
          .eq('recipe_id', recipeId)
          .single();
      sourceData = source;
    }

    if (sourceData == null) {
      throw Exception("Recipe not found.");
    }

    // 2. Check for Duplicate (Local check is best effort offline)
    // Offline: Check if we have a recipe in the box with householdId == targetHouseholdId AND title == sourceData['title']
    final duplicate = box.values.any((e) =>
        e.householdId == targetHouseholdId && e.title == sourceData!['title']);

    if (duplicate) {
      throw Exception("Recipe already exists in the household.");
    }
    // Note: Online check would be more robust against other users' adds, but this is okay.

    // 3. Create Copy
    final newRecipeId = const Uuid().v4();
    final newJson = Map<String, dynamic>.from(sourceData['recipe_json']);
    newJson['id'] = newRecipeId;

    final payload = {
      'user_id': userId,
      'recipe_id': newRecipeId,
      'title': sourceData['title'],
      'recipe_json': newJson,
      'household_id': targetHouseholdId,
      'is_shared': true,
    };

    // Optimistic Add to Hive
    final tempRowId = "temp_${const Uuid().v4()}";
    final model = SavedRecipeModel(
      id: tempRowId,
      userId: userId, // Current user is owner of the shared copy? Yes.
      recipeId: newRecipeId,
      title: sourceData['title'],
      recipeJson: newJson,
      householdId: targetHouseholdId,
      createdAt: DateTime.now(),
      isShared: true,
    );
    box.add(model);

    if (!_offlineManager.hasConnection) {
      await _syncQueueService.queueOperation(
          'saved_recipes', 'insert', payload);
      return;
    }

    try {
      await _client.from('saved_recipes').insert(payload);
    } catch (_) {
      await _syncQueueService.queueOperation(
          'saved_recipes', 'insert', payload);
    }
  }

  Future<String?> findRecipeIdByTitle(String title) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('saved_recipes')
        .select('recipe_id')
        .eq('user_id', userId)
        .eq('title', title)
        .maybeSingle();

    if (response != null && response['recipe_id'] != null) {
      return response['recipe_id'] as String;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getRecipeById(String recipeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('saved_recipes')
        .select('recipe_json')
        .eq('recipe_id', recipeId)
        .maybeSingle();

    if (response != null && response['recipe_json'] != null) {
      return Map<String, dynamic>.from(response['recipe_json']);
    }
    return null;
  }

  Future<String> createRecipeShare(Map<String, dynamic> snapshot) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    // Link sharing requires server to generate a token, cannot work offline
    if (!_offlineManager.hasConnection) {
      throw Exception('No connection. Please check your internet');
    }

    try {
      // Insert into recipe_shares
      // 'token' is generated by default, so we select it back
      final response = await _client
          .from('recipe_shares')
          .insert({
            'created_by': userId,
            'snapshot': snapshot,
            'original_recipe_id': snapshot['id'], // Optional tracking
          })
          .select('token')
          .single();

      return response['token'] as String;
    } catch (e) {
      throw Exception(
          'Failed to create share link. Please check your connection.');
    }
  }

  // Fetch shared recipe by token (Public/RPC)
  Future<Map<String, dynamic>?> getSharedRecipe(String token) async {
    try {
      final response = await _client
          .rpc('get_shared_recipe', params: {'token_input': token});

      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
    } catch (e) {
      print("RPC Error fetching shared recipe: $e");
    }
    return null;
  }
}
