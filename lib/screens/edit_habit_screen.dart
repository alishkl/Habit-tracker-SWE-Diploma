import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '../models/habit.dart';

class EditHabitScreen extends StatefulWidget {
  final Habit habit;

  const EditHabitScreen({super.key, required this.habit});

  @override
  _EditHabitScreenState createState() => _EditHabitScreenState();
}

class _EditHabitScreenState extends State<EditHabitScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _goal;
  late String _type;
  late int _total;
  late Color _color;
  late String _icon;
  late List<String> _days;
  late String _category;
  late String _priority;
  late DateTime? _endDate;
  late String? _note;
  late List<String> _reminders;
  late String _taskType;
  late List<String> _subTasks;
  final _subTaskController = TextEditingController();

  final List<String> _taskTypes = ['Регулярная', 'Одноразовая'];
  final List<String> _types = ['Количество', 'Время', 'Да/Нет'];
  final List<Color> _colors = [
    Colors.blueAccent,
    Colors.purpleAccent,
    Colors.greenAccent,
    Colors.orangeAccent,
  ];
  final List<Map<String, dynamic>> _icons = [
    {'name': 'water_drop', 'icon': Icons.water_drop},
    {'name': 'book', 'icon': Icons.book},
    {'name': 'fitness_center', 'icon': Icons.fitness_center},
    {'name': 'star', 'icon': Icons.star},
  ];
  final List<String> _categories = ['Здоровье', 'Учёба', 'Работа'];
  final List<String> _priorities = ['Высокий', 'Средний', 'Низкий'];

  @override
  void initState() {
    super.initState();
    _name = widget.habit.name;
    _goal = widget.habit.goal;
    _type = widget.habit.type;
    _total = widget.habit.total;
    _color = Color(int.parse(widget.habit.color));
    _icon = widget.habit.icon;
    _days = List.from(widget.habit.days);
    _category = widget.habit.category;
    _priority = widget.habit.priority;
    _endDate = widget.habit.endDate != null ? DateFormat('yyyy-MM-dd').parse(widget.habit.endDate!) : null;
    _note = widget.habit.note;
    _reminders = List.from(widget.habit.reminders);
    _taskType = widget.habit.taskType;
    _subTasks = List.from(widget.habit.subTasks);
    _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      status = await Permission.notification.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Разрешение на уведомления не предоставлено')),
        );
      }
    }
  }

  void _scheduleNotification(String habitName, String time) async {
    final timeParts = time.split(':');
    final now = DateTime.now();
    final location = tz.getLocation('Europe/Moscow');

    if (_taskType == 'Одноразовая') {
      if (_endDate == null) return;
      final scheduledDateTime = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      const minMillis = -8640000000000000;
      const maxMillis = 8640000000000000;
      final millis = scheduledDateTime.millisecondsSinceEpoch;
      if (millis < minMillis || millis > maxMillis) {
        print('Ошибка: scheduledDateTime $scheduledDateTime вне допустимого диапазона.');
        return;
      }

      final tzScheduledTime = tz.TZDateTime.from(scheduledDateTime, location);

      await flutterLocalNotificationsPlugin.zonedSchedule(
        habitName.hashCode,
        'Напоминание: $habitName',
        'Пора выполнить задачу!',
        tzScheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'habit_channel',
            'Habit Reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } else {
      for (var i = 0; i < 30; i++) {
        final scheduledDateTime = now.add(Duration(days: i));
        if (!_days.contains(_getDayOfWeek(scheduledDateTime))) continue;

        final scheduledTime = DateTime(
          scheduledDateTime.year,
          scheduledDateTime.month,
          scheduledDateTime.day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );

        const minMillis = -8640000000000000;
        const maxMillis = 8640000000000000;
        final millis = scheduledTime.millisecondsSinceEpoch;
        if (millis < minMillis || millis > maxMillis) {
          print('Ошибка: scheduledTime $scheduledTime вне допустимого диапазона.');
          continue;
        }

        final tzScheduledTime = tz.TZDateTime.from(scheduledTime, location);

        await flutterLocalNotificationsPlugin.zonedSchedule(
          (habitName.hashCode + i).hashCode,
          'Напоминание: $habitName',
          'Пора выполнить привычку!',
          tzScheduledTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'habit_channel',
              'Habit Reminders',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  String _getDayOfWeek(DateTime date) {
    switch (date.weekday) {
      case 1:
        return 'Пн';
      case 2:
        return 'Вт';
      case 3:
        return 'Ср';
      case 4:
        return 'Чт';
      case 5:
        return 'Пт';
      case 6:
        return 'Сб';
      case 7:
        return 'Вс';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _subTaskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать привычку'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.indigo, Color.fromARGB(255, 143, 147, 173)],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo.withOpacity(0.1), Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  initialValue: _name,
                  decoration: const InputDecoration(
                    labelText: 'Название привычки',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value!.isEmpty ? 'Введите название' : null,
                  onSaved: (value) => _name = value!,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  initialValue: _goal,
                  decoration: const InputDecoration(
                    labelText: 'Цель (например, 8 стаканов или 30 минут)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value!.isEmpty ? 'Введите цель' : null,
                  onSaved: (value) => _goal = value!,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _taskType,
                  decoration: const InputDecoration(
                    labelText: 'Тип задачи',
                    border: OutlineInputBorder(),
                  ),
                  items: _taskTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) => setState(() => _taskType = value!),
                ),
                const SizedBox(height: 20),
                if (_type != 'Да/Нет') ...[
                  const SizedBox(height: 20),
                  TextFormField(
                    initialValue: _total.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Количество (например, 8 или 30)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => int.tryParse(value!) == null ? 'Введите число' : null,
                    onSaved: (value) => _total = int.parse(value!),
                  ),
                ],
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(
                    labelText: 'Тип цели',
                    border: OutlineInputBorder(),
                  ),
                  items: _types.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) => setState(() => _type = value!),
                ),
                const SizedBox(height: 20),
                if (_taskType == 'Регулярная') ...[
                  const Text('Дни выполнения:', style: TextStyle(fontSize: 16)),
                  Wrap(
                    spacing: 10,
                    children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'].map((day) {
                      return FilterChip(
                        label: Text(day),
                        selected: _days.contains(day),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _days.add(day);
                            } else {
                              _days.remove(day);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                ListTile(
                  title: Text(
                    _endDate == null
                        ? 'Срок выполнения: Не задан'
                        : 'Срок: ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _endDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 20),
                const Text('Подзадачи:', style: TextStyle(fontSize: 16)),
                ..._subTasks.map((subTask) => ListTile(
                      title: Text(subTask),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => setState(() => _subTasks.remove(subTask)),
                      ),
                    )),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _subTaskController,
                        decoration: const InputDecoration(
                          labelText: 'Новая подзадача',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (_subTaskController.text.isNotEmpty) {
                          setState(() {
                            _subTasks.add(_subTaskController.text);
                            _subTaskController.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Напоминания:', style: TextStyle(fontSize: 16)),
                ..._reminders.map((time) => ListTile(
                      title: Text(time),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => setState(() => _reminders.remove(time)),
                      ),
                    )),
                TextButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (picked != null) {
                      final time = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      setState(() => _reminders.add(time));
                    }
                  },
                  child: const Text('Добавить напоминание'),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  initialValue: _note,
                  decoration: const InputDecoration(
                    labelText: 'Примечание (опционально)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onSaved: (value) => _note = value,
                ),
                const SizedBox(height: 20),
                const Text('Выберите цвет:', style: TextStyle(fontSize: 16)),
                Wrap(
                  spacing: 10,
                  children: _colors.map((color) {
                    return GestureDetector(
                      onTap: () => setState(() => _color = color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: _color == color
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Text('Выберите иконку:', style: TextStyle(fontSize: 16)),
                Wrap(
                  spacing: 10,
                  children: _icons.map((icon) {
                    return GestureDetector(
                      onTap: () => setState(() => _icon = icon['name']),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _icon == icon['name'] ? Colors.grey.shade200 : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon['icon'], color: _color),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 30),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.indigo, Color.fromARGB(255, 143, 147, 173)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        widget.habit.name = _name;
                        widget.habit.goal = _goal;
                        widget.habit.type = _type;
                        widget.habit.total = _type == 'Да/Нет' ? 1 : _total;
                        widget.habit.color = _color.value.toString();
                        widget.habit.icon = _icon;
                        widget.habit.days = _taskType == 'Регулярная' ? _days : [];
                        widget.habit.category = _category;
                        widget.habit.priority = _priority;
                        widget.habit.endDate = _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null;
                        widget.habit.note = _note;
                        widget.habit.reminders = _reminders;
                        widget.habit.taskType = _taskType;
                        widget.habit.subTasks = _subTasks;
                        widget.habit.save();
                        for (var time in _reminders) {
                          _scheduleNotification(_name, time);
                        }
                        Navigator.pop(context);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text(
                      'Сохранить',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}