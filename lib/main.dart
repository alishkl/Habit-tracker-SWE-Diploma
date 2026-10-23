import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/onboarding_screen.dart';
import 'models/habit.dart';
import 'models/note.dart';
import 'models/mood.dart';
import 'models/challenge.dart';
import 'models/reward.dart';
import 'localizations/app_localizations.dart';
import 'screens/main_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация локали для intl
  await initializeDateFormatting('ru', null);

  // Инициализация Hive
  await Hive.initFlutter();
  Hive.registerAdapter(HabitAdapter());
  Hive.registerAdapter(NoteAdapter());
  Hive.registerAdapter(MoodAdapter());
  Hive.registerAdapter(ChallengeAdapter());
  Hive.registerAdapter(RewardAdapter());
  await Hive.openBox<Habit>('habits');
  await Hive.openBox<Note>('notes');
  await Hive.openBox<Mood>('moods');
  await Hive.openBox<Challenge>('challenges');
  await Hive.openBox<Reward>('rewards');
  await Hive.openBox('user');
  await Hive.openBox('settings');

  // Проверяем содержимое Hive и очищаем некорректные данные
  final box = Hive.box<Habit>('habits');
  print('Проверка содержимого Hive перед запуском:');
  for (var habit in box.values.toList()) {
    print('Привычка: ${habit.name}, history: ${habit.history}');
    final history = Map<String, int>.from(habit.history);
    bool hasInvalidData = false;
    for (var key in history.keys) {
      final parts = key.split('-');
      if (parts.length != 3) {
        print('Некорректный ключ в history: $key');
        hasInvalidData = true;
        continue;
      }
      try {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        final date = DateTime(year, month, day);
        const minMillis = -8640000000000000;
        const maxMillis = 8640000000000000;
        final millis = date.millisecondsSinceEpoch;
        if (millis < minMillis || millis > maxMillis) {
          print('Дата $key вне допустимого диапазона: $date');
          hasInvalidData = true;
        }
      } catch (e) {
        print('Ошибка при разборе ключа $key: $e');
        hasInvalidData = true;
      }
    }
    if (hasInvalidData) {
      print('Очистка некорректных данных для привычки: ${habit.name}');
      habit.history.clear();
      await habit.save();
    }
  }

  // Инициализация часовых поясов
  tz.initializeTimeZones();

  // Инициализация уведомлений
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  try {
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    print('Уведомления успешно инициализированы');
  } catch (e) {
    print('Ошибка инициализации уведомлений: $e');
  }

  // Запрос разрешения на уведомления
  var status = await Permission.notification.status;
  if (!status.isGranted) {
    status = await Permission.notification.request();
    if (!status.isGranted) {
      print('Пользователь отказал в разрешении на уведомления');
    }
  }

  runApp(const HabitTrackerApp());
}

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, box, child) {
        final darkTheme = box.get('darkTheme', defaultValue: false) as bool;
        final language = box.get('language', defaultValue: 'Русский') as String;
        final localizations = AppLocalizations(language);
        return MaterialApp(
          title: localizations.getString('appTitle') ?? 'Habit Tracker',
          theme: ThemeData(
            primarySwatch: Colors.indigo,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            fontFamily: 'Montserrat',
            brightness: darkTheme ? Brightness.dark : Brightness.light,
            colorScheme: darkTheme
                ? const ColorScheme.dark(primary: Colors.indigo)
                : const ColorScheme.light(primary: Colors.indigo),
          ),
          home: OnboardingScreen(
            flutterLocalNotificationsPlugin: flutterLocalNotificationsPlugin,
          ),
        );
      },
    );
  }
}