import 'package:hive/hive.dart';

part 'habit.g.dart';

@HiveType(typeId: 0)
class Habit extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String goal;

  @HiveField(2)
  String type;

  @HiveField(3)
  int progress;

  @HiveField(4)
  int total;

  @HiveField(5)
  String color;

  @HiveField(6)
  String icon;

  @HiveField(7)
  List<String> days;

  @HiveField(8)
  Map<String, int> history;

  @HiveField(9)
  String category;

  @HiveField(10)
  String priority;

  @HiveField(11)
  String? endDate;

  @HiveField(12)
  String? note;

  @HiveField(13)
  List<String> reminders;

  @HiveField(14)
  String taskType; // Новое поле: "Регулярная" или "Одноразовая"

  @HiveField(15)
  List<String> subTasks; // Новое поле: список подзадач

  Habit({
    required this.name,
    required this.goal,
    required this.type,
    required this.progress,
    required this.total,
    required this.color,
    required this.icon,
    required this.days,
    required this.history,
    required this.category,
    required this.priority,
    this.endDate,
    this.note,
    required this.reminders,
    required this.taskType,
    required this.subTasks,
  });
}