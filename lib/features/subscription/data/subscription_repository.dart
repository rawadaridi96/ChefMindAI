import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../presentation/subscription_controller.dart';

part 'subscription_repository.g.dart';

@riverpod
SubscriptionRepository subscriptionRepository(SubscriptionRepositoryRef ref) {
  return SubscriptionRepository(Supabase.instance.client);
}

class SubscriptionRepository {
  final SupabaseClient _client;

  SubscriptionRepository(this._client);

  Future<SubscriptionTier> getSubscriptionTier() async {
    final user = _client.auth.currentUser;
    if (user == null) return SubscriptionTier.discover;

    try {
      final response = await _client
          .from('profiles')
          .select('subscription_tier')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return SubscriptionTier.discover;

      final tierStr = response['subscription_tier'] as String?;
      return _parseTier(tierStr);
    } catch (e) {
      // If table doesn't exist or other error, default to free
      return SubscriptionTier.discover;
    }
  }

  Future<void> updateSubscriptionTier(SubscriptionTier tier) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final tierStr = _tierToString(tier);

    try {
      // Use RPC to bypass RLS policies safely
      await _client.rpc('upgrade_user_subscription', params: {
        'new_tier': tierStr,
      });
    } catch (e) {
      // Re-throw to be caught by Controller
      rethrow;
    }
  }

  SubscriptionTier _parseTier(String? tier) {
    switch (tier) {
      case 'chef':
        return SubscriptionTier.chef;
      case 'master_chef':
        return SubscriptionTier.masterChef;
      case 'discover':
      default:
        return SubscriptionTier.discover;
    }
  }

  String _tierToString(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.chef:
        return 'chef';
      case SubscriptionTier.masterChef:
        return 'master_chef';
      case SubscriptionTier.discover:
        return 'discover';
    }
  }
}
