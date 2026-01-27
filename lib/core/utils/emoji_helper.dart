class EmojiHelper {
  static String getEmoji(String ingredientName) {
    final name = ingredientName.toLowerCase().trim();

    // Vegetables & Greens
    if (name.contains('broccoli')) return '🥦';
    if (name.contains('spinach') || name.contains('leaf')) return '🍃';
    if (name.contains('lettuce') || name.contains('cabbage')) return '🥬';
    if (name.contains('carrot')) return '🥕';
    if (name.contains('potato')) return '🥔';
    if (name.contains('tomato')) return '🍅';
    if (name.contains('cucumber')) return '🥒';
    if (name.contains('eggplant') || name.contains('aubergine')) return '🍆';
    if (name.contains('corn')) return '🌽';
    if (name.contains('pepper') &&
        (name.contains('bell') ||
            name.contains('red') ||
            name.contains('green'))) return '🫑';
    if (name.contains('chili') ||
        name.contains('chilli') ||
        name.contains('hot pepper')) return '🌶️';
    if (name.contains('onion')) return '🧅';
    if (name.contains('garlic')) return '🧄';
    if (name.contains('mushroom')) return '🍄';
    if (name.contains('avocado')) return '🥑';
    if (name.contains('bean')) return '🫘';
    if (name.contains('pea')) return '🫛';
    if (name.contains('sweet potato') || name.contains('yam')) return '🍠';

    // Fruits
    if (name.contains('apple')) return '🍎';
    if (name.contains('pear')) return '🍐';
    if (name.contains('orange') || name.contains('tangerine')) return '🍊';
    if (name.contains('lemon')) return '🍋';
    if (name.contains('banana')) return '🍌';
    if (name.contains('watermelon')) return '🍉';
    if (name.contains('grape')) return '🍇';
    if (name.contains('strawberry') || name.contains('strawberries'))
      return '🍓';
    if (name.contains('blueberry') || name.contains('berries')) return '🫐';
    if (name.contains('cherry') || name.contains('cherries')) return '🍒';
    if (name.contains('peach')) return '🍑';
    if (name.contains('mango')) return '🥭';
    if (name.contains('pineapple')) return '🍍';
    if (name.contains('coconut')) return '🥥';
    if (name.contains('kiwi')) return '🥝';

    // Proteins
    if (name.contains('chicken') ||
        name.contains('breast') ||
        name.contains('thigh')) return '🍗';
    if (name.contains('beef') || name.contains('steak')) return '🥩';
    if (name.contains('pork') || name.contains('bacon') || name.contains('ham'))
      return '🥓';
    if (name.contains('meat')) return '🍖';
    if (name.contains('fish') ||
        name.contains('salmon') ||
        name.contains('tuna')) return '🐟';
    if (name.contains('shrimp') || name.contains('prawn')) return '🦐';
    if (name.contains('crab') || name.contains('lobster')) return '🦀';
    if (name.contains('oyster') || name.contains('clam')) return '🦪';
    if (name.contains('egg')) return '🥚';
    if (name.contains('tofu')) return '🧊';

    // Dairy
    if (name.contains('milk') && !name.contains('coco')) return '🥛';
    if (name.contains('cheese') ||
        name.contains('cheddar') ||
        name.contains('mozzarella')) return '🧀';
    if (name.contains('butter')) return '🧈';
    if (name.contains('yogurt') || name.contains('yoghurt')) return '🥣';
    if (name.contains('ice cream')) return '🍨';

    // Pantry / Grains
    if (name.contains('bread') || name.contains('toast')) return '🍞';
    if (name.contains('croissant')) return '🥐';
    if (name.contains('baguette')) return '🥖';
    if (name.contains('bagel')) return '🥯';
    if (name.contains('pancake')) return '🥞';
    if (name.contains('waffle')) return '🧇';
    if (name.contains('rice')) return '🍚';
    if (name.contains('noodle') ||
        name.contains('pasta') ||
        name.contains('spaghetti')) return '🍝';
    if (name.contains('cereal') || name.contains('oat')) return '🥣';

    // Spices & Condiments
    if (name.contains('salt')) return '🧂';
    if (name.contains('honey')) return '🍯';
    if (name.contains('sugar')) return '🍬';
    if (name.contains('oil') || name.contains('olive')) return '🫒';
    if (name.contains('sauce') || name.contains('ketchup')) return '🥫';
    if (name.contains('mayo')) return '🧴';
    if (name.contains('chocolate')) return '🍫';
    if (name.contains('cookie')) return '🍪';
    if (name.contains('nut') ||
        name.contains('peanut') ||
        name.contains('almond')) return '🥜';

    // Drinks
    if (name.contains('water')) return '💧';
    if (name.contains('coffee') || name.contains('espresso')) return '☕';
    if (name.contains('tea')) return '🫖';
    if (name.contains('juice')) return '🧃';
    if (name.contains('beer')) return '🍺';
    if (name.contains('wine')) return '🍷';
    if (name.contains('cocktail')) return '🍸';

    return '📦'; // Default "Box" or "Package"
  }
}
