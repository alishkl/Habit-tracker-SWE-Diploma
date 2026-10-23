import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../localizations/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkTheme = false;
  bool _notifications = true;
  String _language = 'Русский';
  final List<String> _languages = ['Русский', 'English'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settingsBox = Hive.box('settings');
    setState(() {
      _darkTheme = settingsBox.get('darkTheme', defaultValue: false);
      _notifications = settingsBox.get('notifications', defaultValue: true);
      _language = settingsBox.get('language', defaultValue: 'Русский');
    });
  }

  void _saveSettings() {
    final settingsBox = Hive.box('settings');
    settingsBox.put('darkTheme', _darkTheme);
    settingsBox.put('notifications', _notifications);
    settingsBox.put('language', _language);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, box, child) {
        final language = box.get('language', defaultValue: 'Русский') as String;
        final localizations = AppLocalizations(language);
        return Scaffold(
          appBar: AppBar(
            title: Text(
              localizations.getString('settingsTitle'),
              style: const TextStyle(fontFamily: 'Montserrat'),
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
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _darkTheme ? (Colors.grey[850] ?? Colors.black) : Colors.indigo.withOpacity(0.1),
                  _darkTheme ? Colors.black : Colors.white,
                ],
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text(
                  localizations.getString('generalSettings'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                SwitchListTile(
                  title: Text(
                    localizations.getString('darkTheme'),
                    style: const TextStyle(fontFamily: 'Montserrat', color: Colors.indigo),
                  ),
                  value: _darkTheme,
                  onChanged: (value) {
                    setState(() {
                      _darkTheme = value;
                      _saveSettings();
                    });
                  },
                  secondary: const Icon(Icons.brightness_6, color: Colors.indigo),
                ),
                ListTile(
                  title: Text(
                    localizations.getString('language'),
                    style: const TextStyle(fontFamily: 'Montserrat', color: Colors.indigo),
                  ),
                  subtitle: Text(
                    _language,
                    style: const TextStyle(fontFamily: 'Montserrat', color: Colors.indigo),
                  ),
                  trailing: const Icon(Icons.language, color: Colors.indigo),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          localizations.getString('selectLanguage'),
                          style: const TextStyle(fontFamily: 'Montserrat', color: Color.fromARGB(255, 0, 0, 0)),
                        ),
                        content: DropdownButton<String>(
                          value: _language,
                          items: _languages.map((lang) => DropdownMenuItem(value: lang, child: Text(lang))).toList(),
                          onChanged: (value) {
                            setState(() {
                              _language = value!;
                              _saveSettings();
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    );
                  },
                ),
                const Divider(color: Colors.grey),
                Text(
                  localizations.getString('notifications'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                SwitchListTile(
                  title: Text(
                    localizations.getString('enableNotifications'),
                    style: const TextStyle(fontFamily: 'Montserrat', color: Colors.indigo),
                  ),
                  value: _notifications,
                  onChanged: (value) {
                    setState(() {
                      _notifications = value;
                      _saveSettings();
                    });
                  },
                  secondary: const Icon(Icons.notifications, color: Colors.indigo),
                ),
                const Divider(color: Colors.grey),
                Text(
                  localizations.getString('data'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                ListTile(
                  title: Text(
                    localizations.getString('exportData'),
                    style: const TextStyle(fontFamily: 'Montserrat', color: Colors.indigo),
                  ),
                  leading: const Icon(Icons.download, color: Colors.indigo),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(localizations.getString('exportingData'))),
                    );
                  },
                ),
                ListTile(
                  title: Text(
                    localizations.getString('clearData'),
                    style: const TextStyle(fontFamily: 'Montserrat', color: Colors.indigo),
                  ),
                  leading: const Icon(Icons.delete, color: Colors.red),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          localizations.getString('confirm'),
                          style: const TextStyle(fontFamily: 'Montserrat', color: Colors.black),
                        ),
                        content: Text(
                          localizations.getString('areYouSureClearData'),
                          style: const TextStyle(fontFamily: 'Montserrat', color: Colors.black),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              localizations.getString('cancel'),
                              style: const TextStyle(fontFamily: 'Montserrat', color: Colors.black),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(localizations.getString('dataCleared'))),
                              );
                            },
                            child: Text(
                              localizations.getString('clear'),
                              style: const TextStyle(fontFamily: 'Montserrat', color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(color: Colors.grey),
                ListTile(
                  title: Text(
                    localizations.getString('appVersion'),
                    style: const TextStyle(fontFamily: 'Montserrat', color: Colors.indigo),
                  ),
                  leading: const Icon(Icons.info, color: Colors.indigo),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}