/// Unit normalization utility for shopping cart calculations.
///
/// Converts all volumes to milliliters (ml) and weights to grams (g) before
/// summing, then converts back to readable "Grocery Units".
class UnitNormalizer {
  // Unit type enum
  static const String typeVolume = 'volume';
  static const String typeWeight = 'weight';
  static const String typeCount = 'count';

  // Standardized conversion factors

  // Volume (to ml)
  static const double lToMl = 1000.0;
  static const double tspToMl = 5.0;
  static const double tbspToMl = 15.0;
  static const double cupToMl = 240.0;
  static const double flOzToMl = 30.0;

  // Weight (to g)
  static const double kgToG = 1000.0;
  static const double ozToG = 28.0;
  static const double lbToG = 454.0;

  // Unit mappings
  static const Map<String, double> volumeUnits = {
    'ml': 1.0,
    'milliliter': 1.0,
    'milliliters': 1.0,
    'l': lToMl,
    'liter': lToMl,
    'liters': lToMl,
    'litre': lToMl,
    'litres': lToMl,
    'tsp': tspToMl,
    'teaspoon': tspToMl,
    'teaspoons': tspToMl,
    'tbsp': tbspToMl,
    'tablespoon': tbspToMl,
    'tablespoons': tbspToMl,
    'cup': cupToMl,
    'cups': cupToMl,
    'fl oz': flOzToMl,
    'fluid ounce': flOzToMl,
    'fluid ounces': flOzToMl,
  };

  static const Map<String, double> weightUnits = {
    'g': 1.0,
    'gram': 1.0,
    'grams': 1.0,
    'kg': kgToG,
    'kilogram': kgToG,
    'kilograms': kgToG,
    'oz': ozToG,
    'ounce': ozToG,
    'ounces': ozToG,
    'lb': lbToG,
    'lbs': lbToG,
    'pound': lbToG,
    'pounds': lbToG,
  };

  /// Parses an amount string into its components.
  /// Returns a map with 'amount' (double), 'unit' (String), and 'type' (String).
  ///
  /// Examples:
  /// - "500 ml" -> {amount: 500.0, unit: "ml", type: "volume"}
  /// - "2 cups" -> {amount: 2.0, unit: "cups", type: "volume"}
  /// - "1.5kg" -> {amount: 1.5, unit: "kg", type: "weight"}
  /// - "3" -> {amount: 3.0, unit: "", type: "count"}
  static Map<String, dynamic> parseAmountAndUnit(String input) {
    if (input.trim().isEmpty) {
      return {'amount': 0.0, 'unit': '', 'type': typeCount};
    }

    final clean = input.trim().toLowerCase();

    // First, try to extract a known unit from anywhere in the string
    // This handles cases like "1/2 cup (softened)" or "100g flour"
    String? foundUnit;
    String? foundType;

    // Check all known units (longer ones first to match "fluid ounce" before "ounce")
    final allUnits = <String>[...volumeUnits.keys, ...weightUnits.keys];
    allUnits
        .sort((a, b) => b.length.compareTo(a.length)); // Sort by length desc

    for (final unit in allUnits) {
      // Match unit as a word boundary (not part of another word)
      final unitRegex = RegExp(r'\b' + RegExp.escape(unit) + r'\b');
      if (unitRegex.hasMatch(clean)) {
        foundUnit = unit;
        foundType = _getUnitType(unit);
        break;
      }
    }

    // Extract the numeric amount (handles fractions and mixed numbers)
    // Matches: "500", "1.5", "1/2", "1 1/2"
    final amountRegex = RegExp(r'^(\d+\s+\d+/\d+|\d+/\d+|\d+(?:\.\d+)?)');
    final amountMatch = amountRegex.firstMatch(clean);

    if (amountMatch != null) {
      final amountStr = amountMatch.group(1) ?? '0';
      double amount = _parseAmountString(amountStr);

      if (foundUnit != null && foundType != null) {
        return {'amount': amount, 'unit': foundUnit, 'type': foundType};
      }

      // No known unit found, check if there's any text after the number
      final remaining = clean.substring(amountMatch.end).trim();
      if (remaining.isEmpty) {
        return {'amount': amount, 'unit': '', 'type': typeCount};
      }

      // Unknown unit text - treat as count
      return {'amount': amount, 'unit': remaining, 'type': typeCount};
    }

    // Fallback: try to extract just a number
    final numMatch = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(clean);
    if (numMatch != null) {
      return {
        'amount': double.tryParse(numMatch.group(1)!) ?? 0.0,
        'unit': foundUnit ?? '',
        'type': foundType ?? typeCount
      };
    }

    return {'amount': 0.0, 'unit': '', 'type': typeCount};
  }

  /// Parses a numeric string, handling fractions and mixed numbers.
  static double _parseAmountString(String str) {
    try {
      final trimmed = str.trim();

      // Handle mixed fractions like "1 1/2"
      if (trimmed.contains(' ') && trimmed.contains('/')) {
        final parts = trimmed.split(' ');
        if (parts.length == 2 && parts[1].contains('/')) {
          return double.parse(parts[0]) + _parseFraction(parts[1]);
        }
      }

      // Handle simple fractions like "1/2"
      if (trimmed.contains('/')) {
        return _parseFraction(trimmed);
      }

      return double.parse(trimmed);
    } catch (e) {
      return 0.0;
    }
  }

  /// Parses a fraction string like "1/2" into a double.
  static double _parseFraction(String frac) {
    try {
      final parts = frac.split('/');
      if (parts.length == 2) {
        return double.parse(parts[0]) / double.parse(parts[1]);
      }
    } catch (e) {}
    return 0.0;
  }

