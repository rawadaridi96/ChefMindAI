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

  Future<void> saveLink(String url, {String? title}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    // Saving link as a special 'recipe' for now to avoid schema changes if possible
    // Or we could try to see if 'saved_recipes' accepts other fields.
    // Assuming 'recipe_json' is JSONB, we can store anything.
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

    final linkData = {
      'id': linkId,
      'type': 'link',
      'url': url,
      'title': linkTitle,
      'platform': platform,
      'saved_at': DateTime.now().toIso8601String(),
    };

    await _client.from('saved_recipes').upsert({
      'user_id': userId,
      'recipe_id': linkId,
      'title': linkTitle, // Differentiate in title column
      'recipe_json': linkData,
    });
  }

  Future<List<Map<String, dynamic>>> getSavedRecipes() async {
    final response = await _client
        .from('saved_recipes')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
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
}
