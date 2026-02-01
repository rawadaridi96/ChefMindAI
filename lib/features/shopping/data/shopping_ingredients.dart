/// Data model and repository for common shopping ingredients.
///
/// Provides a curated list of ~80 common ingredients organized by category,
/// with emoji icons or bundled SVG icons for visual display.

class ShoppingIngredient {
  final String name;
  final String category;
  final String imageUrl; // Legacy, kept for compatibility
  final String emoji; // Fallback if no SVG
  final String? svgPath; // Optional bundled SVG icon path
  final bool preferImage; // Whether to prefer imageUrl over emoji

  const ShoppingIngredient({
    required this.name,
    required this.category,
    required this.imageUrl,
    required this.emoji,
    this.svgPath,
    this.preferImage = false,
  });

  /// Whether this ingredient uses a bundled SVG icon
  bool get hasSvgIcon => svgPath != null;
}

/// Categories for organizing ingredients
/// These match the cart category dropdown for consistency
class IngredientCategory {
  static const String meatSeafood = 'Meat & Seafood';
  static const String produce = 'Produce';
  static const String dairyEggs = 'Dairy & Eggs';
  static const String pantry = 'Pantry';
  static const String herbsSpices = 'Herbs & Spices';

  static const List<String> all = [
    meatSeafood,
    produce,
    dairyEggs,
    pantry,
    herbsSpices,
  ];
}

/// Repository of common shopping ingredients
class ShoppingIngredientRepository {
  /// Get all ingredients
  static List<ShoppingIngredient> getAll() => _ingredients;

  /// Get ingredients by category
  static List<ShoppingIngredient> getByCategory(String category) {
    return _ingredients.where((i) => i.category == category).toList();
  }

  /// Search ingredients by name
  static List<ShoppingIngredient> search(String query) {
    final lower = query.toLowerCase();
    return _ingredients
        .where((i) => i.name.toLowerCase().contains(lower))
        .toList();
  }

  // Using Pexels-style URLs - these will fetch food images
  // Format: https://images.pexels.com/photos/{id}/pexels-photo-{id}.jpeg?auto=compress&cs=tinysrgb&w=200
  static String _pexelsUrl(String id) =>
      'https://images.pexels.com/photos/$id/pexels-photo-$id.jpeg?auto=compress&cs=tinysrgb&w=150';

