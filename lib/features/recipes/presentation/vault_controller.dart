import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/vault_repository.dart';
import '../../subscription/presentation/subscription_controller.dart';
import '../../../core/exceptions/premium_limit_exception.dart';
import '../../settings/presentation/household_controller.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/offline_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // Trigger Sync
    ref.read(vaultRepositoryProvider).syncSavedRecipes().ignore();

    return ref
        .watch(vaultRepositoryProvider)
        .watchSavedRecipes(householdId: householdId);
  }

  Future<String?> checkForDuplicate(String title) async {
    return await ref.read(vaultRepositoryProvider).findRecipeIdByTitle(title);
  }

  Future<Map<String, dynamic>?> getRecipeById(String recipeId) async {
    return await ref.read(vaultRepositoryProvider).getRecipeById(recipeId);
  }

  Future<void> saveRecipe(Map<String, dynamic> recipe) async {
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

    // Repository now handles Optimistic UI via Hive -> Stream
    await _performOfflineSafe(
        () => ref.read(vaultRepositoryProvider).saveRecipe(recipe));
  }

  Future<void> saveLink(String url, {String? title}) async {
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

    await _performOfflineSafe(
        () => ref.read(vaultRepositoryProvider).saveLink(url, title: title));
  }

  Future<void> deleteRecipe(String recipeId) async {
    await _performOfflineSafe(
        () => ref.read(vaultRepositoryProvider).deleteRecipe(recipeId));
  }

  Future<void> _performOfflineSafe(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      final isConnected = ref.read(offlineManagerProvider).hasConnection;
      if (!isConnected) {
        // Swallow error - Optimistic Update already happened in Repo
        return;
      }
      rethrow;
    }
  }

  Future<void> shareRecipe(String recipeId) async {
    try {
      await ref.read(vaultRepositoryProvider).shareRecipe(recipeId);
    } catch (e) {
      throw e;
    }
  }

  Future<void> saveToHousehold(Map<String, dynamic> recipe) async {
    // Household check
    final householdState = ref.read(householdControllerProvider);
    final householdId = householdState.valueOrNull?['id'];
    if (householdId == null)
      throw Exception("You are not part of a household.");

    // Check Duplicate
    final repo = ref.read(vaultRepositoryProvider);
    // (Optional: duplicate check logic specific to household could go here, but shareRecipe handles it too. Let's rely on repo constraints/logic if extended, or basic title check)
    // Actually, vaultRepository.saveRecipe inserts a row.
    // We should create a copy with new ID if we want to treat it distinct?
    // User wants to "save only to household".
    // So we just save with householdId.

    // But we should clean the ID?
    // If we are passing the CURRENT recipe, it might have an ID.
    // If we use that ID, it will clash if also in local DB?
    // No, local DB separates by household_id filtering.
    // But uniqueness constraint?
    // recipe_id + user_id?
    // or just recipe_id?
    // Repo uses: 'recipe_id'. The table likely has PK on ID.
    // So we MUST generate a new ID for the household copy to avoid PK collision if user also saves to personal.
    final recipeToSave = Map<String, dynamic>.from(recipe);
    recipeToSave['id'] = const Uuid().v4(); // Force new ID
    recipeToSave['recipe_id'] =
        recipeToSave['id']; // Ensure this property is sync'd

    try {
      await repo.saveRecipe(recipeToSave, householdId: householdId);
    } catch (e) {
      throw e;
    }
  }

  Future<String> createUniversalLink(Map<String, dynamic> recipe) async {
    // Check Tier
    final subState = await ref.read(subscriptionControllerProvider.future);
    final isPremium = subState != SubscriptionTier.homeCook;

    if (!isPremium) {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      final lastDate = prefs.getString('share_date');
      int count = prefs.getInt('share_count') ?? 0;

      if (lastDate != today) {
        count = 0;
        await prefs.setString('share_date', today);
      }

      if (count >= 5) {
        throw PremiumLimitReachedException(
            "Daily share limit reached (5/5). Upgrade for unlimited sharing!",
            "Daily Share Limit");
      }

      await prefs.setInt('share_count', count + 1);
    }

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
