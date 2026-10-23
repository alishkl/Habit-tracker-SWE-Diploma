import 'package:hive/hive.dart';

part 'reward.g.dart';

@HiveType(typeId: 4)
class Reward extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String icon; // Например, "🏆"

  @HiveField(2)
  String dateEarned; // Формат: yyyy-MM-dd

  Reward({
    required this.title,
    required this.icon,
    required this.dateEarned,
  });
}