enum PremiumLimitType {
  vaultFull,
  dailyShareLimit,
  executiveFeatureMood,
  sousFeatureADI,
  dailyRecipeLimit,
}

class PremiumLimitReachedException implements Exception {
  final String message;
  final String featureName;
  final PremiumLimitType type;

  PremiumLimitReachedException(this.message, this.featureName, this.type);

  @override
  String toString() => message;
}
