import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_storage_service.g.dart';

@Riverpod(keepAlive: true)
SecureStorageService secureStorageService(SecureStorageServiceRef ref) {
  return SecureStorageService();
}

class SecureStorageService {
  final _storage = const FlutterSecureStorage();

  static const String _keySubscriptionTier = 'chefmind_subscription_tier';

  Future<void> saveSubscriptionTier(String tier) async {
    await _storage.write(key: _keySubscriptionTier, value: tier);
  }

  Future<String?> getSubscriptionTier() async {
    return await _storage.read(key: _keySubscriptionTier);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
