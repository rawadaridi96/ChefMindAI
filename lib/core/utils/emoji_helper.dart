class EmojiHelper {
  static String? getEmoji(String ingredientName) {
    final name = ingredientName.toLowerCase().trim();

    // 1. Liquids, Oils, Vinegars (Specific Logic First)
    if (name.contains('vinegar') || name.contains('soy sauce'))
      return '🍾'; // Generic dark glass bottle
    if (name.contains('olive oil')) return '🏺'; // Amphora (Classic Oil Jar)
    if (name.contains('sesame oil')) return '🍾';
    if (name.contains('oil')) return '🍾'; // Generic Oil -> Bottle
    if (name.contains('sauce') && !name.contains('apple'))
      return '🥫'; // Canned/Jarred sauce (excluding applesauce)

    // 2. Citrus & Juices (Prioritize Fruit if it's "Juice of X")
    // "Lime Juice" -> Lime, "Lemon Juice" -> Lemon
    if (name.contains('lemon')) return '🍋';
    if (name.contains('lime')) return '🍋‍🟩';
    if (name.contains('orange') && !name.contains('juice'))
      return '🍊'; // Orange Fruit
    if (name.contains('orange juice')) return '🧃'; // Orange Juice -> Box
    if (name.contains('juice')) return '🧃'; // Generic Juice

    // 3. Vegetables & Greens
    if (name.contains('broccoli')) return '🥦';
    if (name.contains('spinach') ||
        name.contains('leaf') ||
        name.contains('basil') ||
        name.contains('parsley') ||
        name.contains('cilantro') ||
        name.contains('coriander')) return '🍃';
    if (name.contains('lettuce') ||
        name.contains('cabbage') ||
        name.contains('kale')) return '🥬';
    if (name.contains('carrot')) return '🥕';
    if (name.contains('potato') && !name.contains('sweet')) return '🥔';
    if (name.contains('tomato')) return '🍅';
    if (name.contains('cucumber') || name.contains('zucchini')) return '🥒';
    if (name.contains('eggplant') || name.contains('aubergine')) return '🍆';
    if (name.contains('corn')) return '🌽';
    if (name.contains('bell pepper') || name.contains('capsicum')) return '🫑';
    if (name.contains('chili') ||
        name.contains('chilli') ||
        name.contains('hot pepper') ||
        name.contains('jalapeno') ||
        name.contains('paprika')) return '🌶️';
    if (name.contains('onion') ||
        name.contains('shallot') ||
        name.contains('scallion')) return '🧅';
    if (name.contains('garlic')) return '🧄';
    if (name.contains('mushroom')) return '🍄';
    if (name.contains('avocado')) return '🥑';
    if (name.contains('bean') && !name.contains('vanilla')) return '🫘';
    if (name.contains('pea') || name.contains('edamame')) return '🫛';
    if (name.contains('sweet potato') || name.contains('yam')) return '🍠';
    if (name.contains('ginger')) return '🫚';

    // 4. Fruits
    if (name.contains('apple')) return '🍎';
    if (name.contains('pear')) return '🍐';
    if (name.contains('banana')) return '🍌';
    if (name.contains('watermelon')) return '🍉';
    if (name.contains('grape') && !name.contains('oil')) return '🍇';
    if (name.contains('strawberry') || name.contains('strawberries'))
      return '🍓';
    if (name.contains('blueberry') || name.contains('berries')) return '🫐';
    if (name.contains('cherry') || name.contains('cherries')) return '🍒';
    if (name.contains('peach') || name.contains('nectarine')) return '🍑';
    if (name.contains('mango')) return '🥭';
    if (name.contains('pineapple')) return '🍍';
    if (name.contains('coconut') &&
        !name.contains('milk') &&
        !name.contains('oil')) return '🥥';
    if (name.contains('kiwi')) return '🥝';

    // Proteins
    if (name.contains('chicken') ||
        name.contains('breast') ||
        name.contains('thigh') ||
        name.contains('poultry')) return '🍗';
    if (name.contains('beef') ||
        name.contains('steak') ||
        name.contains('lamb')) return '🥩';
    if (name.contains('pork') ||
        name.contains('bacon') ||
        name.contains('ham') ||
        name.contains('sausage')) return '🥓';
    if (name.contains('meat') && !name.contains('coconut')) return '🍖';
    if (name.contains('fish') ||
        name.contains('salmon') ||
        name.contains('tuna') ||
        name.contains('cod') ||
        name.contains('tilapia')) return '🐟';
    if (name.contains('shrimp') || name.contains('prawn')) return '🦐';
    if (name.contains('crab') || name.contains('lobster')) return '🦀';
    if (name.contains('oyster') ||
        name.contains('clam') ||
        name.contains('mussel')) return '🦪';
    if (name.contains('egg') && !name.contains('plant')) return '🥚';
    if (name.contains('tofu') || name.contains('tempeh')) return '🧊';

    // Dairy & Alternatives
    if (name.contains('milk') || name.contains('cream')) return '🥛';
    if (name.contains('cheese') ||
        name.contains('cheddar') ||
        name.contains('mozzarella') ||
        name.contains('parmesan')) return '🧀';
    if (name.contains('butter') ||
        name.contains('margarine') ||
        name.contains('ghee')) return '🧈';
    if (name.contains('yogurt') || name.contains('yoghurt')) return '🥣';
    if (name.contains('ice cream') || name.contains('gelato')) return '🍨';

    // Pantry / Grains
    if (name.contains('bread') ||
        name.contains('toast') ||
        name.contains('bun')) return '🍞';
    if (name.contains('croissant')) return '🥐';
    if (name.contains('baguette')) return '🥖';
    if (name.contains('bagel')) return '🥯';
    if (name.contains('pancake')) return '🥞';
    if (name.contains('waffle')) return '🧇';
    if (name.contains('rice') && !name.contains('vinegar')) return '🍚';
    if (name.contains('noodle') ||
        name.contains('pasta') ||
        name.contains('spaghetti') ||
        name.contains('linguine') ||
        name.contains('penne')) return '🍝';
    if (name.contains('cereal') ||
        name.contains('oat') ||
        name.contains('granola')) return '🥣';
    if (name.contains('flour') ||
        name.contains('powder') ||
        name.contains('starch')) return '🥡';

    // Spices & Condiments
    if (name.contains('salt')) return '🧂';
    if (name.contains('black pepper') || name.contains('peppercorn'))
      return '⚫';
    if (name.contains('pepper') &&
        !name.contains('bell') &&
        !name.contains('chili')) return '⚫';
    if (name.contains('honey') || name.contains('syrup')) return '🍯';
    if (name.contains('sugar')) return '🍬';
    if (name.contains('chocolate') || name.contains('cocoa')) return '🍫';
    if (name.contains('cookie') || name.contains('biscuit')) return '🍪';
    if (name.contains('nut') ||
        name.contains('peanut') ||
        name.contains('almond') ||
        name.contains('cashew') ||
        name.contains('walnut')) return '🥜';
    if (name.contains('ketchup') ||
        name.contains('mayo') ||
        name.contains('mustard')) return '🧴';
    if (name.contains('jam') || name.contains('jelly')) return '🫙';

    // Drinks
    if (name.contains('water')) return '💧';
    if (name.contains('ice')) return '🧊';
    if (name.contains('coffee') || name.contains('espresso')) return '☕';
    if (name.contains('tea') || name.contains('matcha')) return '🫖';
    if (name.contains('beer') || name.contains('ale')) return '🍺';
    if (name.contains('wine')) return '🍷';
    if (name.contains('cocktail') ||
        name.contains('liquor') ||
        name.contains('vodka') ||
        name.contains('whiskey')) return '🍸';

    return null; // Return null to trigger fallback icon
  }
}
