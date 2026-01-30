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
  final int? limit;

  PremiumLimitReachedException(this.message, this.featureName, this.type,
      {this.limit});

  @override
  String toString() => "PremiumLimitReachedException: $message";
}
