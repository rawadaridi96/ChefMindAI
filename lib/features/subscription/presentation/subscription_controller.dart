import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'subscription_controller.g.dart';

enum SubscriptionTier { discover, chef, masterChef }

@riverpod
class SubscriptionController extends _$SubscriptionController {
  @override
  SubscriptionTier build() {
    return SubscriptionTier.discover; // Default to discover
  }

  void upgrade(SubscriptionTier tier) {
    state = tier;
  }
}
