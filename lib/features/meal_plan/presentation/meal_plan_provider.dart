import 'package:flutter_riverpod/flutter_riverpod.dart';

// Always enabled (Paywall handled in UI)
final mealPlanEnabledProvider = Provider<bool>((ref) {
  return true;
});
