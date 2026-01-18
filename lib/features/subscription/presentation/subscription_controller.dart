import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/subscription_repository.dart';

part 'subscription_controller.g.dart';

enum SubscriptionTier { homeCook, sousChef, executiveChef }

@riverpod
class SubscriptionController extends _$SubscriptionController {
  @override
  FutureOr<SubscriptionTier> build() {
    return ref.read(subscriptionRepositoryProvider).getSubscriptionTier();
  }

  Future<void> upgrade(SubscriptionTier tier) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.updateSubscriptionTier(tier);

      // Fetch fresh data from source of truth to ensure consistency
      final newTier = await repo.getSubscriptionTier();
      state = AsyncData(newTier);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
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
