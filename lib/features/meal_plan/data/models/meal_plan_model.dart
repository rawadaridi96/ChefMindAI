import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'meal_plan_model.g.dart';

@HiveType(typeId: 4) // Ensure this ID is unique. Checking others...
// UserPrefs=0, SavedRecipe=1, PantryItem=2, ShoppingItem=3. So 4 is safe.
@JsonSerializable(explicitToJson: true)
class MealPlanModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  @JsonKey(name: 'meal_type')
  final String mealType; // "Breakfast", "Lunch", "Dinner", "Snack"

  @HiveField(3)
  @JsonKey(name: 'recipe_id')
  final String? recipeId; // If linked to a recipe

  @HiveField(4)
  @JsonKey(name: 'custom_description')
  final String? customDescription; // For manual entries "e.g. Leftovers"

  @HiveField(5)
  @JsonKey(name: 'recipe_title')
  final String? recipeTitle; // Cached title for display

  @HiveField(6)
  @JsonKey(name: 'user_id')
  final String? userId;

  MealPlanModel({
    required this.id,
    required this.date,
    required this.mealType,
    this.recipeId,
    this.customDescription,
    this.recipeTitle,
    this.userId,
  });

  factory MealPlanModel.fromJson(Map<String, dynamic> json) =>
      _$MealPlanModelFromJson(json);

  Map<String, dynamic> toJson() => _$MealPlanModelToJson(this);
}
