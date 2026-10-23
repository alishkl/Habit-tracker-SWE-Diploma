import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:math';
import '../models/challenge.dart';
import '../models/habit.dart';
import '../models/reward.dart';
import 'add_challenge_screen.dart';

class ChallengesScreen extends StatefulWidget {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  const ChallengesScreen({super.key, required this.flutterLocalNotificationsPlugin});

  @override
  _ChallengesScreenState createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> with TickerProviderStateMixin {
  String _selectedFilter = 'Все';
  String _selectedSort = 'По дате';
  final List<String> _filters = ['Все', 'Активные', 'Завершённые'];
  final List<String> _sortOptions = ['По дате', 'По длительности'];
  final List<String> _quotes = [
    'Ты сделал это! Горжусь тобой! 🎉',
    'Невероятный результат, продолжай в том же духе!',
    'Ты настоящий герой челленджей! 🏆',
  ];

  // Список ежедневных советов
  final List<String> _dailyTips = [
    'Не сдавайтесь, вы уже на полпути!',
    'Каждый день — это шаг к вашей цели!',
    'Маленькие победы ведут к большим результатам!',
    'Оставайтесь сфокусированными, вы справитесь!',
    'Празднуйте каждый прогресс, даже маленький!',
    'Держите ритм, вы на правильном пути!',
    'Верьте в себя — вы сильнее, чем думаете!',
  ];

  // Маппинг иконок
  final Map<String, IconData> _icons = {
    'star': Icons.star,
    'water_drop': Icons.water_drop,
    'book': Icons.book,
    'fitness_center': Icons.fitness_center,
    'meditation': Icons.self_improvement,
    'phone_off': Icons.phone_disabled,
  };

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  int _calculateProgress(Challenge challenge) {
    return challenge.progress?.where((day) => day).length ?? 0;
  }

  void _markDayAsCompleted(Challenge challenge, int dayIndex) async {
    if (dayIndex < (challenge.progress?.length ?? 0) && !challenge.isCompleted) {
      print('Отмечаем день $dayIndex для челленджа: ${challenge.title}');
      setState(() {
        challenge.progress![dayIndex] = true;
        final progress = _calculateProgress(challenge);
        if (progress == challenge.duration) {
          challenge.isCompleted = true;
          _awardReward(challenge);
          _cancelReminder(challenge);
        }
        challenge.save();
      });

      // Если челлендж связан с привычкой, обновляем прогресс привычки
      if (challenge.habitKey != null) {
        final habitsBox = Hive.box<Habit>('habits');
        final habit = habitsBox.values.firstWhere(
          (h) => h.key.toString() == challenge.habitKey,
          orElse: () => throw Exception('Связанная привычка не найдена'),
        );
        final todayKey = _formatDate(DateTime.now());
        habit.history[todayKey] = (habit.history[todayKey] ?? habit.progress) + 1;
        habit.progress = habit.history[todayKey]!;
        habit.save();
        print('Обновлён прогресс привычки: ${habit.name}, ключ: $todayKey, значение: ${habit.progress}');
      }
    }
  }

  void _awardReward(Challenge challenge) {
    print('Начисляем награду за челлендж: ${challenge.title}');
    final rewardsBox = Hive.box<Reward>('rewards');
    final userBox = Hive.box('user');
    String rewardTitle;
    String rewardIcon;

    if (challenge.duration >= 30) {
      rewardTitle = 'Герой ${challenge.duration} дней';
      rewardIcon = '🏆';
    } else if (challenge.duration >= 14) {
      rewardTitle = 'Мастер ${challenge.duration} дней';
      rewardIcon = '🥇';
    } else {
      rewardTitle = 'Новичок ${challenge.duration} дней';
      rewardIcon = '🌟';
    }

    rewardsBox.add(Reward(
      title: rewardTitle,
      icon: rewardIcon,
      dateEarned: _formatDate(DateTime.now()),
    ));

    // Начисляем очки опыта
    int points = userBox.get('points', defaultValue: 0);
    points += challenge.duration * 10; // 10 очков за день
    userBox.put('points', points);

    print('Награда добавлена: $rewardTitle, очки: $points');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Поздравляем! Вы получили награду: $rewardTitle $rewardIcon и $points очков!')),
    );
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

  void _cancelReminder(Challenge challenge) async {
    final notificationId = challenge.key.hashCode;
    print('Отмена напоминаний для челленджа: ${challenge.title}, ID: $notificationId');
    for (int i = 0; i < challenge.duration; i++) {
      await widget.flutterLocalNotificationsPlugin.cancel(notificationId + i);
      print('Отменено уведомление с ID: ${notificationId + i}');
    }
  }

  // Вычисляем день года вручную
  int _getDayOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    return date.difference(startOfYear).inDays + 1;
  }

