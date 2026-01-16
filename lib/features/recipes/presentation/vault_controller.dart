import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/vault_repository.dart';

part 'vault_controller.g.dart';

@riverpod
class VaultController extends _$VaultController {
  @override
  FutureOr<List<Map<String, dynamic>>> build() async {
    try {
      return await ref.read(vaultRepositoryProvider).getSavedRecipes();
    } catch (e, st) {
      print("Vault Load Error: $e");
      print(st);
      throw e;
    }
  }

  Future<String?> checkForDuplicate(String title) async {
    return await ref.read(vaultRepositoryProvider).findRecipeIdByTitle(title);
  }

  Future<void> saveRecipe(Map<String, dynamic> recipe) async {
    state = const AsyncLoading(); // Feedback
    try {
      await ref.read(vaultRepositoryProvider).saveRecipe(recipe);
      // Refresh list
      state = await AsyncValue.guard(
          () => ref.read(vaultRepositoryProvider).getSavedRecipes());
    } catch (e, st) {
      print("Vault Save Error: $e");
      print(st);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveLink(String url, {String? title}) async {
    await AsyncValue.guard(() async {
      await ref.read(vaultRepositoryProvider).saveLink(url, title: title);
      state = await AsyncValue.guard(
          () => ref.read(vaultRepositoryProvider).getSavedRecipes());
    });
  }

  Future<void> deleteRecipe(String recipeId) async {
    await AsyncValue.guard(() async {
      await ref.read(vaultRepositoryProvider).deleteRecipe(recipeId);
      // Optimistic update or refresh
      state = await AsyncValue.guard(
          () => ref.read(vaultRepositoryProvider).getSavedRecipes());
    });
  }
}
