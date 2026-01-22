import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/secure_storage_service.dart';
import '../presentation/subscription_controller.dart';

part 'subscription_repository.g.dart';

@riverpod
SubscriptionRepository subscriptionRepository(SubscriptionRepositoryRef ref) {
  return SubscriptionRepository(
    Supabase.instance.client,
    ref.read(secureStorageServiceProvider),
  );
}

class SubscriptionRepository {
  final SupabaseClient _client;
  final SecureStorageService _secureStorage;

  SubscriptionRepository(this._client, this._secureStorage);

  Future<SubscriptionTier> getSubscriptionTier() async {
    // 1. Try Local Cache First (Fastest/Offline)
    final cachedTier = await _secureStorage.getSubscriptionTier();
    // Default to what we have locally if available, but we will still try to sync

    // 2. If we are offline, trust the cache
    // (Ideally we inject checking offline status, but for now we just try/catch)

    final user = _client.auth.currentUser;
    if (user == null) return SubscriptionTier.homeCook;

    try {
      final response = await _client
          .from('profiles')
          .select('subscription_tier')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        final tierStr = response['subscription_tier'] as String?;
        // 3. Update Cache on successful fetch
        if (tierStr != null) {
          await _secureStorage.saveSubscriptionTier(tierStr);
        }
        return _parseTier(tierStr);
      }
    } catch (e) {
      // 4. Fallback to cache on error (Network/Offline)
      if (cachedTier != null) {
        return _parseTier(cachedTier);
      }
    }

    // Fallback if no cache and no network
    return cachedTier != null
        ? _parseTier(cachedTier)
        : SubscriptionTier.homeCook;
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
      case 'sous_chef':
        return SubscriptionTier.sousChef;
      case 'executive_chef':
        return SubscriptionTier.executiveChef;
      case 'home_cook':
      default:
        return SubscriptionTier.homeCook;
    }
  }

  String _tierToString(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.sousChef:
        return 'sous_chef';
      case SubscriptionTier.executiveChef:
        return 'executive_chef';
      case SubscriptionTier.homeCook:
        return 'home_cook';
    }
  }
}
