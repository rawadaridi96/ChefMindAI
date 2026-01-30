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
      final tier = _parseEntitlements(customerInfo);
      await _updateLocalState(tier);
    });
  }

  Future<SubscriptionTier> getSubscriptionTier() async {
    // 1. Try Local Cache First
    final cachedTier = await _secureStorage.getSubscriptionTier();

    try {
      // 2. Fetch fresh from RevenueCat
      final customerInfo = await Purchases.getCustomerInfo();
      final tier = _parseEntitlements(customerInfo);

      // 3. Update Cache & Backend
      if (tier != _parseTier(cachedTier)) {
        await _updateLocalState(tier);
      }
      return tier;
    } catch (e) {
      // 4. Fallback to cache
      if (cachedTier != null) {
        return _parseTier(cachedTier);
      }
      return SubscriptionTier.homeCook;
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
      // If cancelled, return current tier (or throw cancelled exception if preferred, but usually we just ignore)
      // Actually, better to rethrow strictly so UI knows it failed/cancelled.
      // Rethrowing allows the controller to handle the error state or cancellation.
      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      final tier = _parseEntitlements(customerInfo);
      await _updateLocalState(tier);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _updateLocalState(SubscriptionTier tier) async {
    await _secureStorage.saveSubscriptionTier(_tierToString(tier));

    // Sync to Supabase (Optional backup, mainly for web dashboard if any)
    final user = _client.auth.currentUser;
    if (user != null) {
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
