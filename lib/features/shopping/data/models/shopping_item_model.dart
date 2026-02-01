import 'package:hive/hive.dart';

part 'shopping_item_model.g.dart';

@HiveType(typeId: 1)
class ShoppingItemModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String itemName;

  @HiveField(3)
  final String amount;

  @HiveField(4)
  final bool isBought;

  @HiveField(5)
  final String? recipeSource;

  @HiveField(6)
  final String? householdId;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final String? imageUrl;

  @HiveField(9, defaultValue: 'Uncategorized')
  final String category;

  ShoppingItemModel({
    required this.id,
    required this.userId,
    required this.itemName,
    required this.amount,
    required this.isBought,
    this.recipeSource,
    this.householdId,
    required this.createdAt,
    this.imageUrl,
    this.category = 'Uncategorized',
  });

  factory ShoppingItemModel.fromJson(Map<String, dynamic> json) {
    return ShoppingItemModel(
      id: json['id'].toString(),
      userId: json['user_id'] as String,
      itemName: json['item_name'] as String,
      amount: json['amount']?.toString() ?? '1',
      isBought: json['is_bought'] as bool? ?? false,
      recipeSource: json['recipe_source'] as String?,
      householdId: json['household_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String? ?? 'Uncategorized',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'item_name': itemName,
      'amount': amount,
      'is_bought': isBought,
      'recipe_source': recipeSource,
      'household_id': householdId,
      'created_at': createdAt.toIso8601String(),
      'image_url': imageUrl,
      'category': category,
    };
  }
}
