import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/app_settings.dart';
import 'screens/chat_screen.dart';
import 'screens/flashcards_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  await settings.load();
  runApp(
    ChangeNotifierProvider.value(
      value: settings,
      child: const AppChinese(),
    ),
  );
}

class AppChinese extends StatelessWidget {
  const AppChinese({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppChinese',
      theme: ThemeData(colorSchemeSeed: Colors.red, useMaterial3: true),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    FlashcardsScreen(),
    ChatScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.style), label: 'Flashcards'),
          NavigationDestination(icon: Icon(Icons.chat_bubble), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
