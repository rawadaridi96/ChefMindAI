import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'recipe_repository.g.dart';

@riverpod
RecipeRepository recipeRepository(RecipeRepositoryRef ref) {
  return RecipeRepository(Supabase.instance.client);
}

class RecipeRepository {
  final SupabaseClient _client;

  RecipeRepository(this._client);

  Future<List<Map<String, dynamic>>> generateRecipes({
    required String mode,
    String? query,
    List<String>? filters,
    String? mealType,
    String? allergies,
    String? mood,
    bool isExecutive = false,
  }) async {
    final response = await _client.functions.invoke(
      'generate-recipes',
      body: {
        'mode': mode,
        if (query != null && query.isNotEmpty) 'search_query': query,
        if (filters != null && filters.isNotEmpty) 'filters': filters,
        if (mealType != null && mealType.isNotEmpty) 'meal_type': mealType,
        if (allergies != null && allergies.isNotEmpty) 'allergies': allergies,
        if (mealType != null && mealType.isNotEmpty) 'meal_type': mealType,
        if (allergies != null && allergies.isNotEmpty) 'allergies': allergies,
        if (mood != null && mood.isNotEmpty) 'mood': mood,
        'is_executive': isExecutive,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to generate recipes: ${response.status}');
    }

    final data = response.data;
    if (data is Map && data.containsKey('recipes')) {
      return List<Map<String, dynamic>>.from(data['recipes']);
    }
    return [];
  }

  Future<Map<String, dynamic>> consultChef({
    required String question,
    required Map<String, dynamic> recipeContext,
  }) async {
    final response = await _client.functions.invoke(
      'generate-recipes',
      body: {
        'mode': 'consult_chef',
        'user_question': question,
        'recipe_context': recipeContext,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to consult chef: ${response.status}');
    }

    final data = response.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {'answer': "I couldn't generate an answer."};
  }

  Future<void> updateRecipe(int id, Map<String, dynamic> updates) async {
    await _client.from('recipes').update(updates).eq('id', id);
  }

  Future<Map<String, dynamic>> importRecipe(String url) async {
    final response = await _client.functions.invoke(
      'import-recipe',
      body: {'url': url},
    );

    if (response.status != 200) {
      // Try to parse error message from body
      String errorMsg = 'Failed to import recipe';
      if (response.data is Map && response.data['error'] != null) {
        errorMsg = response.data['error'];
      }
      throw Exception(errorMsg);
    }

    final data = response.data;
    if (data is Map && data.containsKey('recipe')) {
      return Map<String, dynamic>.from(data['recipe']);
    }
    throw Exception('Invalid response format');
  }
}
