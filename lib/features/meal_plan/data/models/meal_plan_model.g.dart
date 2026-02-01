// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_plan_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MealPlanModelAdapter extends TypeAdapter<MealPlanModel> {
  @override
  final int typeId = 4;

  @override
  MealPlanModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealPlanModel(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      mealType: fields[2] as String,
      recipeId: fields[3] as String?,
      customDescription: fields[4] as String?,
      recipeTitle: fields[5] as String?,
      userId: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MealPlanModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.mealType)
      ..writeByte(3)
      ..write(obj.recipeId)
      ..writeByte(4)
      ..write(obj.customDescription)
      ..writeByte(5)
      ..write(obj.recipeTitle)
      ..writeByte(6)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealPlanModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MealPlanModel _$MealPlanModelFromJson(Map<String, dynamic> json) =>
    MealPlanModel(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      mealType: json['meal_type'] as String,
      recipeId: json['recipe_id'] as String?,
      customDescription: json['custom_description'] as String?,
      recipeTitle: json['recipe_title'] as String?,
      userId: json['user_id'] as String?,
    );

Map<String, dynamic> _$MealPlanModelToJson(MealPlanModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'date': instance.date.toIso8601String(),
      'meal_type': instance.mealType,
      'recipe_id': instance.recipeId,
      'custom_description': instance.customDescription,
      'recipe_title': instance.recipeTitle,
      'user_id': instance.userId,
    };
