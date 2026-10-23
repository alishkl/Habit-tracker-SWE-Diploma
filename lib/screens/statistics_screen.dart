import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/challenge.dart';
import '../models/habit.dart';
import '../models/reward.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedPeriod = 'За всё время';
  final List<String> _periods = ['Последние 7 дней', 'Май 2025', 'За всё время'];

  // Форматирование даты
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Фильтрация данных по выбранному периоду
  bool _isInPeriod(DateTime date, String period) {
    final now = DateTime.now();
    if (period == 'За всё время') return true;
    if (period == 'Последние 7 дней') {
      return date.isAfter(now.subtract(const Duration(days: 7)));
    }
    if (period == 'Май 2025') {
      return date.year == 2025 && date.month == 5;
    }
    return true;
  }

  // Подсчёт процента выполнения привычек
  double _calculateHabitCompletionRate(List<Habit> habits, String period) {
    int totalDays = 0;
    int completedDays = 0;

    for (var habit in habits) {
      habit.history.forEach((dateStr, progress) {
        try {
          final date = DateFormat('yyyy-MM-dd').parse(dateStr);
          if (_isInPeriod(date, period)) {
            totalDays++;
            num progressValue = 0;
            if (progress is num) {
              progressValue = progress;
            } else {
              progressValue = num.tryParse(progress?.toString() ?? '0') ?? 0;
            }
            num goalValue = habit.goal is num ? habit.goal as num : 0;
            if (progressValue >= goalValue) {
              completedDays++;
            }
          }
        } catch (e) {
          print('Ошибка парсинга даты в _calculateHabitCompletionRate: $e');
        }
      });
    }

    return totalDays == 0 ? 0.0 : (completedDays / totalDays * 100).toDouble();
  }

  // Поиск самой регулярной привычки
  Habit? _findMostConsistentHabit(List<Habit> habits, String period) {
    Habit? mostConsistent;
    double highestRate = 0.0;

    for (var habit in habits) {
      int totalDays = 0;
      int completedDays = 0;
      habit.history.forEach((dateStr, progress) {
        try {
          final date = DateFormat('yyyy-MM-dd').parse(dateStr);
          if (_isInPeriod(date, period)) {
            totalDays++;
            num progressValue = 0;
            if (progress is num) {
              progressValue = progress;
            } else if (progress is String) {
              progressValue = num.tryParse(progress as String) ?? 0;
            }
            num goalValue = habit.goal is num ? habit.goal as num : 0;
            if (progressValue >= goalValue) {
              completedDays++;
            }
          }
        } catch (e) {
          print('Ошибка парсинга даты в _findMostConsistentHabit: $e');
        }
      });
      final rate = totalDays == 0 ? 0.0 : (completedDays / totalDays * 100).toDouble();
      if (rate > highestRate) {
        highestRate = rate;
        mostConsistent = habit;
      }
    }

    return mostConsistent;
  }

  // Подсчёт активных дней
  int _calculateActiveDays(List<Habit> habits, String period) {
    final activeDays = <String>{};
    for (var habit in habits) {
      habit.history.forEach((dateStr, progress) {
        try {
          final date = DateFormat('yyyy-MM-dd').parse(dateStr);
          if (_isInPeriod(date, period)) {
            num progressValue = 0;
            if (progress is num) {
              progressValue = progress;
            } else if (progress is String) {
              progressValue = num.tryParse(progress as String) ?? 0;
            }
            if (progressValue > 0) {
              activeDays.add(dateStr);
            }
          }
        } catch (e) {
          print('Ошибка парсинга даты в _calculateActiveDays: $e');
        }
      });
    }
    return activeDays.length;
  }

  // Поиск активности по дням недели
  Map<String, int> _getWeeklyActivity(List<Habit> habits, List<Challenge> challenges, String period) {
    final dayCounts = {'Пн': 0, 'Вт': 0, 'Ср': 0, 'Чт': 0, 'Пт': 0, 'Сб': 0, 'Вс': 0};
    for (var habit in habits) {
      habit.history.forEach((dateStr, progress) {
        try {
          final date = DateFormat('yyyy-MM-dd').parse(dateStr);
          if (_isInPeriod(date, period)) {
            num progressValue = 0;
            if (progress is num) {
              progressValue = progress;
            } else if (progress is String) {
              progressValue = num.tryParse(progress as String) ?? 0;
            }
            if (progressValue > 0) {
              String dayKey = DateFormat('E').format(date).substring(0, 2);
              dayCounts.update(dayKey, (value) => value + 1, ifAbsent: () => 1);
            }
          }
        } catch (e) {
          print('Ошибка парсинга даты в _getWeeklyActivity (habits): $e');
        }
      });
    }
    for (var challenge in challenges) {
      if (challenge.progress != null && challenge.startDate.isNotEmpty) {
        try {
          final startDate = DateFormat('yyyy-MM-dd').parse(challenge.startDate);
          for (int i = 0; i < challenge.progress!.length; i++) {
            if (challenge.progress![i]) {
              final date = startDate.add(Duration(days: i));
              if (_isInPeriod(date, period)) {
                String dayKey = DateFormat('E').format(date).substring(0, 2);
                dayCounts.update(dayKey, (value) => value + 1, ifAbsent: () => 1);
              }
            }
          }
        } catch (e) {
          print('Ошибка парсинга даты в _getWeeklyActivity (challenges): $e');
        }
      }
    }
    return dayCounts;
  }

  // Подсчёт статистики по типам наград
  Map<String, int> _calculateRewardTypes(List<Reward> rewards) {
    final types = <String, int>{};
    for (var reward in rewards) {
      if (reward.icon.isNotEmpty) {
        types[reward.icon] = (types[reward.icon] ?? 0) + 1;
      }
    }
    return types;
  }

  // Поиск самой редкой награды
  Reward? _findRarestReward(List<Reward> rewards) {
    if (rewards.isEmpty) return null;
    final types = _calculateRewardTypes(rewards);
    if (types.isEmpty) return null;
    final rarestIcon = types.entries.reduce((a, b) => a.value < b.value ? a : b).key;
    return rewards.lastWhere((reward) => reward.icon == rarestIcon);
  }

  // Генерация мотивационного совета
  String _generateMotivationalTip(List<Habit> habits, List<Challenge> challenges) {
    for (var challenge in challenges) {
      if (!challenge.isCompleted) {
        final progress = challenge.progress?.where((day) => day).length ?? 0;
        final duration = challenge.duration is num ? challenge.duration as num : 0;
        final remainingDays = duration - progress;
        if (remainingDays <= 3 && remainingDays > 0) {
          return "Осталось $remainingDays дней до завершения '${challenge.title}'! Не сдавайся! 🚀";
        }
      }
    }

    final dayCounts = List<int>.filled(7, 0);
    for (var habit in habits) {
      habit.history.forEach((dateStr, progress) {
        try {
          final date = DateFormat('yyyy-MM-dd').parse(dateStr);
          if (_isInPeriod(date, _selectedPeriod)) {
            num progressValue = 0;
            if (progress is num) {
              progressValue = progress;
            } else if (progress is String) {
              progressValue = num.tryParse(progress as String) ?? 0;
            }
            if (progressValue == 0) {
              dayCounts[date.weekday - 1]++;
            }
          }
        } catch (e) {
          print('Ошибка парсинга даты в _generateMotivationalTip: $e');
        }
      });
    }
    final maxMissed = dayCounts.isNotEmpty ? dayCounts.reduce((a, b) => a > b ? a : b) : 0;
    final maxMissedDay = dayCounts.indexOf(maxMissed);
    if (maxMissed > 0) {
      const days = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
      return "Вы часто пропускаете задачи по ${days[maxMissedDay]}. Попробуйте планировать меньше в этот день!";
    }

    return "Вы на правильном пути! Продолжайте в том же духе! 🌟";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Статистика',
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
        actions: [
          DropdownButton<String>(
            value: _selectedPeriod,
            items: _periods.map((period) {
              return DropdownMenuItem(
                value: period,
                child: Text(
                  period,
                  style: const TextStyle(fontFamily: 'Montserrat', color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedPeriod = value!),
            dropdownColor: Colors.indigo,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo.withOpacity(0.1), Colors.white],
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ваш прогресс',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder(
                valueListenable: Hive.box('user').listenable(),
                builder: (context, Box userBox, _) {
                  final points = userBox.get('points', defaultValue: 0);
                  return Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 30),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Очки опыта: $points',
                              style: const TextStyle(
                                fontSize: 18,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder(
                valueListenable: Hive.box<Challenge>('challenges').listenable(),
                builder: (context, Box<Challenge> challengesBox, _) {
                  final challenges = challengesBox.values.toList();
                  final completedChallenges = challenges.where((c) => c.isCompleted).length;
                  final totalChallenges = challenges.length;
                  final completionRate = totalChallenges == 0 ? 0.0 : (completedChallenges / totalChallenges * 100).toDouble();
                  final averageDuration = totalChallenges == 0
                      ? 0.0
                      : challenges.map((c) => (c.duration is num ? c.duration as num : 0)).reduce((a, b) => a + b) / totalChallenges;
                  final longestChallenge = challenges.isNotEmpty
                      ? challenges.reduce((a, b) => (a.duration is num ? a.duration as num : 0) > (b.duration is num ? b.duration as num : 0) ? a : b)
                      : null;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 30),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Завершено $completedChallenges из $totalChallenges челленджей (${completionRate.toStringAsFixed(1)}%)',
                                  style: const TextStyle(fontSize: 18, fontFamily: 'Montserrat'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Row(
                            children: [
                              const Icon(Icons.timer, color: Colors.indigo, size: 30),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Средняя длительность челленджа: ${averageDuration.toStringAsFixed(1)} дней',
                                  style: const TextStyle(fontSize: 18, fontFamily: 'Montserrat'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (longestChallenge != null) ...[
                        const SizedBox(height: 10),
                        Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Row(
                              children: [
                                const Icon(Icons.emoji_events, color: Colors.purple, size: 30),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Самый длинный челлендж: '${longestChallenge.title}' — ${(longestChallenge.duration is num ? longestChallenge.duration as num : 0)} дней",
                                    style: const TextStyle(fontSize: 18, fontFamily: 'Montserrat'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Статистика по привычкам',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder(
                valueListenable: Hive.box<Habit>('habits').listenable(),
                builder: (context, Box<Habit> habitsBox, _) {
                  final habits = habitsBox.values.toList();
                  final completionRate = _calculateHabitCompletionRate(habits, _selectedPeriod);
                  final mostConsistentHabit = _findMostConsistentHabit(habits, _selectedPeriod);
                  final activeDays = _calculateActiveDays(habits, _selectedPeriod);
                  final totalDays = _selectedPeriod == 'Последние 7 дней'
                      ? 7
                      : _selectedPeriod == 'Май 2025'
                          ? 31
                          : habits.isEmpty
                              ? 0
                              : habits.map((h) => h.history.keys.length).fold<int>(0, (a, b) => a > b ? a : b);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Процент выполнения',
                                style: TextStyle(fontSize: 16, fontFamily: 'Montserrat', color: Colors.indigo),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 200,
                                child: PieChart(
                                  PieChartData(
                                    sections: [
                                      PieChartSectionData(
                                        value: completionRate,
                                        color: Colors.green,
                                        title: '${completionRate.toStringAsFixed(1)}%',
                                        radius: 80,
                                        titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      PieChartSectionData(
                                        value: 100 - completionRate,
                                        color: Colors.red.withOpacity(0.7),
                                        title: '${(100 - completionRate).toStringAsFixed(1)}%',
                                        radius: 80,
                                        titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                    sectionsSpace: 0,
                                    centerSpaceRadius: 40,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (mostConsistentHabit != null)
                        Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Row(
                              children: [
                                const Icon(Icons.favorite, color: Colors.red, size: 30),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Самая регулярная привычка: '${mostConsistentHabit.name}'",
                                    style: const TextStyle(fontSize: 18, fontFamily: 'Montserrat'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.orange, size: 30),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Активные дни: $activeDays из $totalDays',
                                  style: const TextStyle(fontSize: 18, fontFamily: 'Montserrat'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Временной анализ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder(
                valueListenable: Hive.box<Habit>('habits').listenable(),
                builder: (context, Box<Habit> habitsBox, _) {
                  return ValueListenableBuilder(
                    valueListenable: Hive.box<Challenge>('challenges').listenable(),
                    builder: (context, Box<Challenge> challengesBox, _) {
                      final habits = habitsBox.values.toList();
                      final challenges = challengesBox.values.toList();
                      final weeklyActivity = _getWeeklyActivity(habits, challenges, _selectedPeriod);

                      return Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Активность по дням',
                                style: TextStyle(fontSize: 16, fontFamily: 'Montserrat', color: Colors.indigo),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 200,
                                child: LineChart(
                                  LineChartData(
                                    gridData: const FlGridData(show: true),
                                    titlesData: FlTitlesData(
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 22,
                                          getTitlesWidget: (value, meta) {
                                            const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              space: 8,
                                              child: Text(days[value.toInt()], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            );
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(showTitles: true),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.3))),
                                    minX: 0,
                                    maxX: 6,
                                    minY: 0,
                                    maxY: weeklyActivity.values.reduce((a, b) => a > b ? a : b) + 1.0,
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: [
                                          FlSpot(0, weeklyActivity['Пн']!.toDouble()),
                                          FlSpot(1, weeklyActivity['Вт']!.toDouble()),
                                          FlSpot(2, weeklyActivity['Ср']!.toDouble()),
                                          FlSpot(3, weeklyActivity['Чт']!.toDouble()),
                                          FlSpot(4, weeklyActivity['Пт']!.toDouble()),
                                          FlSpot(5, weeklyActivity['Сб']!.toDouble()),
                                          FlSpot(6, weeklyActivity['Вс']!.toDouble()),
                                        ],
                                        isCurved: true,
                                        color: Colors.blue,
                                        barWidth: 2,
                                        dotData: const FlDotData(show: true),
                                        belowBarData: BarAreaData(show: false),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Ваши награды',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder(
                valueListenable: Hive.box<Reward>('rewards').listenable(),
                builder: (context, Box<Reward> rewardsBox, _) {
                  final rewards = rewardsBox.values.toList();
                  final rewardTypes = _calculateRewardTypes(rewards);
                  final rarestReward = _findRarestReward(rewards);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Row(
                            children: [
                              const Icon(Icons.emoji_events, color: Colors.amber, size: 30),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Типы наград: ${rewardTypes.isEmpty ? "Нет данных" : rewardTypes.entries.map((e) => '${e.key}: ${e.value}').join(', ')}',
                                  style: const TextStyle(fontSize: 18, fontFamily: 'Montserrat'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (rarestReward != null) ...[
                        const SizedBox(height: 10),
                        Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Row(
                              children: [
                                const Icon(Icons.star_border, color: Colors.purple, size: 30),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Самая редкая награда: '${rarestReward.title}' (${rarestReward.icon})",
                                    style: const TextStyle(fontSize: 18, fontFamily: 'Montserrat'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (rewards.isEmpty)
                        const Center(
                          child: Text(
                            'У вас пока нет наград. Завершайте челленджи, чтобы их получить!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Montserrat', color: Colors.grey),
                          ),
                        )
                      else
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            itemCount: rewards.length,
                            itemBuilder: (context, index) {
                              final reward = rewards[index];
                              return Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  leading: Text(
                                    reward.icon.isNotEmpty ? reward.icon : '🏆',
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  title: Text(
                                    reward.title.isNotEmpty ? reward.title : 'Без названия',
                                    style: const TextStyle(fontFamily: 'Montserrat'),
                                  ),
                                  subtitle: Text(
                                    'Получено: ${reward.dateEarned.isNotEmpty ? reward.dateEarned : 'Неизвестно'}',
                                    style: const TextStyle(fontFamily: 'Montserrat', color: Colors.grey),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Совет',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder(
                valueListenable: Hive.box<Habit>('habits').listenable(),
                builder: (context, Box<Habit> habitsBox, _) {
                  return ValueListenableBuilder(
                    valueListenable: Hive.box<Challenge>('challenges').listenable(),
                    builder: (context, Box<Challenge> challengesBox, _) {
                      final habits = habitsBox.values.toList();
                      final challenges = challengesBox.values.toList();
                      final tip = _generateMotivationalTip(habits, challenges);

                      return Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Row(
                            children: [
                              const Icon(Icons.lightbulb_outline, color: Colors.yellow, size: 30),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  tip,
                                  style: const TextStyle(fontSize: 16, fontFamily: 'Montserrat', fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}