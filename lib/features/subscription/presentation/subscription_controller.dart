import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'subscription_controller.g.dart';

enum SubscriptionTier { free, pro, chef }

@riverpod
class SubscriptionController extends _$SubscriptionController {
  @override
  SubscriptionTier build() {
    return SubscriptionTier.free; // Default to free
  }

  void upgrade(SubscriptionTier tier) {
    state = tier;
  }
}
