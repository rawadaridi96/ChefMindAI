import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../auth/data/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final user = ref.read(authRepositoryProvider).currentUser;
      final prefs = await SharedPreferences.getInstance();
      bool isGuest = user == null || user.isAnonymous;
      int guestGenCount = prefs.getInt('guest_gen_count') ?? 0;

      final recipes = await ref.read(recipeRepositoryProvider).generateRecipes(
            mode: mode,
            query: query,
            filters: filters,
            mealType: mealType,
            allergies: allergies,
          );

      if (isGuest) {
        if (guestGenCount >= 1) {
          // Lock the recipes
          return recipes.map((r) => {...r, 'is_locked': true}).toList();
        }
        await prefs.setInt('guest_gen_count', guestGenCount + 1);
      }

      return recipes;
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
