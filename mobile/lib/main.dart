import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/app_settings.dart';
import 'app_repositories.dart';
import 'screens/chat_screen.dart';
import 'screens/lessons_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/review_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Shows the actual exception on-screen instead of a blank/grey screen —
  // makes it possible to screenshot and report exactly what broke, rather
  // than just "the screen doesn't open".
  ErrorWidget.builder = (details) => Material(
        color: Colors.red.shade50,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${details.exception}\n\n${details.stack}',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ),
      );

  final settings = AppSettings();
  await settings.load();
  final repos = await AppRepositories.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        Provider<AppRepositories>.value(value: repos),
      ],
      child: const AppChinese(),
    ),
  );
}

class AppChinese extends StatelessWidget {
  const AppChinese({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return MaterialApp(
      title: 'Uchi',
      themeMode: settings.themeMode,
      theme: ThemeData(colorSchemeSeed: Colors.red, brightness: Brightness.light, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: Colors.red, brightness: Brightness.dark, useMaterial3: true),
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
    LessonsScreen(),
    ReviewScreen(),
    ProgressScreen(),
    ChatScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.menu_book), label: settings.t('lessons')),
          NavigationDestination(icon: const Icon(Icons.refresh), label: settings.t('review')),
          NavigationDestination(icon: const Icon(Icons.bar_chart), label: settings.t('progress')),
          NavigationDestination(icon: const Icon(Icons.chat_bubble), label: settings.t('chat')),
        ],
      ),
    );
  }
}
