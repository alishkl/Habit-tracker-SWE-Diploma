import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'add_habit_screen.dart';
import 'habit_detail_screen.dart';
import 'edit_habit_screen.dart';
import '../models/habit.dart';
import '../models/note.dart';
import '../models/mood.dart';
import '../localizations/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  String _selectedCategory = 'Все';
  String _selectedFilter = 'Все';
  final List<String> _categories = ['Все', 'Здоровье', 'Учёба', 'Работа'];
  final List<String> _filters = ['Все', 'Выполненные', 'Невыполненные'];
  final List<String> _quotes = [
    'smallSteps',
    'keepGoing',
    'everyAction',
  ];
  final List<String> _moods = ['😊', '😐', '😢', '😄', '😠'];

  String _formatDate(DateTime date) {
    try {
      const minMillis = -8640000000000000;
      const maxMillis = 8640000000000000;
      final millis = date.millisecondsSinceEpoch;
      if (millis < minMillis || millis > maxMillis) {
        print('Ошибка: Дата $date вне допустимого диапазона. Возвращаем текущую дату.');
        return '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      }
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      print('Ошибка в _formatDate: $e');
      return '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
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

  double getDailyProgress(List<Habit> habits, String dateKey) {
    if (habits.isEmpty) return 0;
    double totalProgress = habits.fold(0, (sum, habit) {
      int progress = habit.history[dateKey] ?? habit.progress;
      return sum + (progress / habit.total);
    });
    return (totalProgress / habits.length) * 100;
  }

  int getStreak(List<Habit> habits) {
    if (habits.isEmpty) return 0;

    int streak = 0;
    DateTime currentDate = DateTime.now();
    const int maxDaysToCheck = 1000;

    for (int i = 0; i < maxDaysToCheck; i++) {
      const minMillis = -8640000000000000;
      const maxMillis = 8640000000000000;
      final millis = currentDate.millisecondsSinceEpoch;
      if (millis < minMillis || millis > maxMillis) {
        print('Дата $currentDate вне допустимого диапазона. Прерываем getStreak.');
        break;
      }

      String dateKey = _formatDate(currentDate);
      double progress = getDailyProgress(habits, dateKey);
      if (progress >= 100) {
        streak++;
        currentDate = currentDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  Future<void> _updateHabitProgress(Habit habit, String dateKey, int newProgress) async {
    try {
      print('Обновление прогресса для ${habit.name}: dateKey=$dateKey, newProgress=$newProgress');
      habit.history[dateKey] = newProgress;
      habit.progress = newProgress;
      await habit.save();
      print('Успешно сохранено: ${habit.name}, прогресс: $newProgress');
    } catch (e) {
      print('Ошибка при сохранении привычки: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при сохранении: $e')),
      );
    }
  }

  void _showDayDetailsDialog(DateTime day) {
    final dateKey = _formatDate(day);
    final notesBox = Hive.box<Note>('notes');
    final moodsBox = Hive.box<Mood>('moods');
    final note = notesBox.values.firstWhere(
      (note) => note.date == dateKey,
      orElse: () => Note(date: dateKey, text: ''),
    );
    final mood = moodsBox.values.firstWhere(
      (mood) => mood.date == dateKey,
      orElse: () => Mood(date: dateKey, emoji: ''),
    );
    final TextEditingController noteController = TextEditingController(text: note.text);
    String selectedMood = mood.emoji.isNotEmpty ? mood.emoji : _moods[0];

    showDialog(
      context: context,
      builder: (context) => ValueListenableBuilder(
        valueListenable: Hive.box('settings').listenable(),
        builder: (context, box, child) {
          final language = box.get('language', defaultValue: 'Русский') as String;
          final localizations = AppLocalizations(language);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              '${localizations.getString('dayDetails')} ${DateFormat('d MMMM yyyy', language == 'Русский' ? 'ru' : 'en').format(day)}',
              style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.getString('noteLabel'),
                    style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      hintText: localizations.getString('enterNote'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    localizations.getString('moodLabel'),
                    style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: _moods.map((emoji) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedMood = emoji;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selectedMood == emoji ? Colors.indigo.withOpacity(0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selectedMood == emoji ? Colors.indigo : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  localizations.getString('cancelAction'),
                  style: const TextStyle(color: Colors.grey, fontFamily: 'Montserrat'),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (noteController.text.isNotEmpty) {
                    if (note.key == null) {
                      notesBox.add(Note(date: dateKey, text: noteController.text));
                    } else {
                      note.text = noteController.text;
                      note.save();
                    }
                  } else if (note.key != null) {
                    note.delete();
                  }

                  if (mood.key == null) {
                    moodsBox.add(Mood(date: dateKey, emoji: selectedMood));
                  } else {
                    mood.emoji = selectedMood;
                    mood.save();
                  }

                  Navigator.pop(context);
                  setState(() {});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  localizations.getString('saveAction'),
                  style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dateKey = _formatDate(_selectedDay);
    print('Используемый dateKey: $dateKey');

    final habitsBox = Hive.box<Habit>('habits');
    final notesBox = Hive.box<Note>('notes');
    final moodsBox = Hive.box<Mood>('moods');

    print('Все привычки в Hive:');
    for (var habit in habitsBox.values) {
      print('Привычка: ${habit.name}, history: ${habit.history}');
    }

    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, box, child) {
        final language = box.get('language', defaultValue: 'Русский') as String;
        final localizations = AppLocalizations(language);
        final categoryItems = [
          localizations.getString('all'),
          localizations.getString('health'),
          localizations.getString('study'),
          localizations.getString('work'),
        ].where((item) => item != null).toList();
        final filterItems = [
          localizations.getString('all'),
          localizations.getString('completed'),
          localizations.getString('notCompleted'),
        ].where((item) => item != null).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(
              localizations.getString('myHabits'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Montserrat',
              ),
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
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.indigo.withOpacity(0.1), Colors.white],
              ),
            ),
            child: ValueListenableBuilder(
              valueListenable: habitsBox.listenable(),
              builder: (context, Box<Habit> habitsBox, _) {
                return ValueListenableBuilder(
                  valueListenable: notesBox.listenable(),
                  builder: (context, Box<Note> notesBox, _) {
                    return ValueListenableBuilder(
                      valueListenable: moodsBox.listenable(),
                      builder: (context, Box<Mood> moodsBox, _) {
                        final allHabits = habitsBox.values.toList();
                        final habits = allHabits
                            .where((habit) {
                              if (habit.taskType == 'Одноразовая') {
                                if (habit.endDate == null) return false;
                                final endDate = DateFormat('yyyy-MM-dd').parse(habit.endDate!);
                                return isSameDay(endDate, _selectedDay);
                              }
                              final dayOfWeek = _getDayOfWeek(_selectedDay);
                              return habit.days.contains(dayOfWeek) &&
                                  (_selectedCategory == localizations.getString('all') ||
                                      habit.category == _selectedCategory) &&
                                  (_selectedFilter == localizations.getString('all') ||
                                      (_selectedFilter == localizations.getString('completed') &&
                                          (habit.history[dateKey] ?? habit.progress) >= habit.total) ||
                                      (_selectedFilter == localizations.getString('notCompleted') &&
                                          (habit.history[dateKey] ?? habit.progress) < habit.total));
                            })
                            .toList();

                        habits.sort((a, b) {
                          const priorityOrder = {'Высокий': 1, 'Средний': 2, 'Низкий': 3};
                          return priorityOrder[a.priority]!.compareTo(priorityOrder[b.priority]!);
                        });

                        final streak = getStreak(allHabits);
                        final completedHabits = allHabits.where((habit) => (habit.history[dateKey] ?? habit.progress) >= habit.total).length;
                        final bestProgress = allHabits.isEmpty
                            ? 0
                            : allHabits.map((habit) => (habit.history[dateKey] ?? habit.progress) / habit.total * 100).reduce(max);

                        return Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10),
                                ],
                              ),
                              child: TableCalendar(
                                firstDay: DateTime.utc(2020, 1, 1),
                                lastDay: DateTime.utc(2030, 12, 31),
                                focusedDay: _focusedDay,
                                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                                onDaySelected: (selectedDay, focusedDay) {
                                  setState(() {
                                    _selectedDay = selectedDay;
                                    _focusedDay = focusedDay;
                                  });
                                  _showDayDetailsDialog(selectedDay);
                                },
                                calendarFormat: CalendarFormat.week,
                                headerStyle: const HeaderStyle(
                                  formatButtonVisible: false,
                                  titleTextStyle: TextStyle(fontFamily: 'Montserrat', fontSize: 18),
                                ),
                                calendarStyle: const CalendarStyle(
                                  todayDecoration: BoxDecoration(
                                    color: Colors.indigo,
                                    shape: BoxShape.circle,
                                  ),
                                  selectedDecoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                calendarBuilders: CalendarBuilders(
                                  markerBuilder: (context, date, events) {
                                    final dateKey = _formatDate(date);
                                    final progress = getDailyProgress(allHabits, dateKey);
                                    final hasNote = notesBox.values.any((note) => note.date == dateKey);
                                    final mood = moodsBox.values.firstWhere(
                                      (mood) => mood.date == dateKey,
                                      orElse: () => Mood(date: dateKey, emoji: ''),
                                    );

                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (progress > 0) ...[
                                          Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 2),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: progress >= 100
                                                  ? Colors.green
                                                  : progress >= 50
                                                      ? Colors.yellow
                                                      : Colors.red,
                                            ),
                                            width: 6,
                                            height: 6,
                                          ),
                                        ],
                                        if (hasNote) ...[
                                          const Icon(
                                            Icons.note,
                                            size: 12,
                                            color: Colors.indigo,
                                          ),
                                        ],
                                        if (mood.emoji.isNotEmpty) ...[
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 2),
                                            child: Text(
                                              mood.emoji,
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  DropdownButton<String>(
                                    value: categoryItems.contains(_selectedCategory) ? _selectedCategory : categoryItems.first,
                                    items: categoryItems.map((category) {
                                      return DropdownMenuItem(
                                        value: category,
                                        child: Text(category, style: const TextStyle(fontFamily: 'Montserrat')),
                                      );
                                    }).toList(),
                                    onChanged: (value) => setState(() => _selectedCategory = value!),
                                  ),
                                  DropdownButton<String>(
                                    value: filterItems.contains(_selectedFilter) ? _selectedFilter : filterItems.first,
                                    items: filterItems.map((filter) {
                                      return DropdownMenuItem(
                                        value: filter,
                                        child: Text(filter, style: const TextStyle(fontFamily: 'Montserrat')),
                                      );
                                    }).toList(),
                                    onChanged: (value) => setState(() => _selectedFilter = value!),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        '${localizations.getString('today')} ${getDailyProgress(allHabits, dateKey).toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo,
                                          fontFamily: 'Montserrat',
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: CircularProgressIndicator(
                                          value: getDailyProgress(allHabits, dateKey) / 100,
                                          color: Colors.indigo,
                                          backgroundColor: Colors.grey.shade200,
                                          strokeWidth: 6,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        localizations.getStringWithParams('streakDays', [getStreak(allHabits)]),
                                        style: const TextStyle(fontFamily: 'Montserrat'),
                                      ),
                                      Text(
                                        localizations.getStringWithParams('completedHabits', [completedHabits]),
                                        style: const TextStyle(fontFamily: 'Montserrat'),
                                      ),
                                      Text(
                                        localizations.getStringWithParams('bestProgress', [bestProgress.toStringAsFixed(0)]),
                                        style: const TextStyle(fontFamily: 'Montserrat'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (getDailyProgress(allHabits, dateKey) >= 100)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                child: Text(
                                  localizations.getString(_quotes[Random().nextInt(_quotes.length)]),
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.indigo,
                                    fontFamily: 'Montserrat',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            Expanded(
                              child: habits.isEmpty
                                  ? _buildEmptyState(context, localizations)
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(20),
                                      itemCount: habits.length,
                                      itemBuilder: (context, index) {
                                        return HabitItem(
                                          habit: habits[index],
                                          dateKey: dateKey,
                                          screenWidth: screenWidth,
                                          onUpdateProgress: _updateHabitProgress,
                                          localizations: localizations,
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHabitScreen()));
            },
            backgroundColor: Colors.indigo,
            child: const Icon(Icons.add, size: 30, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations localizations) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lightbulb_outline, size: 80, color: Colors.indigo),
          const SizedBox(height: 20),
          Text(
            localizations.getString('startNow'),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
              fontFamily: 'Montserrat',
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              localizations.getString('addFirstHabit'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontFamily: 'Montserrat'),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHabitScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              localizations.getString('addHabit'),
              style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
            ),
          ),
        ],
      ),
    );
  }
}

class HabitItem extends StatefulWidget {
  final Habit habit;
  final String dateKey;
  final double screenWidth;
  final Future<void> Function(Habit, String, int) onUpdateProgress;
  final AppLocalizations localizations;

  const HabitItem({
    super.key,
    required this.habit,
    required this.dateKey,
    required this.screenWidth,
    required this.onUpdateProgress,
    required this.localizations,
  });

  @override
  _HabitItemState createState() => _HabitItemState();
}

class _HabitItemState extends State<HabitItem> {
  bool _isLoading = false;

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'water_drop':
        return Icons.water_drop;
      case 'book':
        return Icons.book;
      case 'fitness_center':
        return Icons.fitness_center;
      default:
        return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.habit.history[widget.dateKey] ?? widget.habit.progress;
    final progressPercent = (progress / widget.habit.total * 100).toStringAsFixed(0);
    final iconData = _getIconData(widget.habit.icon);

    return Slidable(
      key: ValueKey(widget.habit.key),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditHabitScreen(habit: widget.habit),
                ),
              );
            },
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: widget.localizations.getString('editAction'),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              widget.habit.delete();
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: widget.localizations.getString('deleteAction'),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HabitDetailScreen(habit: widget.habit),
            ),
          );
        },
        onLongPress: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(widget.habit.name, style: const TextStyle(fontFamily: 'Montserrat')),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditHabitScreen(habit: widget.habit),
                      ),
                    );
                  },
                  child: Text(
                    widget.localizations.getString('editAction'),
                    style: const TextStyle(fontFamily: 'Montserrat'),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    widget.habit.delete();
                    Navigator.pop(context);
                  },
                  child: Text(
                    widget.localizations.getString('deleteAction'),
                    style: TextStyle(color: Colors.red, fontFamily: 'Montserrat'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    widget.localizations.getString('closeAction'),
                    style: const TextStyle(fontFamily: 'Montserrat'),
                  ),
                ),
              ],
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
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
                  color: Color(int.parse(widget.habit.color)),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                ),
              ),
              const SizedBox(width: 15),
              Icon(iconData, color: Color(int.parse(widget.habit.color))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.habit.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.indigo,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${widget.localizations.getString('goal')} ${widget.habit.goal}',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontFamily: 'Montserrat'),
                    ),
                    const SizedBox(height: 5),
                    LinearProgressIndicator(
                      value: progress / widget.habit.total,
                      color: Color(int.parse(widget.habit.color)),
                      backgroundColor: Colors.grey.shade200,
                    ),
                    Text('$progressPercent% (${progress}/${widget.habit.total})', style: const TextStyle(fontFamily: 'Montserrat')),
                  ],
                ),
              ),
              _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                    )
                  : IconButton(
                      icon: Icon(
                        progress >= widget.habit.total ? Icons.check_circle : Icons.check_circle_outline,
                        color: progress >= widget.habit.total ? Color(int.parse(widget.habit.color)) : Colors.grey,
                      ),
                      onPressed: () async {
                        print('Нажатие на чекбокс: ${widget.habit.name}, текущий прогресс: $progress');
                        setState(() {
                          _isLoading = true;
                        });
                        try {
                          final newProgress = progress < widget.habit.total ? (progress + 1).clamp(0, widget.habit.total) : 0;
                          await widget.onUpdateProgress(widget.habit, widget.dateKey, newProgress);
                        } catch (e) {
                          print('Ошибка при обновлении прогресса: $e');
                        } finally {
                          setState(() {
                            _isLoading = false;
                          });
                        }
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}