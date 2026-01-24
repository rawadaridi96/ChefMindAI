import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'core/constants/supabase_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/services/locale_provider.dart';
import 'package:chefmind_ai/features/onboarding/presentation/entry_orchestrator.dart';

import 'package:chefmind_ai/features/home/home_screen.dart';
import 'package:chefmind_ai/features/auth/presentation/auth_state_provider.dart';
import 'package:chefmind_ai/features/import/presentation/global_import_listener.dart';
import 'package:chefmind_ai/core/services/deep_link_service.dart';
import 'core/services/offline_manager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.anonKey,
  );

  // Check Remember Me preference
  final prefs = await SharedPreferences.getInstance();
  final rememberMe = prefs.getBool('remember_me') ?? true;

  if (!rememberMe) {
    // Explicitly sign out before running the app if remember me is false
    // We suppress errors here in case it's already signed out
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }

  // Initialize Deep Link Listener
  DeepLinkService().init(navigatorKey);

  // Initialize Offline Manager (Hive + Connectivity)
  final container = ProviderContainer();
  await container.read(offlineManagerProvider).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ChefMindApp(),
    ),
  );
}

class ChefMindApp extends ConsumerWidget {
  const ChefMindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'ChefMindAI',
      navigatorKey: navigatorKey,
      theme: AppTheme.darkTheme,

      // Localization Configuration
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocaleNotifier.supportedLocales,
      locale: locale, // User-selected locale (null = system default)
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        // If user has set a locale, use it
        if (locale != null) return locale;
        // Otherwise, try to match device locale
        for (final supportedLocale in supportedLocales) {
          if (deviceLocale?.languageCode == supportedLocale.languageCode) {
            return supportedLocale;
          }
        }
        // Default to English
        return const Locale('en');
      },

      builder: (context, child) {
        // Wrap the entire app with the listener, passing the navigator key
        return GlobalImportListener(
          navigatorKey: navigatorKey,
          child: child!,
        );
      },
      home: Consumer(
        builder: (context, ref, _) {
          final authState = ref.watch(authStateChangesProvider);

          return authState.when(
            data: (state) {
              final session = state.session;
              if (session != null) {
                return const HomeScreen();
              } else {
                return const EntryOrchestrator();
              }
            },
            loading: () => const EntryOrchestrator(),
            error: (_, __) => const EntryOrchestrator(),
          );
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