  /// Determines the unit type (volume, weight, or count).
  static String _getUnitType(String unit) {
    final lower = unit.toLowerCase().trim();
    if (lower.isEmpty) return typeCount;
    if (volumeUnits.containsKey(lower)) return typeVolume;
    if (weightUnits.containsKey(lower)) return typeWeight;
    return typeCount;
  }

  /// Converts an amount to its base unit (ml for volume, g for weight).
  /// Returns a map with 'baseAmount' (double) and 'type' (String).
  static Map<String, dynamic> toBaseUnit(double amount, String unit) {
    final lower = unit.toLowerCase().trim();

    if (volumeUnits.containsKey(lower)) {
      return {
        'baseAmount': amount * volumeUnits[lower]!,
        'type': typeVolume,
      };
    }

    if (weightUnits.containsKey(lower)) {
      return {
        'baseAmount': amount * weightUnits[lower]!,
        'type': typeWeight,
      };
    }

    // Unknown unit, treat as count
    return {'baseAmount': amount, 'type': typeCount};
  }

  /// Converts a base amount back to a readable grocery unit.
  ///
  /// For volume: ≥1000ml → L, <1000ml → ml
  /// For weight: ≥1000g → kg, <1000g → g
  static String toGroceryUnit(double baseAmount, String type) {
    if (type == typeVolume) {
      if (baseAmount >= 1000) {
        final liters = baseAmount / 1000;
        return '${_formatNumber(liters)} L';
      } else {
        return '${_formatNumber(baseAmount)} ml';
      }
    }

    if (type == typeWeight) {
      if (baseAmount >= 1000) {
        final kg = baseAmount / 1000;
        return '${_formatNumber(kg)} kg';
      } else {
        return '${_formatNumber(baseAmount)} g';
      }
    }

    // Count type
    return _formatNumber(baseAmount);
  }

  /// Formats a number for display (removes trailing zeros).
  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    // Round to 2 decimal places and remove trailing zeros
    String formatted = value.toStringAsFixed(2);
    formatted = formatted.replaceAll(RegExp(r'0*$'), '');
    formatted = formatted.replaceAll(RegExp(r'\.$'), '');
    return formatted;
  }

  /// Main entry point: aggregates multiple amount strings into a single result.
  ///
  /// Groups amounts by compatible unit types (volume/weight/count),
  /// sums each group in base units, and converts back to grocery units.
  ///
  /// When mixing unit types:
  /// - Same type: sums them (e.g., "500 ml" + "1 L" = "1.5 L")
  /// - Count + weight/volume: adds count to the unit-based amount (e.g., "2 g" + "1" = "3 g")
  /// - Volume + weight: joins with " + " (rare, usually a data issue)
  ///
  /// Examples:
  /// - ["500 ml", "1 L"] → "1.5 L"
  /// - ["200g", "800g"] → "1 kg"
  /// - ["2", "3"] → "5"
  /// - ["2 g", "1"] → "3 g"
  static String aggregateAmounts(List<String> amounts) {
    if (amounts.isEmpty) return '';

    double volumeTotal = 0.0;
    double weightTotal = 0.0;
    double countTotal = 0.0;

    bool hasVolume = false;
    bool hasWeight = false;
    bool hasCount = false;

    for (final amountStr in amounts) {
      if (amountStr.trim().isEmpty) continue;

      final parsed = parseAmountAndUnit(amountStr);
      final double amount = parsed['amount'];
      final String unit = parsed['unit'];
      final String type = parsed['type'];

      if (amount <= 0) continue;

      if (type == typeVolume) {
        final base = toBaseUnit(amount, unit);
        volumeTotal += base['baseAmount'];
        hasVolume = true;
      } else if (type == typeWeight) {
        final base = toBaseUnit(amount, unit);
        weightTotal += base['baseAmount'];
        hasWeight = true;
      } else {
        countTotal += amount;
        hasCount = true;
      }
    }

    // If we have counts mixed with weight or volume, add count to the unit-based amount
    // This handles cases like "2 g" + "1" = "3 g" instead of "2 g + 1"
    if (hasCount && countTotal > 0) {
      if (hasWeight && !hasVolume) {
        // Add count to weight (assume count represents the base unit)
        weightTotal += countTotal;
        hasCount = false;
        countTotal = 0;
      } else if (hasVolume && !hasWeight) {
        // Add count to volume (assume count represents the base unit)
        volumeTotal += countTotal;
        hasCount = false;
        countTotal = 0;
      }
    }

    // Build result string
    List<String> results = [];

    if (hasVolume && volumeTotal > 0) {
      results.add(toGroceryUnit(volumeTotal, typeVolume));
    }

    if (hasWeight && weightTotal > 0) {
      results.add(toGroceryUnit(weightTotal, typeWeight));
    }

    if (hasCount && countTotal > 0) {
      results.add(_formatNumber(countTotal));
    }

    return results.join(' + ');
  }

  /// Checks if a unit string represents a known metric/volume/weight unit.
  static bool isKnownUnit(String unit) {
    final lower = unit.toLowerCase().trim();
    return volumeUnits.containsKey(lower) || weightUnits.containsKey(lower);
  }

  /// Checks if an amount string contains a known unit.
  static bool containsKnownUnit(String amountStr) {
    final parsed = parseAmountAndUnit(amountStr);
    return parsed['type'] != typeCount || parsed['unit'].toString().isEmpty;
  }
}
