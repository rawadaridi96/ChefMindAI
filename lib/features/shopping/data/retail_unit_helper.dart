class RetailUnitHelper {
  static const Set<String> _pantryStaples = {
    'oil',
    'olive oil',
    'vegetable oil',
    'salt',
    'black pepper',
    'pepper',
    'sugar',
    'flour',
    'vinegar',
    'soy sauce',
    'spices',
    'butter', // Sometimes a staple
  };

  /// Converts a recipe ingredient amount to a retail-friendly unit.
  /// e.g. "1 tbsp Olive Oil" -> "1 Bottle"
  /// "1 pinch Salt" -> "1 Box"
  static String toRetailUnit(String name, String amount) {
    if (amount.trim().isEmpty) return '';

    final lowerName = name.toLowerCase().trim();

    // Parse quantity from amount string (e.g. "2 tbsp" -> 2.0)
    double qty = _parseQuantity(amount);
    if (qty <= 0) qty = 1;

    // Check if it's a staple
    if (_isPantryStaple(lowerName)) {
      return _getStapleUnit(lowerName, qty);
    }

    // Check for cooking measurements to simplify
    // e.g. "1 tsp", "1/4 cup", "300g", "pinch"
    final cookingUnits = [
      'tsp',
      'tbsp',
      'cup',
      'scoop',
      'pinch',
      'dash',
      'gram',
      'g ',
      'kg',
      'oz',
      'ounce',
      'lb',
      'ml',
      'liter'
    ];

    final lowerAmount = amount.toLowerCase();
    if (cookingUnits.any((u) => lowerAmount.contains(u))) {
      return qty % 1 == 0
          ? '${qty.toInt()} Unit${qty > 1 ? 's' : ''}'
          : '$qty Unit${qty > 1 ? 's' : ''}';
    }

    // Default return original if no mapping logic applies
    return amount;
  }

  static bool _isPantryStaple(String name) {
    // Simple check: does the name contain any of the staple keywords?
    return _pantryStaples.any((s) => name.contains(s));
  }

  static String _getStapleUnit(String name, double qty) {
    String unit = 'Unit';
    if (name.contains('salt')) {
      unit = 'Box';
    } else if (name.contains('sugar')) {
      unit = 'Bag';
    } else if (name.contains('flour')) {
      unit = 'Bag';
    } else if (name.contains('oil')) {
      unit = 'Bottle';
    } else if (name.contains('vinegar')) {
      unit = 'Bottle';
    } else if (name.contains('soy sauce')) {
      unit = 'Bottle';
    } else if (name.contains('pepper')) {
      unit = 'Jar';
    } else if (name.contains('spice')) {
      unit = 'Jar';
    }

    // Pluralize
    // Pluralize
    if (qty > 1) {
      if (unit == 'Box') {
        unit = 'Boxes';
      } else {
        unit += 's';
      }
    }

    return qty % 1 == 0 ? '${qty.toInt()} $unit' : '$qty $unit';
  }

  static double _parseQuantity(String amount) {
    try {
      final clean = amount.toLowerCase().trim();
      // Handle fractions like "1/4"
      if (clean.contains('/')) {
        final parts = clean.split('/');
        if (parts.length == 2) {
          return (double.parse(parts[0]) / double.parse(parts[1]));
        }
      }

      final match = RegExp(r'^(\d+(\.\d+)?)').firstMatch(clean);
      if (match != null) {
        return double.parse(match.group(1)!);
      }
    } catch (_) {}
    return 1.0;
  }

  /// Extracts the core ingredient name from a raw string.
  /// cleaning up adjectives like "Large", "Small", "Fresh".
  static String extractCoreIngredientName(String input) {
    var clean = input;

    // 1. Remove common descriptors (case insensitive)
    final descriptors = [
      'large',
      'medium',
      'small',
      'extra large',
      'jumbo',
      'fresh',
      'dried',
      'ground',
      'chopped',
      'sliced',
      'whole',
      'grated',
      'minced'
    ];

    for (final desc in descriptors) {
      // Regex matches "Large " or " Large" ensuring word boundary
      final regex = RegExp(r'\b' + desc + r'\b', caseSensitive: false);
      clean = clean.replaceAll(regex, '');
    }

    // Clean up double spaces and trim
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Capitalize first letter
    if (clean.isNotEmpty) {
      clean = "${clean[0].toUpperCase()}${clean.substring(1)}";
    }

    final lowerInfo = clean.toLowerCase();

    // Check against known staples for perfect matches
    for (final staple in _pantryStaples) {
      if (lowerInfo.contains(staple)) {
        return staple
            .split(' ')
            .map((str) => str.isNotEmpty
                ? "${str[0].toUpperCase()}${str.substring(1)}"
                : "")
            .join(' ');
      }
    }

    return clean;
  }
}
