import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../data/subscription_repository.dart';

part 'subscription_controller.g.dart';

enum SubscriptionTier { homeCook, sousChef, executiveChef }

@riverpod
class SubscriptionController extends _$SubscriptionController {
  @override
  FutureOr<SubscriptionTier> build() {
    return ref.read(subscriptionRepositoryProvider).getSubscriptionTier();
  }

  Future<void> purchasePackage(Package package) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final newTier = await repo.purchasePackage(package);
      // Force state update immediately
      state = AsyncData(newTier);
    } catch (e) {
      // If cancelled, we should revert to previous state instead of error?
      // Or just invalidate to re-fetch?
      // Usually users prefer "nothing happened" if cancelled.
      // But if it's a real error, show it.
      // For now, let's invalidate self to be safe if error occurs, ensuring we return to valid state
      ref.invalidateSelf();
      // But we rethrow so UI can show error message
      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.restorePurchases();
      final newTier = await repo.getSubscriptionTier();
      state = AsyncData(newTier);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<Offerings?> fetchOfferings() async {
    return ref.read(subscriptionRepositoryProvider).getOfferings();
  }

  // Feature Limits
  int get dailyRecipeGenerationLimit {
    final tier = state.valueOrNull ?? SubscriptionTier.homeCook;
    switch (tier) {
      case SubscriptionTier.homeCook:
        return 5;
      case SubscriptionTier.sousChef:
      case SubscriptionTier.executiveChef:
        return 2147483647; // Effectively unlimited (max int)
    }
  }

  int get vaultSaveLimit {
    final tier = state.valueOrNull ?? SubscriptionTier.homeCook;
    switch (tier) {
      case SubscriptionTier.homeCook:
        return 3;
      case SubscriptionTier.sousChef:
      case SubscriptionTier.executiveChef:
        return 2147483647; // Unlimited
    }
  }

  bool get canUseLinkScraper {
    final tier = state.valueOrNull ?? SubscriptionTier.homeCook;
    // Only paid plans can use scraper
    return tier != SubscriptionTier.homeCook;
  }
}
