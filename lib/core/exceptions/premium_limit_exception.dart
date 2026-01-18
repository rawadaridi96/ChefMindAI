class PremiumLimitReachedException implements Exception {
  final String message;
  final String featureName;

  PremiumLimitReachedException(this.message, this.featureName);

  @override
  String toString() => message;
}
