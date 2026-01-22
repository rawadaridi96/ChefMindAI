// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_recipe_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavedRecipeModelAdapter extends TypeAdapter<SavedRecipeModel> {
  @override
  final int typeId = 2;

  @override
  SavedRecipeModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavedRecipeModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      recipeId: fields[2] as String,
      title: fields[3] as String,
      recipeJson: (fields[4] as Map).cast<String, dynamic>(),
      householdId: fields[5] as String?,
      createdAt: fields[6] as DateTime,
      isShared: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SavedRecipeModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.recipeId)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.recipeJson)
      ..writeByte(5)
      ..write(obj.householdId)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.isShared);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedRecipeModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
