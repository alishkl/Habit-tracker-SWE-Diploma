import 'package:hive/hive.dart';

part 'challenge.g.dart';

@HiveType(typeId: 3)
class Challenge extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String description;

  @HiveField(2)
  int duration;

  @HiveField(3)
  String startDate;

  @HiveField(4)
  List<bool> progress;

  @HiveField(5)
  bool isCompleted;

  @HiveField(6)
  String? habitKey;

  @HiveField(7)
  String? reminderTime;

  @HiveField(8)
  String icon; // Новое поле для иконки

  Challenge({
    required this.title,
    required this.description,
    required this.duration,
    required this.startDate,
    required this.progress,
    required this.isCompleted,
    this.habitKey,
    this.reminderTime,
    this.icon = 'star', // Значение по умолчанию
  });
}