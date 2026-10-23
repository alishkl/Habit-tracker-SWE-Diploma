import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/challenge.dart';
import '../models/habit.dart';

// Модель для готового челленджа
class PresetChallenge {
  final String title;
  final String description;
  final int duration;
  final String icon;

  PresetChallenge({
    required this.title,
    required this.description,
    required this.duration,
    required this.icon,
  });
}

class AddChallengeScreen extends StatefulWidget {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  const AddChallengeScreen({super.key, required this.flutterLocalNotificationsPlugin});

  @override
  _AddChallengeScreenState createState() => _AddChallengeScreenState();
}

class _AddChallengeScreenState extends State<AddChallengeScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _duration = 7;
  String? _selectedHabitKey;
  TimeOfDay? _reminderTime;
  String _selectedIcon = 'star'; // Иконка по умолчанию

  // Список доступных иконок
  final Map<String, IconData> _icons = {
    'star': Icons.star,
    'water_drop': Icons.water_drop,
    'book': Icons.book,
    'fitness_center': Icons.fitness_center,
    'meditation': Icons.self_improvement,
    'phone_off': Icons.phone_disabled,
  };

  // Список готовых челленджей с иконками
  final List<PresetChallenge> _presetChallenges = [
    PresetChallenge(
      title: '30 дней без сахара',
      description: 'Откажитесь от сахара на 30 дней для улучшения здоровья.',
      duration: 30,
      icon: 'water_drop',
    ),
    PresetChallenge(
      title: 'Утренние пробежки 21 день',
      description: 'Бегайте каждое утро в течение 21 дня.',
      duration: 21,
      icon: 'fitness_center',
    ),
    PresetChallenge(
      title: 'Чтение 15 минут в день',
      description: 'Читайте книги по 15 минут ежедневно в течение 14 дней.',
      duration: 14,
      icon: 'book',
    ),
    PresetChallenge(
      title: 'Медитация 10 дней',
      description: 'Практикуйте медитацию каждое утро в течение 10 дней.',
      duration: 10,
      icon: 'meditation',
    ),
    PresetChallenge(
      title: 'Выпивать 2 литра воды',
      description: 'Пейте 2 литра воды ежедневно в течение 30 дней.',
      duration: 30,
      icon: 'water_drop',
    ),
    PresetChallenge(
      title: 'Без телефона перед сном',
      description: 'Не используйте телефон за час до сна в течение 7 дней.',
      duration: 7,
      icon: 'phone_off',
    ),
  ];

  String _formatDate(DateTime date) {
    final formatted = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    print('Форматированная дата: $formatted');
    return formatted;
  }

  Future<void> _scheduleReminder(Challenge challenge) async {
    if (challenge.reminderTime == null) {
      print('Нет напоминания для челленджа: ${challenge.title}');
      return;
    }

    try {
      final timeParts = challenge.reminderTime!.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final startDate = DateFormat('yyyy-MM-dd').parse(challenge.startDate);
      final notificationId = challenge.key.hashCode;

      print('Планирование напоминаний для челленджа: ${challenge.title}, ID: $notificationId');

      for (int i = 0; i < challenge.duration; i++) {
        final scheduledDate = startDate.add(Duration(days: i));
        if (scheduledDate.isBefore(DateTime.now())) {
          print('Дата $scheduledDate уже прошла, пропускаем');
          continue;
        }

        final scheduledTime = tz.TZDateTime(
          tz.local,
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          hour,
          minute,
        );

        print('Планируем уведомление на $scheduledTime (ID: ${notificationId + i})');

        await widget.flutterLocalNotificationsPlugin.zonedSchedule(
          notificationId + i,
          'Напоминание: ${challenge.title}',
          'Пора выполнить челлендж на день ${i + 1}!',
          scheduledTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'challenge_channel',
              'Челленджи',
              channelDescription: 'Напоминания о челленджах',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidAllowWhileIdle: true,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
      print('Напоминания успешно запланированы для ${challenge.title}');
    } catch (e) {
      print('Ошибка при планировании напоминаний: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при настройке напоминаний: $e')),
      );
    }
  }

  void _createChallenge() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty || _duration <= 0) {
      print('Ошибка валидации: title=$title, duration=$_duration');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, заполните все поля корректно')),
      );
      return;
    }

    final now = DateTime.now();
    final challenge = Challenge(
      title: title,
      description: description.isEmpty ? 'Без описания' : description,
      duration: _duration,
      startDate: _formatDate(now),
      progress: List.filled(_duration, false),
      isCompleted: false,
      habitKey: _selectedHabitKey,
      reminderTime: _reminderTime != null
          ? '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
          : null,
      icon: _selectedIcon,
    );

    print('Создаём челлендж: ${challenge.title}, duration=${challenge.duration}');

    final box = Hive.box<Challenge>('challenges');
    box.add(challenge).then((key) {
      print('Челлендж сохранён с ключом: $key');
      if (_reminderTime != null) {
        _scheduleReminder(challenge);
      } else {
        print('Напоминание не установлено');
      }
      Navigator.pop(context);
    }).catchError((e) {
      print('Ошибка при сохранении челленджа: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при сохранении челленджа: $e')),
      );
    });
  }

  // Метод для заполнения полей на основе выбранного готового челленджа
  void _selectPresetChallenge(PresetChallenge preset) {
    setState(() {
      _titleController.text = preset.title;
      _descriptionController.text = preset.description;
      _duration = preset.duration;
      _selectedIcon = preset.icon;
    });
    print('Выбран готовый челлендж: ${preset.title}');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Добавить челлендж',
          style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.indigo, Color.fromARGB(255, 143, 147, 173)],
            ),
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Раздел с готовыми челленджами
            const Text(
              'Выберите готовый челлендж',
              style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _presetChallenges.length,
                itemBuilder: (context, index) {
                  final preset = _presetChallenges[index];
                  return GestureDetector(
                    onTap: () => _selectPresetChallenge(preset),
                    child: Container(
                      width: 150,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_icons[preset.icon], color: Colors.indigo, size: 30),
                          const SizedBox(height: 5),
                          Text(
                            preset.title,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.indigo,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${preset.duration} дней',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Название',
              style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Например, "30 дней без сахара"',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Описание',
              style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: 'Краткое описание челленджа',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            const Text(
              'Иконка',
              style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _icons.entries.map((entry) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIcon = entry.key;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedIcon == entry.key ? Colors.indigo.withOpacity(0.2) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedIcon == entry.key ? Colors.indigo : Colors.grey.shade300,
                      ),
                    ),
                    child: Icon(
                      entry.value,
                      color: _selectedIcon == entry.key ? Colors.indigo : Colors.grey,
                      size: 30,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Длительность (дни)',
              style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _duration.toDouble(),
                    min: 1,
                    max: 90,
                    divisions: 89,
                    label: _duration.toString(),
                    onChanged: (value) {
                      setState(() {
                        _duration = value.toInt();
                      });
                    },
                    activeColor: Colors.indigo,
                    inactiveColor: Colors.grey.shade300,
                  ),
                ),
                Text(
                  '$_duration дней',
                  style: const TextStyle(fontFamily: 'Montserrat'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Связать с привычкой (опционально)',
              style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder(
              valueListenable: Hive.box<Habit>('habits').listenable(),
              builder: (context, Box<Habit> habitsBox, _) {
                final habits = habitsBox.values.toList();
                return DropdownButton<String>(
                  value: _selectedHabitKey,
                  hint: const Text('Выберите привычку', style: TextStyle(fontFamily: 'Montserrat')),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Без связи', style: TextStyle(fontFamily: 'Montserrat')),
                    ),
                    ...habits.map((habit) {
                      return DropdownMenuItem<String>(
                        value: habit.key.toString(),
                        child: Text(habit.name, style: const TextStyle(fontFamily: 'Montserrat')),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedHabitKey = value;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Напоминание (опционально)',
              style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _reminderTime == null
                        ? 'Не установлено'
                        : 'Напоминать в ${_reminderTime!.format(context)}',
                    style: const TextStyle(fontFamily: 'Montserrat'),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final selectedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (selectedTime != null) {
                      setState(() {
                        _reminderTime = selectedTime;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Выбрать время',
                    style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: _createChallenge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text(
                  'Создать челлендж',
                  style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}