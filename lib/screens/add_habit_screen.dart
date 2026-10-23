import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import '../models/habit.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key});

  @override
  _AddHabitScreenState createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _goal = '';
  String _type = 'Количество';
  int _total = 1;
  Color _color = Colors.blueAccent;
  String _icon = 'star';
  List<String> _days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  String _category = 'Здоровье';
  String _priority = 'Средний';
  DateTime? _endDate;
  String? _note;
  List<String> _reminders = [];
  String _taskType = 'Регулярная'; // Добавляем выбор типа задачи
  List<String> _subTasks = []; // Список подзадач
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
  final List<Map<String, String>> _templates = [
    {'name': 'Пить воду', 'goal': '8 стаканов', 'type': 'Количество', 'total': '8'},
    {'name': 'Читать', 'goal': '30 минут', 'type': 'Время', 'total': '30'},
    {'name': 'Бегать', 'goal': '30 минут', 'type': 'Время', 'total': '30'},
  ];

  @override
  void initState() {
    super.initState();
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
      if (_endDate == null) return; // Для одноразовой задачи нужна дата
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
      // Для регулярной задачи планируем уведомления на каждый выбранный день
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
        title: const Text('Добавить привычку'),
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
                const Text('Шаблоны:', style: TextStyle(fontSize: 16)),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _templates.length,
                    itemBuilder: (context, index) {
                      final template = _templates[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Chip(
                          label: Text(template['name']!),
                          onDeleted: () {
                            setState(() {
                              _name = template['name']!;
                              _goal = template['goal']!;
                              _type = template['type']!;
                              _total = int.parse(template['total']!);
                            });
                          },
                          deleteIcon: const Icon(Icons.add, size: 18),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Название привычки',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value!.isEmpty ? 'Введите название' : null,
                  onSaved: (value) => _name = value!,
                  onChanged: (value) {
                    setState(() {
                      _name = value;
                    });
                    if (value.toLowerCase().contains('вода')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Попробуйте "Пить 8 стаканов воды в день?"')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Цель (например, 8 стаканов)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value!.isEmpty ? 'Введите цель' : null,
                  onSaved: (value) => _goal = value!,
                  onChanged: (value) => setState(() => _goal = value),
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
                if (_type != 'Да/Нет')
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Количество (например, 8)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => int.tryParse(value!) == null ? 'Введите число' : null,
                    onSaved: (value) => _total = int.parse(value!),
                  ),
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
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'Категория',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(value: category, child: Text(category));
                  }).toList(),
                  onChanged: (value) => setState(() => _category = value!),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Приоритет',
                    border: OutlineInputBorder(),
                  ),
                  items: _priorities.map((priority) {
                    return DropdownMenuItem(value: priority, child: Text(priority));
                  }).toList(),
                  onChanged: (value) => setState(() => _priority = value!),
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
                        : 'Срок выполнения: ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
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
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
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
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
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
                const SizedBox(height: 20),
                const Text('Превью:', style: TextStyle(fontSize: 16)),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _color,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Icon(_icons.firstWhere((i) => i['name'] == _icon)['icon'], color: _color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _name.isEmpty ? 'Новая привычка' : _name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.indigo),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Цель: ${_goal.isEmpty ? 'Не указано' : _goal}',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                        final habit = Habit(
                          name: _name,
                          goal: _goal,
                          type: _type,
                          progress: 0,
                          total: _type == 'Да/Нет' ? 1 : _total,
                          color: _color.value.toString(),
                          icon: _icon,
                          days: _taskType == 'Регулярная' ? _days : [],
                          history: {},
                          category: _category,
                          priority: _priority,
                          endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
                          note: _note,
                          reminders: _reminders,
                          taskType: _taskType,
                          subTasks: _subTasks,
                        );
                        Hive.box<Habit>('habits').add(habit);
                        for (var time in _reminders) {
                          _scheduleNotification(_name, time);
                        }
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
                        color: Color.fromARGB(255, 233, 233, 233),
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