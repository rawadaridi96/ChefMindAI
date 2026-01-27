// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pantry_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PantryItemModelAdapter extends TypeAdapter<PantryItemModel> {
  @override
  final int typeId = 0;

  @override
  PantryItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PantryItemModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      name: fields[2] as String,
      category: fields[3] as String,
      createdAt: fields[4] as DateTime,
      householdId: fields[5] as String?,
      imageUrl: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PantryItemModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.householdId)
      ..writeByte(6)
      ..write(obj.imageUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PantryItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
