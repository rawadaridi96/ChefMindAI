import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:chefmind_ai/core/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io';
import '../data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

part 'auth_controller.g.dart';

@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  final _storage = const FlutterSecureStorage();

  @override
  FutureOr<void> build() {
    // no-op
  }

  Future<void> signIn(String email, String password,
      {bool rememberMe = true}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInWithEmail(email, password);

      final prefs = await SharedPreferences.getInstance();

      // Only persistent if successful ("Remember Me")
      if (rememberMe) {
        await prefs.setBool('remember_me', true);
        await prefs.setString('saved_email', email);
      } else {
        await prefs.setBool('remember_me', false);
        await prefs.remove('saved_email');
      }

      final user = repo.currentUser;
      final name = user?.userMetadata?['full_name'] ?? 'Chef';
      ref.read(postLoginMessageProvider.notifier).state =
          "Welcome back, $name!";
    });
  }

  Future<void> signUp(String email, String password,
      {String? fullName, bool rememberMe = true}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        await ref
            .read(authRepositoryProvider)
            .signUpWithEmail(email, password, fullName: fullName);

        final prefs = await SharedPreferences.getInstance();

        await prefs.setBool('remember_me', rememberMe);
        if (rememberMe) {
          await prefs.setString('saved_email', email);
        } else {
          await prefs.remove('saved_email');
        }
      } on AuthException catch (e) {
        if (e.code == 'over_email_send_rate_limit' || e.statusCode == '429') {
          throw 'Please wait a moment before requesting another email.';
        }
        throw e.message;
      } catch (e) {
        rethrow;
      }

      ref.read(postLoginMessageProvider.notifier).state =
          "Account created! Welcome to ChefMind.";
    });
  }

  Future<void> signInAnonymously() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInAnonymously();
      // Important: Guest sessions usually don't need 'Remember Me' for email/pass
      // but Supabase persists the session automatically.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', true);
      ref.read(postLoginMessageProvider.notifier).state =
          "Welcome, Guest Chef!";
    });
  }

  Future<void> updateProfile({String? fullName, String? password}) async {
    await ref.read(authRepositoryProvider).updateUser(
        fullName: fullName != null && fullName.isNotEmpty ? fullName : null,
        password: password != null && password.isNotEmpty ? password : null);

    // If password was updated, we should update stored biometric credentials if they exist
    if (password != null && password.isNotEmpty) {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        // Check if user has biometrics enabled
        final accounts = await getBiometricAccounts();
        final hasBiometrics = accounts.any((acc) => acc['userId'] == user.id);
        if (hasBiometrics) {
          // Update the stored password
          await _storage.write(
              key: 'biometric_pass_${user.id}', value: password);
        }
      }
    }
  }

  Future<void> updateDietaryPreferences(List<String> preferences) async {
    await ref.read(authRepositoryProvider).updateUser(data: {
      'dietary_preferences': preferences,
    });
  }

  // --- Biometric Management ---

  Future<void> storeBiometricCredentials(
      String email, String password, String userId,
      {String? displayName, String? avatarUrl}) async {
    // 1. Store the password securely
    await _storage.write(key: 'biometric_pass_$userId', value: password);

    // 2. Update the list of accounts
    final accounts = await getBiometricAccounts();

    // Remove existing entry for this user if any (to update it)
    accounts.removeWhere((acc) => acc['userId'] == userId);

    // Add new entry
    accounts.add({
      'userId': userId,
      'email': email,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'enrolledAt': DateTime.now().toIso8601String(),
    });

    // Save list
    await _storage.write(
        key: 'biometric_accounts', value: jsonEncode(accounts));

    // Also save preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', true);
  }

  Future<List<Map<String, dynamic>>> getBiometricAccounts() async {
    final jsonStr = await _storage.read(key: 'biometric_accounts');
    if (jsonStr == null) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> removeBiometricAccount(String userId) async {
    // 1. Remove password
    await _storage.delete(key: 'biometric_pass_$userId');

    // 2. Remove from list
    final accounts = await getBiometricAccounts();
    accounts.removeWhere((acc) => acc['userId'] == userId);
    await _storage.write(
        key: 'biometric_accounts', value: jsonEncode(accounts));

    // If list empty, update pref
    if (accounts.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', false);
    }
  }

  Future<void> authenticateWithBiometrics(String userId) async {
    try {
      state = const AsyncLoading();
      final password = await _storage.read(key: 'biometric_pass_$userId');

      // Find email from accounts list
      final accounts = await getBiometricAccounts();
      final account = accounts.firstWhere((acc) => acc['userId'] == userId,
          orElse: () => {});
      final email = account['email'] as String?;

      if (email == null || password == null) {
        throw Exception("Credentials not found. Please log in manually.");
      }

      final LocalAuthentication auth = LocalAuthentication();
      bool didAuthenticate = false;
      try {
        didAuthenticate = await auth.authenticate(
          localizedReason: 'Please authenticate to log in',
          options: const AuthenticationOptions(stickyAuth: true),
        );
      } catch (e) {
        if (e is PlatformException) {
          switch (e.code) {
            case 'LockedOut':
            case 'PermanentlyLockedOut':
            case 'Other':
            case 'auth_in_progress':
              HapticFeedback.heavyImpact();
              throw Exception("Biometric authentication failed");
            case 'NotAvailable':
            case 'PasscodeNotSet':
            case 'NotEnrolled':
              HapticFeedback.mediumImpact();
              throw Exception("Biometrics not available");
            default:
              didAuthenticate = false;
          }
        } else {
          didAuthenticate = false;
        }
      }

      if (didAuthenticate) {
        await ref.read(authRepositoryProvider).signInWithEmail(email, password);
        final user = ref.read(authRepositoryProvider).currentUser;
        final name = account['displayName'] ??
            user?.userMetadata?['full_name'] ??
            'Chef';
        ref.read(postLoginMessageProvider.notifier).state =
            "Welcome back, $name!";
        state = const AsyncData(null);
      } else {
        // User cancelled or silent failure.
        // Reset state so loading spinner disappears if any, but do NOT show error.
        state = const AsyncData(null);
      }
    } catch (e, st) {
      // Catch "Bad state: Future already completed" and ignore it
      if (e.toString().contains("Bad state") ||
          e.toString().contains("Future already completed")) {
        state = const AsyncData(null);
        return;
      }
      state = AsyncError(e, st);
    }
  }

  // --- End Biometric Management ---

  Future<void> uploadProfilePicture(File image) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) throw Exception("User not logged in");

    // Check for existing avatar to delete later
    final oldUrl = user.userMetadata?['avatar_url'] as String?;

    // Upload image
    final url = await ref
        .read(authRepositoryProvider)
        .uploadProfileImage(user.id, image);

    // Update user metadata
    await ref
        .read(authRepositoryProvider)
        .updateUser(data: {'avatar_url': url});

    // Update local biometric account metadata if exists
    final accounts = await getBiometricAccounts();
    final index = accounts.indexWhere((acc) => acc['userId'] == user.id);
    if (index != -1) {
      accounts[index]['avatarUrl'] = url;
      await _storage.write(
          key: 'biometric_accounts', value: jsonEncode(accounts));
    }

    // If successful, try to delete the old image
    if (oldUrl != null) {
      try {
        final uri = Uri.parse(oldUrl);
        final pathSegments = uri.pathSegments;
        final avatarIndex = pathSegments.indexOf('avatars');
        if (avatarIndex != -1 && avatarIndex + 1 < pathSegments.length) {
          final path = pathSegments.sublist(avatarIndex + 1).join('/');
          await ref.read(authRepositoryProvider).deleteProfileImage(path);
        }
      } catch (_) {}
    }

    // Force refresh session to ensure UI updates
    try {
      await ref.read(authRepositoryProvider).refreshSession();
    } catch (_) {}
  }

  Future<void> removeProfilePicture() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final oldUrl = user?.userMetadata?['avatar_url'] as String?;

    // Update user metadata with null avatar_url to remove it
    await ref
        .read(authRepositoryProvider)
        .updateUser(data: {'avatar_url': null});

    if (user != null) {
      // Update local biometric account metadata if exists
      final accounts = await getBiometricAccounts();
      final index = accounts.indexWhere((acc) => acc['userId'] == user.id);
      if (index != -1) {
        accounts[index]['avatarUrl'] = null;
        await _storage.write(
            key: 'biometric_accounts', value: jsonEncode(accounts));
      }
    }

    // Delete file from storage
    if (oldUrl != null) {
      try {
        final uri = Uri.parse(oldUrl);
        final pathSegments = uri.pathSegments;
        final avatarIndex = pathSegments.indexOf('avatars');
        if (avatarIndex != -1 && avatarIndex + 1 < pathSegments.length) {
          final path = pathSegments.sublist(avatarIndex + 1).join('/');
          await ref.read(authRepositoryProvider).deleteProfileImage(path);
        }
      } catch (_) {}
    }

    try {
      await ref.read(authRepositoryProvider).refreshSession();
    } catch (_) {}
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // Clear remember me on explicit sign out?
      // Usually "Remember Me" means "Keep me logged in across restarts".
      // Explicit "Sign Out" usually implies "Forget me".
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', false);

      await ref.read(authRepositoryProvider).signOut();
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        await ref.read(authRepositoryProvider).signInWithGoogle();
        // Assume social login implies "Remember Me" unless checked otherwise?
        // For simplicity, we default to true for social auth for now.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('remember_me', true);
        ref.read(postLoginMessageProvider.notifier).state =
            "Signed in with Google!";
      } catch (e) {
        // Propagate error but maybe map specific codes if needed
        if (e.toString().contains('10')) {
          throw 'Google Sign-In Configuration Error (SHA-1). See Setup Guide.';
        }
        rethrow;
      }
    });
  }

  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInWithApple();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', true);
      ref.read(postLoginMessageProvider.notifier).state =
          "Signed in with Apple!";
    });
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(authRepositoryProvider).resetPassword(email));
  }
}

// Simple provider to pass success messages from AuthSheet (which unmounts) to HomeScreen
final postLoginMessageProvider = StateProvider<String?>((ref) => null);