  static const List<ShoppingIngredient> _ingredients = [
    // === MEAT & SEAFOOD ===
    ShoppingIngredient(
      name: 'Chicken',
      category: IngredientCategory.meatSeafood,
      imageUrl:
          'https://images.pexels.com/photos/616354/pexels-photo-616354.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍗',
    ),
    ShoppingIngredient(
      name: 'Beef',
      category: IngredientCategory.meatSeafood,
      imageUrl:
          'https://images.pexels.com/photos/1639557/pexels-photo-1639557.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥩',
    ),
    ShoppingIngredient(
      name: 'Salmon',
      category: IngredientCategory.meatSeafood,
      imageUrl:
          'https://images.pexels.com/photos/3296279/pexels-photo-3296279.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🐟',
    ),
    ShoppingIngredient(
      name: 'Shrimp',
      category: IngredientCategory.meatSeafood,
      imageUrl:
          'https://images.pexels.com/photos/725991/pexels-photo-725991.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🦐',
    ),
    ShoppingIngredient(
      name: 'Eggs',
      category: IngredientCategory.meatSeafood,
      imageUrl:
          'https://images.pexels.com/photos/162712/egg-white-food-protein-162712.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥚',
    ),
    ShoppingIngredient(
      name: 'Tofu',
      category: IngredientCategory.meatSeafood,
      imageUrl:
          'https://images.pexels.com/photos/4518643/pexels-photo-4518643.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🧊',
    ),
    ShoppingIngredient(
      name: 'Ground Beef',
      category: IngredientCategory.meatSeafood,
      imageUrl:
          'https://images.pexels.com/photos/128401/pexels-photo-128401.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥩',
    ),
    ShoppingIngredient(
      name: 'Bacon',
      category: IngredientCategory.meatSeafood,
      imageUrl:
          'https://images.pexels.com/photos/1927377/pexels-photo-1927377.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥓',
    ),
    ShoppingIngredient(
      name: 'Pork',
      category: IngredientCategory.meatSeafood,
      imageUrl:
          'https://images.pexels.com/photos/236478/pexels-photo-236478.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍖',
    ),
    ShoppingIngredient(
      name: 'Lamb',
      category: IngredientCategory.meatSeafood,
      imageUrl:
          'https://images.pexels.com/photos/618773/pexels-photo-618773.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍖',
    ),

    // === PRODUCE ===
    ShoppingIngredient(
      name: 'Tomato',
      category: IngredientCategory.produce,
      imageUrl:
          'https://images.pexels.com/photos/1327838/pexels-photo-1327838.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍅',
    ),
    ShoppingIngredient(
      name: 'Onion',
      category: IngredientCategory.produce,
      imageUrl:
          'https://images.pexels.com/photos/4197447/pexels-photo-4197447.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🧅',
    ),
    ShoppingIngredient(
      name: 'Garlic',
      category: IngredientCategory.produce,
      imageUrl:
          'https://images.pexels.com/photos/4197496/pexels-photo-4197496.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🧄',
    ),
    ShoppingIngredient(
      name: 'Carrot',
      category: IngredientCategory.produce,
      imageUrl:
          'https://images.pexels.com/photos/143133/pexels-photo-143133.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥕',
    ),
    ShoppingIngredient(
      name: 'Potato',
      category: IngredientCategory.produce,
      imageUrl:
          'https://images.pexels.com/photos/144248/potatoes-vegetables-erdfrucht-bio-144248.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥔',
    ),
    ShoppingIngredient(
      name: 'Broccoli',
      category: IngredientCategory.produce,
      imageUrl:
          'https://images.pexels.com/photos/47347/broccoli-vegetable-food-healthy-47347.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥦',
    ),
    ShoppingIngredient(
      name: 'Spinach',
      category: IngredientCategory.produce,
      imageUrl:
          'https://images.pexels.com/photos/2325843/pexels-photo-2325843.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍃',
    ),
    ShoppingIngredient(
      name: 'Lettuce',
      category: IngredientCategory.produce,
      imageUrl:
          'https://images.pexels.com/photos/1199562/pexels-photo-1199562.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥬',
    ),
    ShoppingIngredient(
      name: 'Bell Pepper',
      category: IngredientCategory.produce,
      imageUrl:
          'https://images.pexels.com/photos/1435904/pexels-photo-1435904.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🫑',
    ),
    ShoppingIngredient(
      name: 'Cucumber',
      category: IngredientCategory.produce,
      imageUrl:
          'https://images.pexels.com/photos/2329440/pexels-photo-2329440.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥒',
    ),
    ShoppingIngredient(
      name: 'Mushroom',
      category: IngredientCategory.produce,
      imageUrl:
          'https://images.pexels.com/photos/36438/mushrooms-brown-mushrooms-cook-eat.jpg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍄',
    ),
    ShoppingIngredient(
      name: 'Avocado',
      category: IngredientCategory.produce,
      imageUrl:
          'https://images.pexels.com/photos/557659/pexels-photo-557659.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥑',
    ),
    ShoppingIngredient(
      name: 'Lemon',
      category: IngredientCategory.produce,
      imageUrl:
          'https://images.pexels.com/photos/1414110/pexels-photo-1414110.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍋',
    ),
    ShoppingIngredient(
      name: 'Lime',
      category: IngredientCategory.produce,
      imageUrl:
          'https://images.pexels.com/photos/997725/pexels-photo-997725.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍋‍🟩',
    ),
    ShoppingIngredient(
      name: 'Ginger',
      category: IngredientCategory.produce,
      imageUrl:
          'https://images.pexels.com/photos/161556/ginger-plant-asia-rhizome-161556.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🫚',
    ),
    ShoppingIngredient(
      name: 'Zucchini',
      category: IngredientCategory.produce,
      imageUrl:
          'https://images.pexels.com/photos/128420/pexels-photo-128420.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥒',
    ),

    // === DAIRY & EGGS ===
    ShoppingIngredient(
      name: 'Milk',
      category: IngredientCategory.dairyEggs,
      imageUrl:
          'https://images.pexels.com/photos/248412/pexels-photo-248412.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥛',
    ),
    ShoppingIngredient(
      name: 'Cheese',
      category: IngredientCategory.dairyEggs,
      imageUrl:
          'https://images.pexels.com/photos/821365/pexels-photo-821365.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🧀',
    ),
    ShoppingIngredient(
      name: 'Butter',
      category: IngredientCategory.dairyEggs,
      imageUrl:
          'https://images.pexels.com/photos/531334/pexels-photo-531334.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🧈',
    ),
    ShoppingIngredient(
      name: 'Yogurt',
      category: IngredientCategory.dairyEggs,
      imageUrl:
          'https://images.pexels.com/photos/1435706/pexels-photo-1435706.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥣',
    ),
    ShoppingIngredient(
      name: 'Cream',
      category: IngredientCategory.dairyEggs,
      imageUrl:
          'https://images.pexels.com/photos/4110257/pexels-photo-4110257.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥛',
    ),
    ShoppingIngredient(
      name: 'Mozzarella',
      category: IngredientCategory.dairyEggs,
      imageUrl:
          'https://images.pexels.com/photos/6287544/pexels-photo-6287544.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🧀',
    ),
    ShoppingIngredient(
      name: 'Parmesan',
      category: IngredientCategory.dairyEggs,
      imageUrl:
          'https://images.pexels.com/photos/4109940/pexels-photo-4109940.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🧀',
    ),
    ShoppingIngredient(
      name: 'Sour Cream',
      category: IngredientCategory.dairyEggs,
      imageUrl:
          'https://images.pexels.com/photos/4110008/pexels-photo-4110008.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥛',
    ),

    // === PANTRY (GRAINS) ===
    ShoppingIngredient(
      name: 'Rice',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/4110251/pexels-photo-4110251.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍚',
    ),
    ShoppingIngredient(
      name: 'Pasta',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/1279330/pexels-photo-1279330.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍝',
    ),
    ShoppingIngredient(
      name: 'Bread',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/1775043/pexels-photo-1775043.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍞',
    ),
    ShoppingIngredient(
      name: 'Quinoa',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/6544376/pexels-photo-6544376.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥣',
    ),
    ShoppingIngredient(
      name: 'Oats',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/543730/pexels-photo-543730.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥣',
    ),
    ShoppingIngredient(
      name: 'Noodles',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/1907228/pexels-photo-1907228.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍜',
    ),
    ShoppingIngredient(
      name: 'Flour',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/5765/flour-powder-wheat-jar.jpg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥡',
    ),
    ShoppingIngredient(
      name: 'Tortillas',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/5737253/pexels-photo-5737253.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🫓',
    ),

    // === PANTRY ===
    ShoppingIngredient(
      name: 'Olive Oil',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/1022385/pexels-photo-1022385.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🫒',
    ),
    ShoppingIngredient(
      name: 'Sugar',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/4110101/pexels-photo-4110101.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍬',
    ),
    ShoppingIngredient(
      name: 'Honey',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/1638280/pexels-photo-1638280.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍯',
    ),
    ShoppingIngredient(
      name: 'Soy Sauce',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/6646218/pexels-photo-6646218.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍶',
      svgPath: 'assets/icons/ingredients/soy_sauce.png',
      preferImage: false,
    ),
    ShoppingIngredient(
      name: 'Vinegar',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/5946069/pexels-photo-5946069.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍶',
    ),
    ShoppingIngredient(
      name: 'Tomato Sauce',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/4110256/pexels-photo-4110256.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥫',
    ),
    ShoppingIngredient(
      name: 'Coconut Milk',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/4110471/pexels-photo-4110471.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥥',
    ),
    ShoppingIngredient(
      name: 'Canned Beans',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/6544245/pexels-photo-6544245.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥫',
    ),
    ShoppingIngredient(
      name: 'Peanut Butter',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/5217992/pexels-photo-5217992.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🥜',
    ),
    ShoppingIngredient(
      name: 'Chocolate',
      category: IngredientCategory.pantry,
      imageUrl:
          'https://images.pexels.com/photos/918327/pexels-photo-918327.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍫',
    ),

    // === HERBS & SPICES ===
    ShoppingIngredient(
      name: 'Salt',
      category: IngredientCategory.herbsSpices,
      imageUrl:
          'https://images.pexels.com/photos/6941010/pexels-photo-6941010.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🧂',
    ),
    ShoppingIngredient(
      name: 'Black Pepper',
      category: IngredientCategory.herbsSpices,
      imageUrl:
          'https://images.pexels.com/photos/4198939/pexels-photo-4198939.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '⚫',
    ),
    ShoppingIngredient(
      name: 'Cumin',
      category: IngredientCategory.herbsSpices,
      imageUrl:
          'https://images.pexels.com/photos/4198843/pexels-photo-4198843.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🪡',
    ),
    ShoppingIngredient(
      name: 'Paprika',
      category: IngredientCategory.herbsSpices,
      imageUrl:
          'https://images.pexels.com/photos/4198757/pexels-photo-4198757.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🌶️',
    ),
    ShoppingIngredient(
      name: 'Cinnamon',
      category: IngredientCategory.herbsSpices,
      imageUrl:
          'https://images.pexels.com/photos/4198770/pexels-photo-4198770.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🟤',
    ),
    ShoppingIngredient(
      name: 'Oregano',
      category: IngredientCategory.herbsSpices,
      imageUrl:
          'https://images.pexels.com/photos/4198839/pexels-photo-4198839.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍃',
    ),
    ShoppingIngredient(
      name: 'Basil',
      category: IngredientCategory.herbsSpices,
      imageUrl:
          'https://images.pexels.com/photos/1340116/pexels-photo-1340116.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🌿',
    ),
    ShoppingIngredient(
      name: 'Thyme',
      category: IngredientCategory.herbsSpices,
      imageUrl:
          'https://images.pexels.com/photos/4198717/pexels-photo-4198717.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🌿',
    ),
    ShoppingIngredient(
      name: 'Rosemary',
      category: IngredientCategory.herbsSpices,
      imageUrl:
          'https://images.pexels.com/photos/4198688/pexels-photo-4198688.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🌿',
    ),
    ShoppingIngredient(
      name: 'Turmeric',
      category: IngredientCategory.herbsSpices,
      imageUrl:
          'https://images.pexels.com/photos/4198813/pexels-photo-4198813.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🟡',
    ),
    ShoppingIngredient(
      name: 'Chili Flakes',
      category: IngredientCategory.herbsSpices,
      imageUrl:
          'https://images.pexels.com/photos/4198930/pexels-photo-4198930.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🌶️',
    ),
    ShoppingIngredient(
      name: 'Curry Powder',
      category: IngredientCategory.herbsSpices,
      imageUrl:
          'https://images.pexels.com/photos/4198826/pexels-photo-4198826.jpeg?auto=compress&cs=tinysrgb&w=150',
      emoji: '🍛',
    ),
  ];
}
