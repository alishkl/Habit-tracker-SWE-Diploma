import 'package:hive/hive.dart';

part 'mood.g.dart';

@HiveType(typeId: 2)
class Mood extends HiveObject {
  @HiveField(0)
  String date;

  @HiveField(1)
  String emoji; // Например, "😊", "😐", "😢"

  Mood({
    required this.date,
    required this.emoji,
  });
}