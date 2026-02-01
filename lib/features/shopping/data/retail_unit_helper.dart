import 'unit_normalizer.dart';

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

  // Density conversions: grams per cup for common dry ingredients
  // 1 cup = 48 tsp = 16 tbsp
  static const Map<String, double> _dryIngredientDensity = {
    // === FLOURS (grams per cup) ===
    'flour': 120.0,
    'all-purpose flour': 120.0,
    'whole wheat flour': 130.0,
    'bread flour': 127.0,
    'cake flour': 114.0,
    'almond flour': 96.0,
    'coconut flour': 112.0,
    'chickpea flour': 92.0,
    'oat flour': 120.0,
    'rice flour': 158.0,
    'semolina': 167.0,

    // === SUGARS (grams per cup) ===
    'sugar': 200.0,
    'granulated sugar': 200.0,
    'brown sugar': 220.0,
    'powdered sugar': 120.0,
    'icing sugar': 120.0,
    'confectioner\'s sugar': 120.0,
    'honey': 340.0,
    'maple syrup': 322.0,

    // === GRAINS & STARCHES (grams per cup) ===
    'rice': 200.0,
    'basmati rice': 200.0,
    'jasmine rice': 200.0,
    'brown rice': 190.0,
    'wild rice': 160.0,
    'quinoa': 170.0,
    'couscous': 157.0,
    'bulgur': 140.0,
    'barley': 200.0,
    'oats': 90.0,
    'rolled oats': 90.0,
    'steel cut oats': 176.0,
    'polenta': 163.0,
    'cornmeal': 156.0,
    'cornstarch': 128.0,
    'corn starch': 128.0,
    'breadcrumbs': 108.0,
    'panko': 60.0,

    // === PASTA (grams per cup, dry) ===
    'pasta': 100.0,
    'spaghetti': 100.0,
    'penne': 100.0,
    'macaroni': 100.0,
    'orzo': 170.0,
    'noodles': 85.0,

    // === LEGUMES (grams per cup, dry) ===
    'lentils': 192.0,
    'red lentils': 192.0,
    'green lentils': 192.0,
    'chickpeas': 164.0,
    'black beans': 194.0,
    'kidney beans': 184.0,
    'white beans': 179.0,
    'cannellini beans': 179.0,
    'pinto beans': 193.0,
    'navy beans': 208.0,
    'split peas': 196.0,

    // === NUTS & SEEDS (grams per cup) ===
    'almonds': 143.0,
    'walnuts': 120.0,
    'pecans': 109.0,
    'cashews': 137.0,
    'peanuts': 146.0,
    'hazelnuts': 135.0,
    'pistachios': 123.0,
    'pine nuts': 135.0,
    'macadamia nuts': 134.0,
    'sunflower seeds': 140.0,
    'pumpkin seeds': 129.0,
    'sesame seeds': 144.0,
    'chia seeds': 170.0,
    'flax seeds': 168.0,
    'flaxseed': 168.0,
    'poppy seeds': 145.0,

    // === CHOCOLATE & BAKING (grams per cup) ===
    'chocolate chips': 170.0,
    'cocoa powder': 85.0,
    'cocoa': 85.0,
    'coconut flakes': 85.0,
    'shredded coconut': 93.0,
    'raisins': 165.0,
    'dried cranberries': 120.0,
    'dried fruit': 140.0,

    // === DAIRY POWDERS (grams per cup) ===
    'milk powder': 68.0,
    'powdered milk': 68.0,
    'protein powder': 120.0,

    // === LEAVENERS & THICKENERS (grams per tsp) ===
    'baking powder': 4.0,
    'baking soda': 5.0,
    'yeast': 3.0,
    'active dry yeast': 3.0,
    'instant yeast': 3.0,
    'gelatin': 3.0,
    'xanthan gum': 2.5,
    'cream of tartar': 3.0,

    // === SALT (grams per tsp) ===
    'salt': 6.0,
    'table salt': 6.0,
    'sea salt': 5.0,
    'kosher salt': 4.8,
    'pink salt': 6.0,

    // === SPICES (grams per tsp) ===
    'black pepper': 2.3,
    'pepper': 2.3,
    'white pepper': 2.4,
    'cayenne': 1.8,
    'cayenne pepper': 1.8,
    'paprika': 2.3,
    'smoked paprika': 2.3,
    'cumin': 2.1,
    'ground cumin': 2.1,
    'coriander': 1.8,
    'ground coriander': 1.8,
    'turmeric': 3.0,
    'ginger': 1.8,
    'ground ginger': 1.8,
    'cinnamon': 2.6,
    'ground cinnamon': 2.6,
    'nutmeg': 2.2,
    'ground nutmeg': 2.2,
    'allspice': 1.9,
    'cloves': 2.1,
    'ground cloves': 2.1,
    'cardamom': 2.0,
    'curry powder': 2.0,
    'garam masala': 2.0,
    'chili powder': 2.6,
    'oregano': 1.0,
    'dried oregano': 1.0,
    'basil': 0.7,
    'dried basil': 0.7,
    'thyme': 0.8,
    'dried thyme': 0.8,
    'rosemary': 1.2,
    'dried rosemary': 1.2,
    'sage': 0.7,
    'dried sage': 0.7,
    'bay leaves': 0.6,
    'parsley': 0.5,
    'dried parsley': 0.5,
    'dill': 1.0,
    'dried dill': 1.0,
    'mint': 0.5,
    'dried mint': 0.5,
    'tarragon': 0.6,
    'fennel seeds': 2.0,
    'mustard seeds': 3.3,
    'mustard powder': 2.3,
    'onion powder': 2.4,
    'garlic powder': 2.8,
    'celery salt': 6.0,
    'italian seasoning': 1.0,
    'herbs de provence': 1.0,
  };

  // Ingredients where the density is "per tsp" instead of "per cup"
  static const Set<String> _perTspIngredients = {
    // Leaveners
    'baking powder', 'baking soda', 'yeast', 'active dry yeast',
    'instant yeast',
    'gelatin', 'xanthan gum', 'cream of tartar',
    // Salt
    'salt', 'table salt', 'sea salt', 'kosher salt', 'pink salt', 'celery salt',
    // All spices
    'black pepper', 'pepper', 'white pepper', 'cayenne', 'cayenne pepper',
    'paprika', 'smoked paprika', 'cumin', 'ground cumin', 'coriander',
    'ground coriander',
    'turmeric', 'ginger', 'ground ginger', 'cinnamon', 'ground cinnamon',
    'nutmeg', 'ground nutmeg', 'allspice', 'cloves', 'ground cloves',
    'cardamom',
    'curry powder', 'garam masala', 'chili powder',
    'oregano', 'dried oregano', 'basil', 'dried basil', 'thyme', 'dried thyme',
    'rosemary', 'dried rosemary', 'sage', 'dried sage', 'bay leaves',
    'parsley', 'dried parsley', 'dill', 'dried dill', 'mint', 'dried mint',
    'tarragon', 'fennel seeds', 'mustard seeds', 'mustard powder',
    'onion powder', 'garlic powder', 'italian seasoning', 'herbs de provence',
  };

  /// Converts a recipe ingredient amount to a retail-friendly unit.
  /// e.g. "1 tbsp Olive Oil" -> "1 Bottle"
  /// "1 pinch Salt" -> "1 Box"
  static String toRetailUnit(String name, String amount) {
    if (amount.trim().isEmpty) return '';

    final lowerName = name.toLowerCase().trim();
    final lowerAmount = amount.toLowerCase().trim();

    // FIRST: Check for qualitative amounts that don't have a specific quantity
    // These should be displayed as a checkmark (✓) or kept as-is
    final qualitativeAmounts = [
      'as needed',
      'to taste',
      'for garnish',
      'for serving',
      'optional',
      'sprinkle',
      'a sprinkle',
      'drizzle',
      'a drizzle',
      'few',
      'some',
      'enough',
    ];

    if (qualitativeAmounts.any((q) => lowerAmount.contains(q))) {
      // Return a checkmark to indicate "just buy it"
      return '✓';
    }

    // Parse quantity from amount string (e.g. "2 tbsp" -> 2.0)
    double qty = _parseQuantity(amount);
    if (qty <= 0) qty = 1;

    // SECOND: Check for metric units (g, kg, ml, L) - normalize to grocery format
    final metricUnits = ['g', 'kg', 'ml', 'l', 'liter', 'liters'];
    if (metricUnits.any((u) => lowerAmount.contains(u))) {
      final parsed = UnitNormalizer.parseAmountAndUnit(amount);
      if (parsed['type'] != UnitNormalizer.typeCount) {
        final baseResult = UnitNormalizer.toBaseUnit(
            parsed['amount'] as double, parsed['unit'] as String);
        return UnitNormalizer.toGroceryUnit(
            baseResult['baseAmount'] as double, baseResult['type'] as String);
      }
    }

    // THIRD: Check if this is a dry ingredient with volume - convert to grams
    final dryConversion = _convertDryIngredientToGrams(lowerName, lowerAmount);
    if (dryConversion != null) {
      return dryConversion;
    }

    // FOURTH: For other cooking measurements - preserve original amount
    final cookingUnits = [
      'tsp',
      'tbsp',
      'cup',
      'scoop',
      'pinch',
      'dash',
      'oz',
      'ounce',
      'lb',
    ];

    if (cookingUnits.any((u) => lowerAmount.contains(u))) {
      return amount;
    }

    // FIFTH: Only convert to pantry staple units if amount is a plain number
    if (_isPantryStaple(lowerName)) {
      return _getStapleUnit(lowerName, qty);
    }

    // Default: return original if no mapping logic applies
    return amount;
  }

  /// Converts dry ingredient volume measurements to grams
  static String? _convertDryIngredientToGrams(String name, String amountLower) {
    // Find matching dry ingredient
    String? matchedIngredient;
    double? gramsPerUnit;
    bool isPerTsp = false;

    for (final entry in _dryIngredientDensity.entries) {
      if (name.contains(entry.key)) {
        matchedIngredient = entry.key;
        gramsPerUnit = entry.value;
        isPerTsp = _perTspIngredients.contains(entry.key);
        break;
      }
    }

    if (matchedIngredient == null || gramsPerUnit == null) {
      return null; // Not a recognized dry ingredient
    }

    // Parse the amount and unit
    final parsed = UnitNormalizer.parseAmountAndUnit(amountLower);
    final amount = parsed['amount'] as double;
    final unit = (parsed['unit'] as String).toLowerCase();

    if (amount <= 0) return null;

    // Convert to grams based on unit type
    double grams;
    if (unit.contains('cup')) {
      // For per-tsp ingredients, 1 cup = 48 tsp
      grams = isPerTsp ? amount * gramsPerUnit * 48 : amount * gramsPerUnit;
    } else if (unit.contains('tbsp') || unit.contains('tablespoon')) {
      // 1 tbsp = 3 tsp, or 1/16 cup
      grams =
          isPerTsp ? amount * gramsPerUnit * 3 : amount * (gramsPerUnit / 16);
    } else if (unit.contains('tsp') || unit.contains('teaspoon')) {
      // For per-tsp ingredients, use directly
      // For per-cup ingredients, 1 tsp = 1/48 cup
      grams = isPerTsp ? amount * gramsPerUnit : amount * (gramsPerUnit / 48);
    } else {
      // Not a volume unit we can convert
      return null;
    }

    // Round to sensible precision
    if (grams < 1) {
      return '${grams.toStringAsFixed(1)} g';
    } else if (grams < 10) {
      return '${grams.round()} g';
    } else {
      // Round to nearest 5g for larger amounts
      final rounded = (grams / 5).round() * 5;
      return '$rounded g';
    }
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
