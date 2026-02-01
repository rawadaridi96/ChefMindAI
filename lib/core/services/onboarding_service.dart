import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used to store onboarding completion status
const String _kOnboardingCompleteKey = 'onboarding_complete';
const String _kOnboardingDontShowKey = 'onboarding_dont_show';

/// Provider to check if onboarding should be shown
final shouldShowOnboardingProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final dontShow = prefs.getBool(_kOnboardingDontShowKey) ?? false;
  final completed = prefs.getBool(_kOnboardingCompleteKey) ?? false;
  return !dontShow && !completed;
});

/// Provider to manage onboarding state
final onboardingServiceProvider = Provider((ref) => OnboardingService());

class OnboardingService {
  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingCompleteKey) ?? false;
  }

  /// Check if user has opted to not show again
  Future<bool> dontShowAgain() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingDontShowKey) ?? false;
  }

  /// Mark onboarding as complete
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompleteKey, true);
  }

  /// Mark to never show onboarding again
  Future<void> setDontShowAgain(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingDontShowKey, value);
  }

  /// Reset onboarding (for "Show Tutorial Again" option)
  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompleteKey, false);
    await prefs.setBool(_kOnboardingDontShowKey, false);
  }

  /// Check if onboarding should be shown
  Future<bool> shouldShowOnboarding() async {
    final dontShow = await dontShowAgain();
    final completed = await hasCompletedOnboarding();
    return !dontShow && !completed;
  }
}
