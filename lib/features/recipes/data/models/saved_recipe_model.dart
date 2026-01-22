import 'package:hive/hive.dart';

part 'saved_recipe_model.g.dart';

@HiveType(typeId: 2)
class SavedRecipeModel extends HiveObject {
  @HiveField(0)
  final String id; // This is the row ID (pk)

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String recipeId; // The functional ID of the recipe

  @HiveField(3)
  final String title;

  @HiveField(4)
  final Map<String, dynamic> recipeJson; // Storing the full JSON blob

  @HiveField(5)
  final String? householdId;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final bool isShared;

  SavedRecipeModel({
    required this.id,
    required this.userId,
    required this.recipeId,
    required this.title,
    required this.recipeJson,
    this.householdId,
    required this.createdAt,
    this.isShared = false,
  });

  factory SavedRecipeModel.fromJson(Map<String, dynamic> json) {
    // Use 'id' if available, otherwise fall back to recipe_id
    // Some tables might not return 'id' or use auto-increment without exposing it
    final rowId = json['id']?.toString() ?? json['recipe_id']?.toString() ?? '';

    return SavedRecipeModel(
      id: rowId,
      userId: json['user_id'] as String,
      recipeId: json['recipe_id'] as String,
      title: json['title'] as String,
      recipeJson: Map<String, dynamic>.from(json['recipe_json'] ?? {}),
      householdId: json['household_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isShared: json['is_shared'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id, // Ensure this matches type (int vs string in DB?)
      'user_id': userId,
      'recipe_id': recipeId,
      'title': title,
      'recipe_json': recipeJson,
      'household_id': householdId,
      'created_at': createdAt.toIso8601String(),
      'is_shared': isShared,
    };
  }
}
