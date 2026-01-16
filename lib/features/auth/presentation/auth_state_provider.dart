import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_state_provider.g.dart';

@riverpod
Stream<AuthState> authStateChanges(AuthStateChangesRef ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
}
