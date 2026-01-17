import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';

part 'auth_repository.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository(Supabase.instance.client.auth);
}

class AuthRepository {
  final GoTrueClient _authClient;

  AuthRepository(this._authClient);

  Stream<AuthState> get authStateChanges => _authClient.onAuthStateChange;
  User? get currentUser => _authClient.currentUser;

  Future<void> signInWithEmail(String email, String password) async {
    await _authClient.signInWithPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail(String email, String password,
      {String? fullName}) async {
    await _authClient.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
  }

  Future<void> signInAnonymously() async {
    await _authClient.signInAnonymously();
  }

  Future<UserResponse> updateUser(
      {String? fullName, String? password, Map<String, dynamic>? data}) async {
    final Map<String, dynamic> finalData = {...?data};
    if (fullName != null) {
      finalData['full_name'] = fullName;
    }

    final attributes = UserAttributes(
      password: password,
      data: finalData.isNotEmpty ? finalData : null,
    );
    return await _authClient.updateUser(attributes);
  }

  Future<void> signOut() async {
    await _authClient.signOut();
  }

  Future<void> refreshSession() async {
    await _authClient.refreshSession();
  }

  Future<AuthResponse> signInWithGoogle() async {
    // Native Google Sign-In
    const webClientId =
        '1030484641058-7lmpe1hqiq2bds0shl7rfrv7huja23l5.apps.googleusercontent.com';
    const iosClientId =
        '1030484641058-m3hkb5jvqbtd0k6er8bi1s5um6m5kvkq.apps.googleusercontent.com';

    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: iosClientId,
      serverClientId: webClientId,
    );

    final googleUser = await googleSignIn.signIn();
    final googleAuth = await googleUser?.authentication;

    if (googleAuth == null) {
      throw 'Google Sign-In canceled.';
    }

    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw 'No ID Token found.';
    }

    return _authClient.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<AuthResponse> signInWithApple() async {
    final rawNonce = _generateRawNonce();
    final hashedNonce = _hashNonce(rawNonce);

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw 'No Identity Token found.';
    }

    return _authClient.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  Future<void> resetPassword(String email) async {
    await _authClient.resetPasswordForEmail(
      email,
      redirectTo: 'io.supabase.flutter://reset-callback/',
    );
  }

  Future<String> uploadProfileImage(String userId, File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final fileExt = imageFile.path.split('.').last;
    final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
    final filePath = '$userId/$fileName';

    await Supabase.instance.client.storage.from('avatars').uploadBinary(
        filePath, bytes,
        fileOptions: const FileOptions(upsert: true));

    return Supabase.instance.client.storage
        .from('avatars')
        .getPublicUrl(filePath);
  }

  Future<void> deleteProfileImage(String path) async {
    await Supabase.instance.client.storage.from('avatars').remove([path]);
  }

  /// Generates a random string of 32 characters to be used as a nonce
  String _generateRawNonce() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  /// Returns the sha256 hash of the [rawNonce]
  String _hashNonce(String rawNonce) {
    final bytes = utf8.encode(rawNonce);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
