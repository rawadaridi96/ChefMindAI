import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/subscription_repository.dart';

part 'subscription_controller.g.dart';

enum SubscriptionTier { discover, chef, masterChef }

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
}
