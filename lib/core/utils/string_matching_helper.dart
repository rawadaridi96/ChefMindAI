import 'dart:math';

class StringMatchingHelper {
  /// Calculates similarity between two strings (0.0 to 1.0)
  static double calculateSimilarity(String s1, String s2) {
    if (s1.toLowerCase() == s2.toLowerCase()) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final normalizedS1 = s1.toLowerCase().trim();
    final normalizedS2 = s2.toLowerCase().trim();

    int length = max(normalizedS1.length, normalizedS2.length);
    int dist = _levenshtein(normalizedS1, normalizedS2);
    return 1.0 - (dist / length);
  }

  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.filled(t.length + 1, 0);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < t.length + 1; i++) v0[i] = i;

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s.codeUnitAt(i) == t.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost]
            .reduce((curr, next) => min(curr, next));
      }
      for (int j = 0; j < t.length + 1; j++) v0[j] = v1[j];
    }
    return v1[t.length];
  }

  /// Checks if any pantry item matches the ingredient name using fuzzy logic
  static bool hasMatch(String ingredientName, List<String> pantryItemNames,
      {double threshold = 0.65}) {
    // 0.65 threshold allows:
    // "Chocolate" (9) vs "Chocolate Bar" (13) -> dist 4 -> sim 0.69 (MATCH)
    // "Pancakes" (8) vs "Cupcakes" (8) -> dist 3 -> sim 0.62 (NO MATCH) - Good

    final normalizedIng = ingredientName.toLowerCase();

    return pantryItemNames.any((pItem) {
      final normalizedP = pItem.toLowerCase();
      // 1. Direct Containment (Safety Net)
      if (normalizedIng.contains(normalizedP) ||
          normalizedP.contains(normalizedIng)) return true;

      // 2. Fuzzy
      return calculateSimilarity(normalizedIng, normalizedP) >= threshold;
    });
  }
}
