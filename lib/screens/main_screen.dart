import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'home_screen.dart';
import 'statistics_screen.dart';
import 'challenges_screen.dart';
import 'settings_screen.dart';
import '../localizations/app_localizations.dart';

class MainScreen extends StatefulWidget {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  const MainScreen({super.key, required this.flutterLocalNotificationsPlugin});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const StatisticsScreen(),
      ChallengesScreen(flutterLocalNotificationsPlugin: widget.flutterLocalNotificationsPlugin),
      const SettingsScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, box, child) {
        final language = box.get('language', defaultValue: 'Русский') as String;
        final localizations = AppLocalizations(language);
        return Scaffold(
          body: _screens[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home),
                label: localizations.getString('home'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.bar_chart),
                label: localizations.getString('statistics'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.star),
                label: localizations.getString('challenges'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings),
                label: localizations.getString('settings'),
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.indigo,
            unselectedItemColor: Colors.grey,
            backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
            onTap: _onItemTapped,
          ),
        );
      },
    );
  }
}