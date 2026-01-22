import 'package:hive/hive.dart';

part 'pantry_item_model.g.dart';

@HiveType(typeId: 0)
class PantryItemModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String category;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final String? householdId;

  PantryItemModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.createdAt,
    this.householdId,
  });

  factory PantryItemModel.fromJson(Map<String, dynamic> json) {
    return PantryItemModel(
      id: json['id'].toString(), // Handle if int
      userId: json['user_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'Uncategorized',
      createdAt: DateTime.parse(json['created_at'] as String),
      householdId: json['household_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'household_id': householdId,
    };
  }
}
