import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chefmind_ai/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chefmind_ai/features/auth/presentation/auth_state_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('ChefMind App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(
                AuthState(AuthChangeEvent.signedOut, null),
              )),
        ],
        child: const ChefMindApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Expect to see AuthScreen
    expect(find.text('ChefMind AI'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
