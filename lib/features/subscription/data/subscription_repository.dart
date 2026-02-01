import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/config/store_config.dart';
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

  SubscriptionRepository(this._client, this._secureStorage) {
    _initRevenueCat();
  }

  Future<void> _initRevenueCat() async {
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration? configuration;
    if (Platform.isAndroid) {
      if (StoreConfig.googleApiKey != 'goog_PlaceholderKey') {
        configuration = PurchasesConfiguration(StoreConfig.googleApiKey);
      }
    } else if (Platform.isIOS) {
      if (StoreConfig.appleApiKey != 'appl_PlaceholderKey') {
        configuration = PurchasesConfiguration(StoreConfig.appleApiKey);
      }
    }

    if (configuration != null) {
      await Purchases.configure(configuration);
      _listenToPurchaseUpdates();
    }
  }

  void _listenToPurchaseUpdates() {
    Purchases.addCustomerInfoUpdateListener((customerInfo) async {
      // Instead of manual parsing, run the full resolution logic.
      // This ensures we check Supabase before accepting a 'Home Cook' status from RC.
      await getSubscriptionTier();
    });
  }

  Future<SubscriptionTier> getSubscriptionTier() async {
    // 1. Try Local Cache First
    final cachedTier = await _secureStorage.getSubscriptionTier();
    SubscriptionTier currentTier =
        cachedTier != null ? _parseTier(cachedTier) : SubscriptionTier.homeCook;

    try {
      // 2. Fetch fresh from RevenueCat
      final customerInfo = await Purchases.getCustomerInfo();

      // Check Active Entitlements
      final rcTier = _parseEntitlements(customerInfo);

      // 3. Logic: If RC has an active paid tier, it is the authority.
      if (rcTier != SubscriptionTier.homeCook) {
        if (rcTier != _parseTier(cachedTier)) {
          await _updateLocalState(rcTier); // Sync Upgrade to Supabase
        }
        return rcTier;
      }

      // 4. RC says "Home Cook".
      // Do NOT assume expiry/downgrade yet. Check Supabase first.

      final user = _client.auth.currentUser;
      if (user != null) {
        try {
          final response = await _client
              .from('profiles')
              .select('subscription_tier')
              .eq('id', user.id)
              .single();

          final sbTierStr = response['subscription_tier'] as String?;
          final sbTier = _parseTier(sbTierStr);

          // If Supabase has a valid paid tier, honor it (Cross-device / Web sync)
          if (sbTier != SubscriptionTier.homeCook) {
            // Update local cache to match Supabase, but DO NOT call _updateLocalState
            // because that would blindly trigger an RPC call. Just cache it.
            await _secureStorage.saveSubscriptionTier(_tierToString(sbTier));
            return sbTier;
          }
        } catch (_) {}
      }

      // 5. If both RC and Supabase say Home Cook (or SB failed), then it's Home Cook.
      if (currentTier != SubscriptionTier.homeCook) {
        // Only update local cache, DO NOT sync "Home Cook" to Supabase.
        // Let backend webhooks handle downgrades to be safe.
        await _secureStorage.saveSubscriptionTier('home_cook');
      }
      return SubscriptionTier.homeCook;
    } catch (e) {
      // 6. Fallback to cache on error (e.g. no internet)
      return currentTier;
    }
  }

  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      return null;
    }
  }

  Future<SubscriptionTier> purchasePackage(Package package) async {
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      final tier = _parseEntitlements(customerInfo);
      await _updateLocalState(tier);
      return tier;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        rethrow;
      }
      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    try {
      // Just fetch the latest info from Apple
      await Purchases.restorePurchases();
      // Use the smart logic to determine the actual tier
      // This prevents overwriting Supabase with "Home Cook" on a fresh device
      await getSubscriptionTier();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _updateLocalState(SubscriptionTier tier) async {
    await _secureStorage.saveSubscriptionTier(_tierToString(tier));

    // Sync to Supabase (Optional backup, mainly for web dashboard if any)
    final user = _client.auth.currentUser;
    // CRITICAL: Do NOT auto-downgrade Supabase to "Home Cook".
    // Only push Paid Upgrades. Let backend webhooks handle expiry/downgrades.
    if (user != null && tier != SubscriptionTier.homeCook) {
      try {
        await _client.rpc('upgrade_user_subscription', params: {
          'new_tier': _tierToString(tier),
        });
      } catch (_) {
        // Ignore backend sync error, local/IAP is source of truth
      }
    }
  }

  SubscriptionTier _parseEntitlements(CustomerInfo customerInfo) {
    if (customerInfo.entitlements.active
        .containsKey(StoreConfig.entitlementExecutiveChef)) {
      return SubscriptionTier.executiveChef;
    } else if (customerInfo.entitlements.active
        .containsKey(StoreConfig.entitlementSousChef)) {
      return SubscriptionTier.sousChef;
    }
    return SubscriptionTier.homeCook;
  }

  // Legacy Helpers
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

  // Deprecated: Replaced by purchasePackage
  Future<void> updateSubscriptionTier(SubscriptionTier tier) async {
    throw UnimplementedError("Use purchasePackage for IAP");
  }
}
