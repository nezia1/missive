// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plain_text_message.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlainTextMessageAdapter extends TypeAdapter<PlainTextMessage> {
  @override
  final int typeId = 0;

  @override
  PlainTextMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlainTextMessage(
      id: fields[4] as String,
      content: fields[0] as String,
      own: fields[1] as bool,
      receiver: fields[2] as String?,
      sentAt: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PlainTextMessage obj) {
    writer
      ..writeByte(5)
      ..writeByte(4)
      ..write(obj.id)
      ..writeByte(0)
      ..write(obj.content)
      ..writeByte(1)
      ..write(obj.own)
      ..writeByte(2)
      ..write(obj.receiver)
      ..writeByte(3)
      ..write(obj.sentAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlainTextMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
