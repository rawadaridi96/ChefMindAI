import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/vault_repository.dart';
import '../../subscription/presentation/subscription_controller.dart';
import '../../../core/exceptions/premium_limit_exception.dart';
import '../../settings/presentation/household_controller.dart';
import 'package:uuid/uuid.dart';

part 'vault_controller.g.dart';

// Manual Provider for Sync Toggle
final vaultSyncEnabledProvider = StateProvider<bool>((ref) => false);

@riverpod
class VaultController extends _$VaultController {
  @override
  Stream<List<Map<String, dynamic>>> build() {
    final isSyncEnabled = ref.watch(vaultSyncEnabledProvider);
    String? householdId;

    if (isSyncEnabled) {
      final householdState = ref.watch(householdControllerProvider);
      householdId = householdState.valueOrNull?['id'];
    }

    return ref
        .watch(vaultRepositoryProvider)
        .getSavedRecipesStream(householdId: householdId);
  }

  Future<String?> checkForDuplicate(String title) async {
    return await ref.read(vaultRepositoryProvider).findRecipeIdByTitle(title);
  }

  Future<Map<String, dynamic>?> getRecipeById(String recipeId) async {
    return await ref.read(vaultRepositoryProvider).getRecipeById(recipeId);
  }

  Future<void> saveRecipe(Map<String, dynamic> recipe) async {
    // Ensure subscription tier is loaded
    final textTier = await ref.read(subscriptionControllerProvider.future);

    final limit = (textTier == SubscriptionTier.sousChef ||
            textTier == SubscriptionTier.executiveChef)
        ? 2147483647
        : ref.read(subscriptionControllerProvider.notifier).vaultSaveLimit;
    final currentCount = state.value?.length ?? 0;

    if (currentCount >= limit) {
      throw PremiumLimitReachedException(
        "Vault is full ($limit items).",
        "Vault Limit Reached",
      );
    }

    // Optimistic Update
    final newId = recipe['id'] ?? const Uuid().v4();
    recipe['id'] = newId; // Ensure ID is set in the payload

    final optimisticItem = {
      'recipe_id': newId,
      'title': recipe['title'],
      'recipe_json': recipe,
      'created_at': DateTime.now().toIso8601String(),
    };

    final previousState = state;
    if (previousState.value != null) {
      final updatedList = [optimisticItem, ...previousState.value!];
      state = AsyncValue.data(updatedList);
    }

    try {
      await ref.read(vaultRepositoryProvider).saveRecipe(recipe);
      // No refresh needed if success
    } catch (e, st) {
      print("Vault Save Error: $e");
      print(st);
      // Rollback
      state = previousState;
      // Re-throw or show error state?
      // If we re-throw, UI shows error toast.
      // But we must revert local state.
      // state = AsyncValue.error(e, st); // This might replace the whole list with error?
      // Better to revert list and show toast.
      state = previousState; // Revert list
      throw e; // Let UI handle toast
    }
  }

  Future<void> saveLink(String url, {String? title}) async {
    // Ensure subscription tier is loaded
    final textTier = await ref.read(subscriptionControllerProvider.future);

    final limit = (textTier == SubscriptionTier.sousChef ||
            textTier == SubscriptionTier.executiveChef)
        ? 2147483647
        : ref.read(subscriptionControllerProvider.notifier).vaultSaveLimit;
    final currentCount = state.value?.length ?? 0;

    if (currentCount >= limit) {
      throw PremiumLimitReachedException(
        "Vault is full ($limit items).",
        "Vault Limit Reached",
      );
    }

    // Optimistic Update
    final repo = ref.read(vaultRepositoryProvider);
    final linkMetadata = repo.generateLinkMetadata(url, title: title);

    // Create a "Row-like" structure matching DB response
    final optimisticItem = {
      'recipe_id': linkMetadata['id'],
      'title': linkMetadata['title'],
      'recipe_json': linkMetadata,
      'created_at': DateTime.now().toIso8601String(),
      // 'household_id' is assumed null unless we strictly filter?
      // But if we are in Personal view (default for saveLink), satisfied.
    };

    final previousState = state;
    if (previousState.value != null) {
      // Prepend to list
      final updatedList = [optimisticItem, ...previousState.value!];
      state = AsyncValue.data(updatedList);
    }

    try {
      await repo.saveRecipe(linkMetadata);
    } catch (e) {
      // Rollback
      state = previousState;
      throw e;
    }
  }

  Future<void> deleteRecipe(String recipeId) async {
    print("DEBUG: deleteRecipe called for $recipeId");
    // 1. Optimistic Update: Remove immediately from UI
    final previousState = state;
    if (previousState.value != null) {
      print("DEBUG: Current list size: ${previousState.value!.length}");
      final updatedList = previousState.value!
          .where((r) => r['recipe_id'] != recipeId)
          .toList();
      print("DEBUG: New list size: ${updatedList.length}");

      if (previousState.value!.length == updatedList.length) {
        print("DEBUG: No item found with ID $recipeId");
        // Verify IDs in list
        for (var r in previousState.value!) {
          print(
              "DEBUG: Available ID: ${r['recipe_id']} (Type: ${r['recipe_id'].runtimeType})");
        }
      }

      state = AsyncValue.data(updatedList);
    } else {
      print("DEBUG: State value is null");
    }

    try {
      // 2. Perform DB Operation
      await ref.read(vaultRepositoryProvider).deleteRecipe(recipeId);
    } catch (e) {
      // 3. Rollback on failure
      print("DEBUG: Delete failed, rolling back. Error: $e");
      state = previousState;
      throw e;
    }
  }

  Future<void> shareRecipe(String recipeId) async {
    try {
      await ref.read(vaultRepositoryProvider).shareRecipe(recipeId);
    } catch (e) {
      throw e;
    }
  }

  Future<String> createUniversalLink(Map<String, dynamic> recipe) async {
    // 1. Get Token
    final token =
        await ref.read(vaultRepositoryProvider).createRecipeShare(recipe);

    // 2. Generate Deep Link
    // Scheme: chefmind://share/universal?token=...
    return "chefmind://share/universal?token=$token";
  }

  Future<Map<String, dynamic>?> getSharedRecipe(String token) async {
    return await ref.read(vaultRepositoryProvider).getSharedRecipe(token);
  }
}
