// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitAdapter extends TypeAdapter<Habit> {
  @override
  final int typeId = 0;

  @override
  Habit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Habit(
      name: fields[0] as String,
      goal: fields[1] as String,
      type: fields[2] as String,
      progress: fields[3] as int,
      total: fields[4] as int,
      color: fields[5] as String,
      icon: fields[6] as String,
      days: (fields[7] as List).cast<String>(),
      history: (fields[8] as Map).cast<String, int>(),
      category: fields[9] as String,
      priority: fields[10] as String,
      endDate: fields[11] as String?,
      note: fields[12] as String?,
      reminders: (fields[13] as List).cast<String>(),
      taskType: fields[14] as String,
      subTasks: (fields[15] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.goal)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.progress)
      ..writeByte(4)
      ..write(obj.total)
      ..writeByte(5)
      ..write(obj.color)
      ..writeByte(6)
      ..write(obj.icon)
      ..writeByte(7)
      ..write(obj.days)
      ..writeByte(8)
      ..write(obj.history)
      ..writeByte(9)
      ..write(obj.category)
      ..writeByte(10)
      ..write(obj.priority)
      ..writeByte(11)
      ..write(obj.endDate)
      ..writeByte(12)
      ..write(obj.note)
      ..writeByte(13)
      ..write(obj.reminders)
      ..writeByte(14)
      ..write(obj.taskType)
      ..writeByte(15)
      ..write(obj.subTasks);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
