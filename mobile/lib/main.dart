import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/app_settings.dart';
import 'app_repositories.dart';
import 'screens/chat_screen.dart';
import 'screens/lessons_screen.dart';
import 'screens/practice_hub_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/review_screen.dart';

const _brandSeed = Color(0xFF6C5CE7);

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

/// Softer overscroll everywhere (iOS-style bounce instead of the hard
/// Android glow stop), which is most of what makes list scrolling feel
/// smooth rather than abrupt.
class _SmoothScrollBehavior extends MaterialScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

class AppChinese extends StatelessWidget {
  const AppChinese({super.key});

  ThemeData _theme(Brightness brightness) {
    return ThemeData(
      colorSchemeSeed: _brandSeed,
      brightness: brightness,
      useMaterial3: true,
      // Material's zoom transition animates both the incoming and outgoing
      // route, so pushing Settings fades/scales in instead of snapping.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()},
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return MaterialApp(
      title: 'Uchi',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _SmoothScrollBehavior(),
      themeMode: settings.themeMode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
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
    PracticeHubScreen(),
    ProgressScreen(),
    ChatScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      // Cross-fades tabs with a slight upward drift instead of swapping
      // them instantly.
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.015),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey<int>(_index),
          child: _screens[_index],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: settings.t('lessons'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.refresh_outlined),
            selectedIcon: const Icon(Icons.refresh),
            label: settings.t('review'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: settings.t('practiceHub'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: settings.t('progress'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: settings.t('chat'),
          ),
        ],
      ),
    );
  }
}
