import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for the current locale
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

/// Notifier that manages locale state and persistence
class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _loadSavedLocale();
  }

  static const String _localeKey = 'app_locale';

  /// Supported locales
  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('ar'), // Arabic
    Locale('fr'), // French
    Locale('es'), // Spanish
    Locale('zh'), // Chinese
    Locale('hi'), // Hindi
    Locale('pt'), // Portuguese
  ];

  /// Load saved locale from SharedPreferences
  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_localeKey);

    if (savedLocale != null) {
      state = Locale(savedLocale);
    }
    // If null, app will use system default via localeResolutionCallback
  }

  /// Set and persist a new locale
  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }

  /// Clear saved locale (use system default)
  Future<void> clearLocale() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localeKey);
  }

  /// Get display name for a locale
  static String getDisplayName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'ar':
        return 'العربية';
      case 'fr':
        return 'Français';
      case 'es':
        return 'Español';
      case 'zh':
        return '简体中文';
      case 'hi':
        return 'हिन्दी';
      case 'pt':
        return 'Português';
      default:
        return languageCode;
    }
  }

  /// Get flag emoji for a locale
  static String getFlag(String languageCode) {
    switch (languageCode) {
      case 'en':
        return '🇺🇸';
      case 'ar':
        return '🇸🇦';
      case 'fr':
        return '🇫🇷';
      case 'es':
        return '🇪🇸';
      case 'zh':
        return '🇨🇳';
      case 'hi':
        return '🇮🇳';
      case 'pt':
        return '🇧🇷';
      default:
        return '🌐';
    }
  }
}
