import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/habit.dart';
import 'edit_habit_screen.dart';

class HabitDetailScreen extends StatelessWidget {
  final Habit habit;

  const HabitDetailScreen({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    final history = habit.history.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.name),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.indigo, Color.fromARGB(255, 143, 147, 173)],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditHabitScreen(habit: habit),
                ),
              );
            },
          ),
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
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ListView(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getIconData(habit.icon),
                            color: Color(int.parse(habit.color)),
                            size: 30,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  habit.name,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Цель: ${habit.goal}',
                                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Тип задачи: ${habit.taskType}'),
                      Text('Категория: ${habit.category}'),
                      Text('Приоритет: ${habit.priority}'),
                      if (habit.taskType == 'Регулярная')
                        Text('Дни: ${habit.days.join(", ")}'),
                      if (habit.endDate != null)
                        Text('Срок: ${habit.endDate}'),
                      if (habit.note != null && habit.note!.isNotEmpty)
                        Text('Примечание: ${habit.note}'),
                      const SizedBox(height: 10),
                      const Text('Напоминания:', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (habit.reminders.isEmpty)
                        const Text('Нет напоминаний'),
                      ...habit.reminders.map((time) => Text(time)),
                      const SizedBox(height: 10),
                      const Text('Подзадачи:', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (habit.subTasks.isEmpty)
                        const Text('Нет подзадач'),
                      ...habit.subTasks.map((subTask) => Text('- $subTask')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('История выполнения:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('История пока пуста'),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final entry = history[index];
                    return ListTile(
                      title: Text(entry.key),
                      trailing: Text('${entry.value}/${habit.total}'),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

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
}