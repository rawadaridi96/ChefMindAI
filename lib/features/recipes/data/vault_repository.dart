import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:uuid/uuid.dart';

part 'vault_repository.g.dart';

@riverpod
VaultRepository vaultRepository(VaultRepositoryRef ref) {
  return VaultRepository(Supabase.instance.client);
}

class VaultRepository {
  final SupabaseClient _client;

  VaultRepository(this._client);

  Future<void> saveRecipe(Map<String, dynamic> recipe) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    // Ensure we have a recipe_id
    final recipeId = recipe['id'] ?? const Uuid().v4();
    // Update the recipe map just in case we need it later
    recipe['id'] = recipeId;

    await _client.from('saved_recipes').upsert({
      'user_id': userId,
      'recipe_id': recipeId, // Satisfy Not Null constraint
      'title': recipe['title'],
      'recipe_json': recipe,
    });
  }

  Map<String, dynamic> generateLinkMetadata(String url, {String? title}) {
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
      'saved_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> saveLink(String url, {String? title}) async {
    // Legacy support or direct use
    final linkData = generateLinkMetadata(url, title: title);
    await saveRecipe(linkData);
  }

  Future<List<Map<String, dynamic>>> getSavedRecipes(
      {String? householdId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    var query = _client.from('saved_recipes').select();

    if (householdId != null) {
      // Household View: Show items belonging to this household
      query = query.eq('household_id', householdId);
    } else {
      // Personal View: Show items belonging to user (and NOT household-exclusive if that's a thing,
      // but usually personal means created by me or explicitly mine).
      // Given previous Shopping Cart logic, we want explicit isolation.
      // So fetch where user_id = me AND household_id IS NULL?
      // OR fetch where user_id = me (regardless of sharing).
      // "Shared with Household" usually means "I own it, but they can see it".
      // If I "Share" it, does it move to the household list?
      // In Shopping Cart, we had strict separation: Household List vs Personal List.
      // If I share a recipe, `shareRecipe` sets `household_id`.
      // If I view "Personal", should I see it?
      // If I adhere to strict isolation: NO. It moved to Household.
      // If I want "My Recipes" (all mine) + "Household" (everyone's).
      // User asked for "Shared Cart" which was strict.
      // Let's assume strict isolation for consistency first: Personal = household_id is NULL.
      query = query.eq('user_id', userId).filter('household_id', 'is', 'null');
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Stream<List<Map<String, dynamic>>> getSavedRecipesStream(
      {String? householdId}) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return Stream.value([]);

    // Stream definition
    // Note: 'order' might not be supported in stream builder directly in all SDK versions,
    // but we can sort in Dart.
    Stream<List<Map<String, dynamic>>> stream;

    if (householdId != null) {
      // Stream Household Items
      stream = _client
          .from('saved_recipes')
          .stream(primaryKey: ['id']).eq('household_id', householdId);
    } else {
      // Stream Personal Items (user_id = me)
      // Filter 'household_id' == null locally
      stream = _client
          .from('saved_recipes')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .map((data) =>
              data.where((item) => item['household_id'] == null).toList());
    }

    // Apply sorting locally to ensure consistency
    return stream.map((data) {
      final sorted = List<Map<String, dynamic>>.from(data);
      sorted.sort((a, b) {
        final aTime = a['created_at'] as String? ?? '';
        final bTime = b['created_at'] as String? ?? '';
        return bTime.compareTo(aTime); // Descending
      });
      return sorted;
    });
  }

  Future<void> deleteRecipe(String recipeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    await _client
        .from('saved_recipes')
        .delete()
        .eq('user_id', userId)
        .eq('recipe_id', recipeId);
  }

  Future<void> shareRecipe(String recipeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    // Get currentUser's profile to find household_id
    final profile = await _client
        .from('profiles')
        .select('household_id')
        .eq('id', userId)
        .single();

    final householdId = profile['household_id'];

    if (householdId == null) {
      throw Exception("You are not part of a household.");
    }

    // 1. Fetch Source Recipe
    final source = await _client
        .from('saved_recipes')
        .select()
        .eq('recipe_id', recipeId)
        .single();

    // 2. Check for Duplicate in Household
    // We check if a recipe with the same title already exists in the household
    final existing = await _client
        .from('saved_recipes')
        .select('recipe_id') // Changed from 'id' to 'recipe_id'
        .eq('household_id', householdId)
        .eq('title', source['title'])
        .maybeSingle();

    if (existing != null) {
      // It implies it's already shared/exists
      throw Exception("Recipe already exists in the household.");
    }

    // 3. Create Copy
    final newRecipeId = const Uuid().v4();
    final newJson = Map<String, dynamic>.from(source['recipe_json']);
    newJson['id'] = newRecipeId; // Ensure internal ID matches
    // Also ensure title duplication check doesn't fail on " V2" logic if we want specific logic?
    // No, we just copy exact title.

    await _client.from('saved_recipes').insert({
      'user_id': userId,
      'recipe_id': newRecipeId,
      'title': source['title'],
      'recipe_json': newJson,
      'household_id': householdId,
      'is_shared': true,
    });
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