  // Получаем совет дня
  String _getDailyTip() {
    final dayOfYear = _getDayOfYear(DateTime.now());
    final index = dayOfYear % _dailyTips.length;
    return _dailyTips[index];
  }

  @override
  Widget build(BuildContext context) {
    final today = _formatDate(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Челленджи',
          style: TextStyle(
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
          valueListenable: Hive.box<Challenge>('challenges').listenable(),
          builder: (context, Box<Challenge> challengesBox, _) {
            print('Обновление списка челленджей, всего: ${challengesBox.values.length}');
            challengesBox.values.forEach((challenge) {
              print('Челлендж в базе: ${challenge.title}, isCompleted: ${challenge.isCompleted}, startDate: ${challenge.startDate}');
            });

            return ValueListenableBuilder(
              valueListenable: Hive.box<Reward>('rewards').listenable(),
              builder: (context, Box<Reward> rewardsBox, _) {
                final allChallenges = challengesBox.values.toList();
                final challenges = allChallenges.where((challenge) {
                  if (_selectedFilter == 'Все') return true;
                  if (_selectedFilter == 'Активные') return !challenge.isCompleted;
                  return challenge.isCompleted;
                }).toList();

                print('Отфильтровано челленджей: ${challenges.length}, фильтр: $_selectedFilter');

                challenges.sort((a, b) {
                  try {
                    if (_selectedSort == 'По дате') {
                      final dateA = DateFormat('yyyy-MM-dd').parse(a.startDate);
                      final dateB = DateFormat('yyyy-MM-dd').parse(b.startDate);
                      return dateB.compareTo(dateA);
                    }
                    return b.duration.compareTo(a.duration);
                  } catch (e) {
                    print('Ошибка сортировки: $e');
                    return 0;
                  }
                });

                final completedChallenges = allChallenges.where((c) => c.isCompleted).length;
                final totalChallenges = allChallenges.length;
                final completionRate = totalChallenges == 0 ? 0 : (completedChallenges / totalChallenges * 100);

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          DropdownButton<String>(
                            value: _selectedFilter,
                            items: _filters.map((filter) {
                              return DropdownMenuItem(
                                value: filter,
                                child: Text(filter, style: const TextStyle(fontFamily: 'Montserrat')),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedFilter = value!),
                          ),
                          DropdownButton<String>(
                            value: _selectedSort,
                            items: _sortOptions.map((sort) {
                              return DropdownMenuItem(
                                value: sort,
                                child: Text(sort, style: const TextStyle(fontFamily: 'Montserrat')),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedSort = value!),
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
                                'Завершено: $completedChallenges/$totalChallenges',
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
                                  value: completionRate / 100,
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
                                'Награды: ${rewardsBox.length}',
                                style: const TextStyle(fontFamily: 'Montserrat'),
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 5,
                                children: rewardsBox.values
                                    .take(3)
                                    .map((reward) => Text(
                                          reward.icon,
                                          style: const TextStyle(fontSize: 20),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Row(
                            children: [
                              const Icon(Icons.lightbulb_outline, color: Colors.indigo),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Совет дня: ${_getDailyTip()}',
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.indigo,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: challenges.isEmpty
                          ? _buildEmptyState(context)
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: challenges.length,
                              itemBuilder: (context, index) {
                                final challenge = challenges[index];
                                if (challenge == null) {
                                  print('Ошибка: челлендж с индексом $index равен null');
                                  return const SizedBox.shrink();
                                }
                                DateTime? startDate;
                                try {
                                  startDate = DateFormat('yyyy-MM-dd').parse(challenge.startDate);
                                } catch (e) {
                                  print('Ошибка парсинга даты для челленджа ${challenge.title}: $e');
                                  return const SizedBox.shrink();
                                }
                                final daysSinceStart = DateTime.now().difference(startDate).inDays;
                                final currentDayIndex = daysSinceStart.clamp(0, challenge.duration - 1);
                                final progress = _calculateProgress(challenge);

                                print('Отображение челленджа: ${challenge.title}, индекс: $index, прогресс: $progress');

                                return ChallengeItem(
                                  challenge: challenge,
                                  currentDayIndex: currentDayIndex,
                                  daysSinceStart: daysSinceStart,
                                  progress: progress,
                                  onMarkDay: _markDayAsCompleted,
                                  icons: _icons,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddChallengeScreen(
              flutterLocalNotificationsPlugin: widget.flutterLocalNotificationsPlugin,
            )),
          );
        },
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, size: 30, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star_border, size: 80, color: Colors.indigo),
          const SizedBox(height: 20),
          const Text(
            'Нет челленджей!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
              fontFamily: 'Montserrat',
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Добавьте свой первый челлендж и начните!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey, fontFamily: 'Montserrat'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddChallengeScreen(
                  flutterLocalNotificationsPlugin: widget.flutterLocalNotificationsPlugin,
                )),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Добавить челлендж',
              style: TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
            ),
          ),
        ],
      ),
    );
  }
}

class ChallengeItem extends StatefulWidget {
  final Challenge challenge;
  final int currentDayIndex;
  final int daysSinceStart;
  final int progress;
  final Function(Challenge, int) onMarkDay;
  final Map<String, IconData> icons;

  const ChallengeItem({
    super.key,
    required this.challenge,
    required this.currentDayIndex,
    required this.daysSinceStart,
    required this.progress,
    required this.onMarkDay,
    required this.icons,
  });

  @override
  _ChallengeItemState createState() => _ChallengeItemState();
}

class _ChallengeItemState extends State<ChallengeItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  final List<String> _quotes = [
    'Ты сделал это! Горжусь тобой! 🎉',
    'Невероятный результат, продолжай в том же духе!',
    'Ты настоящий герой челленджей! 🏆',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    if (widget.challenge.isCompleted) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ChallengeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.challenge.isCompleted && widget.challenge.isCompleted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Временно отключаем ScaleTransition для отладки
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Ограничиваем ширину внутреннего Row
              SizedBox(
                width: MediaQuery.of(context).size.width - 120, // Учитываем отступы и иконку справа
                child: Row(
                  children: [
                    Icon(
                      widget.icons[widget.challenge.icon] ?? Icons.star,
                      color: Colors.indigo,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.challenge.title ?? 'Без названия',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.indigo,
                          fontFamily: 'Montserrat',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.challenge.isCompleted)
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            widget.challenge.description ?? 'Без описания',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontFamily: 'Montserrat'),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: widget.progress / (widget.challenge.duration != 0 ? widget.challenge.duration : 1),
            color: Colors.indigo,
            backgroundColor: Colors.grey.shade200,
          ),
          const SizedBox(height: 5),
          Text(
            'Прогресс: ${widget.progress}/${widget.challenge.duration} дней',
            style: const TextStyle(fontFamily: 'Montserrat'),
          ),
          const SizedBox(height: 10),
          // Визуальный "путь" с днями
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: List.generate(widget.challenge.duration, (index) {
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < widget.progress
                      ? Colors.green
                      : index == widget.currentDayIndex && !widget.challenge.isCompleted
                          ? Colors.indigo
                          : Colors.grey.shade300,
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          if (!widget.challenge.isCompleted && widget.daysSinceStart >= 0)
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  widget.onMarkDay(widget.challenge, widget.currentDayIndex);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'Отметить день ${widget.currentDayIndex + 1}',
                  style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
                ),
              ),
            ),
          if (widget.challenge.isCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _quotes[Random().nextInt(_quotes.length)],
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.indigo,
                  fontFamily: 'Montserrat',
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}