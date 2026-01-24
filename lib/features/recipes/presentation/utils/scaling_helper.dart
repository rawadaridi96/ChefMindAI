import 'package:chefmind_ai/features/shopping/data/retail_unit_helper.dart';

class ScalingHelper {
  /// Parses an ingredient string into its components.
  /// Example: "1 1/2 cups Flour" -> {amount: 1.5, unit: "cups", name: "Flour"}
  static Map<String, dynamic> parseIngredient(String raw) {
    if (raw.trim().isEmpty) return {'amount': 0.0, 'unit': '', 'name': ''};

    final clean = raw.trim();
    // Regex to capture:
    // 1. Amount (integers, decimals, fractions like 1 1/2 or 1/2)
    // 2. The rest (Unit + Name), allowing optional space
    // e.g. "20g" captured as "20", "", "g"
    final amountRegex = RegExp(r'^(\d+\s+\d+/\d+|\d+/\d+|\d+(\.\d+)?)\s*(.*)$');

    final match = amountRegex.firstMatch(clean);

    if (match != null) {
      final amountStr = match.group(1) ?? '0';
      final rest = match.group(3) ?? ''; // group 3 is (.*)

      double amount = _parseAmountString(amountStr);

      // Try to separate Unit from Name (basic heuristic)
      // We can use known units from RetailUnitHelper if available, or a local list
      final unitResult = _extractUnit(rest);

      return {
        'amount': amount,
        'unit': unitResult['unit'],
        'name': unitResult['name'],
        'original': raw
      };
    }

    // Fallback for no amount found (e.g. "Salt to taste")
    return {'amount': 0.0, 'unit': '', 'name': clean, 'original': raw};
  }

  static double _parseAmountString(String str) {
    try {
      if (str.contains(' ')) {
        // Mixed fraction "1 1/2"
        final parts = str.split(' ');
        if (parts.length == 2 && parts[1].contains('/')) {
          return double.parse(parts[0]) + _parseFraction(parts[1]);
        }
      }
      if (str.contains('/')) {
        return _parseFraction(str);
      }
      return double.parse(str);
    } catch (e) {
      return 0.0;
    }
  }

  static double _parseFraction(String frac) {
    try {
      final parts = frac.split('/');
      return double.parse(parts[0]) / double.parse(parts[1]);
    } catch (e) {
      return 0.0;
    }
  }

  static Map<String, String> _extractUnit(String text) {
    final units = [
      'tsp',
      'teaspoon',
      'tbsp',
      'tablespoon',
      'cup',
      'oz',
      'ounce',
      'lb',
      'pound',
      'g',
      'gram',
      'kg',
      'kilogram',
      'ml',
      'l',
      'liter',
      'pinch',
      'dash',
      'clove',
      'slice',
      'piece',
      'can',
      'bottle',
      'box',
      'bag'
    ];

    final parts = text.split(' ');
    if (parts.isNotEmpty) {
      final potentialUnit =
          parts[0].toLowerCase().replaceAll(RegExp(r's$'), ''); // singularize
      if (units.contains(potentialUnit) ||
          units.any((u) => potentialUnit.startsWith(u))) {
        // It's a unit
        final unit = parts[0];
        final name = parts.skip(1).join(' ');
        return {'unit': unit, 'name': name};
      }

      // Regex check for attached unit e.g. "200g" -> handled by split earlier?
      // If we passed "g" here as text, potentialUnit is "g". It matches.
    }

    return {'unit': '', 'name': text};
  }

  /// Scales an ingredient string by a factor.
  static String scaleIngredient(String raw, double factor) {
    final parsed = parseIngredient(raw);
    final double amount = parsed['amount'];

    if (amount <= 0) return raw; // Don't scale "Salt to taste"

    final scaledAmount = amount * factor;

    // Format the new amount
    String amountStr = _formatAmount(scaledAmount);

    String unit = parsed['unit'];
    String name = parsed['name'];

    // Basic pluralization fix
    if (unit.isNotEmpty) {
      if (scaledAmount > 1 && !unit.endsWith('s') && !unit.endsWith('z')) {
        if ([
          'cup',
          'spoon',
          'pinch',
          'dash',
          'slice',
          'piece',
          'can',
          'bottle',
          'bag',
          'box',
          'clove'
        ].any((u) => unit.toLowerCase().contains(u))) {
          unit += 's';
        }
      }
    }

    if (unit.isNotEmpty) {
      return "$amountStr $unit $name".trim();
    } else {
      return "$amountStr $name".trim();
    }
  }

  static String _formatAmount(double amount) {
    if (amount % 1 == 0) return amount.toInt().toString();

    final fractionalPart = amount - amount.toInt();
    final wholePart = amount.toInt();

    const double tolerance = 0.05;

    String fraction = '';
    if ((fractionalPart - 0.25).abs() < tolerance)
      fraction = "1/4";
    else if ((fractionalPart - 0.5).abs() < tolerance)
      fraction = "1/2";
    else if ((fractionalPart - 0.75).abs() < tolerance)
      fraction = "3/4";
    else if ((fractionalPart - 0.33).abs() < tolerance)
      fraction = "1/3";
    else if ((fractionalPart - 0.66).abs() < tolerance) fraction = "2/3";

    if (fraction.isNotEmpty) {
      if (wholePart > 0) return "$wholePart $fraction";
      return fraction;
    }

    return amount
        .toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)
        .replaceAll(RegExp(r'0*$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  static Map<String, dynamic> scaleMacros(
      Map<String, dynamic> outputMacros, double factor) {
    final newMacros = Map<String, dynamic>.from(outputMacros);

    newMacros.forEach((key, value) {
      if (value is String) {
        final match = RegExp(r'^(\d+(\.\d+)?)(\D*)$').firstMatch(value.trim());
        if (match != null) {
          final val = double.parse(match.group(1)!);
          final unit = match.group(3) ?? '';

          final scaledVal = val * factor;

          newMacros[key] = "${scaledVal.toInt()}$unit";
        }
      }
    });

    return newMacros;
  }

  /// Scales just the amount string (e.g. "1/2" -> "1").
  /// Returns the formatted string.
  static String scaleAmount(String amountStr, double factor) {
    if (amountStr.trim().isEmpty) return '';
    // Use scaleIngredient because it handles units and mixed text robustly
    return scaleIngredient(amountStr, factor);
  }
}
