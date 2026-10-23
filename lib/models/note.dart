import 'package:hive/hive.dart';

part 'note.g.dart';

@HiveType(typeId: 1)
class Note extends HiveObject {
  @HiveField(0)
  String date;

  @HiveField(1)
  String text;

  Note({
    required this.date,
    required this.text,
  });
}