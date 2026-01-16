import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../recipes/data/recipe_repository.dart';

part 'recipe_controller.g.dart';

@riverpod
class RecipeController extends _$RecipeController {
  @override
  FutureOr<List<Map<String, dynamic>>> build() {
    return []; // Initially empty list of recipes
  }

  Future<void> generate({
    required String mode,
    String? query,
    List<String>? filters,
    String? mealType,
    String? allergies,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(recipeRepositoryProvider).generateRecipes(
            mode: mode,
            query: query,
            filters: filters,
            mealType: mealType,
            allergies: allergies,
          );
    });
  }

  Future<Map<String, dynamic>> consultChef(
      String question, String contextRecipe) {
    return ref.read(recipeRepositoryProvider).consultChef(
          question: question,
          contextRecipe: contextRecipe,
        );
  }

  Future<void> updateRecipe(int id, Map<String, dynamic> updates) async {
    await ref.read(recipeRepositoryProvider).updateRecipe(id, updates);
    // Optionally refresh list
    // ref.refresh(recipeControllerProvider);
  }
}
