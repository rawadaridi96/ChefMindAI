// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shopping_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ShoppingItemModelAdapter extends TypeAdapter<ShoppingItemModel> {
  @override
  final int typeId = 1;

  @override
  ShoppingItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ShoppingItemModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      itemName: fields[2] as String,
      amount: fields[3] as String,
      isBought: fields[4] as bool,
      recipeSource: fields[5] as String?,
      householdId: fields[6] as String?,
      createdAt: fields[7] as DateTime,
      imageUrl: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ShoppingItemModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.itemName)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.isBought)
      ..writeByte(5)
      ..write(obj.recipeSource)
      ..writeByte(6)
      ..write(obj.householdId)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.imageUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoppingItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
