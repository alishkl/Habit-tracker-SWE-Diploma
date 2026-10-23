import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'main_screen.dart';
import '../localizations/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  const OnboardingScreen({super.key, required this.flutterLocalNotificationsPlugin});

  @override
  OnboardingScreenState createState() => OnboardingScreenState();
}

class OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      titleKey: 'onboardingWelcome',
      descriptionKey: 'onboardingTrackHabits',
      image: 'assets/images/goals.jpg',
    ),
    OnboardingItem(
      titleKey: 'onboardingChooseHabits',
      descriptionKey: 'onboardingTemplates',
      image: 'assets/images/templ.png',
    ),
    OnboardingItem(
      titleKey: 'onboardingTrackProgress',
      descriptionKey: 'onboardingRealTime',
      image: 'assets/images/time.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkIfOnboardingCompleted();
  }

  void _checkIfOnboardingCompleted() async {
    var box = await Hive.openBox('settings');
    bool onboardingCompleted = box.get('onboardingCompleted', defaultValue: false);

    if (onboardingCompleted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainScreen(
            flutterLocalNotificationsPlugin: widget.flutterLocalNotificationsPlugin,
          ),
        ),
      );
    }
  }

  void _completeOnboarding() async {
    var box = await Hive.openBox('settings');
    await box.put('onboardingCompleted', true);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainScreen(
          flutterLocalNotificationsPlugin: widget.flutterLocalNotificationsPlugin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, box, child) {
        final language = box.get('language', defaultValue: 'Русский') as String;
        final localizations = AppLocalizations(language);
        return Scaffold(
          backgroundColor: Colors.white,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.indigo.withOpacity(0.1), Colors.white],
              ),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: screenHeight * 0.8,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _items.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      return OnboardingPage(
                        item: _items[index],
                        localizations: localizations,
                      );
                    },
                  ),
                ),
                SizedBox(
                  height: screenHeight * 0.2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _items.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: screenWidth * 0.7,
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
                            if (_currentPage == _items.length - 1) {
                              _completeOnboarding();
                            } else {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: Text(
                            _currentPage == _items.length - 1
                                ? localizations.getString('onboardingStart') ?? 'Начать'
                                : localizations.getString('next') ?? 'Далее',
                            style: const TextStyle(
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
              ],
            ),
          ),
        );
      },
    );
  }
}

class OnboardingItem {
  final String titleKey;
  final String descriptionKey;
  final String image;

  OnboardingItem({
    required this.titleKey,
    required this.descriptionKey,
    required this.image,
  });
}

class OnboardingPage extends StatelessWidget {
  final OnboardingItem item;
  final AppLocalizations localizations;

  const OnboardingPage({super.key, required this.item, required this.localizations});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  item.image,
                  fit: BoxFit.cover,
                  height: screenHeight * 0.4,
                  width: double.infinity,
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Flexible(
            flex: 2,
            child: Text(
              localizations.getString(item.titleKey) ?? item.titleKey,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Colors.indigo,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 15),
          Flexible(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                localizations.getString(item.descriptionKey) ?? item.descriptionKey,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, height: 1.5, color: Colors.grey.shade700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}