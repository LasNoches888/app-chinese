import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'api/app_settings.dart';
import 'app_repositories.dart';
import 'screens/lessons_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/plans_screen.dart';
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

  // sqflite talks to Android/iOS's platform channel by default and has
  // no desktop implementation — Windows (and Linux, same story) needs
  // the FFI-backed factory pointed at the bundled sqlite3.dll instead,
  // or every database call throws "databaseFactory not initialized"
  // before a single screen renders.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

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
      // Every screen was built assuming a phone-width viewport — on a
      // desktop window that's suddenly 1280px+ wide, the same layouts
      // stretch edge to edge and run their trailing content (chips,
      // badges, buttons) straight off the visible window instead of
      // wrapping or centering. A generous-but-bounded ceiling here keeps
      // every screen readable (long text lines, wide cards) without
      // needing a max-width constraint added to two dozen screens
      // individually; HomeShell below adds its own desktop navigation
      // rail on top of this for the five main tabs specifically.
      builder: (context, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: child,
        ),
      ),
      home: const _RootScreen(),
    );
  }
}

/// Gates the first launch behind [OnboardingScreen] — everyone after that
/// (the `onboarded` flag persists) goes straight to [HomeShell] like
/// before. A separate widget rather than a condition inside HomeShell so
/// completing onboarding is a real navigation transition, not a rebuild
/// that just swaps what a StatefulWidget's build() returns underneath the
/// same route.
class _RootScreen extends StatefulWidget {
  const _RootScreen();

  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  late bool _onboarded;

  @override
  void initState() {
    super.initState();
    _onboarded = context.read<AppSettings>().onboarded;
  }

  @override
  Widget build(BuildContext context) {
    if (_onboarded) return const HomeShell();
    return OnboardingScreen(onDone: () => setState(() => _onboarded = true));
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
    PlansScreen(),
  ];

  /// Below this, a NavigationRail would leave less room for content than
  /// a phone screen already gets — the bottom bar stays the right call
  /// all the way up to a small desktop window.
  static const _railBreakpoint = 700.0;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final destinations = [
      (
        icon: Icons.menu_book_outlined,
        selected: Icons.menu_book,
        label: settings.t('lessons'),
      ),
      (
        icon: Icons.refresh_outlined,
        selected: Icons.refresh,
        label: settings.t('review'),
      ),
      (
        icon: Icons.auto_awesome_outlined,
        selected: Icons.auto_awesome,
        label: settings.t('practiceHub'),
      ),
      (
        icon: Icons.bar_chart_outlined,
        selected: Icons.bar_chart,
        label: settings.t('progress'),
      ),
      (
        icon: Icons.map_outlined,
        selected: Icons.map,
        label: settings.t('plansTitle'),
      ),
    ];

    final body = AnimatedSwitcher(
      // Cross-fades tabs with a slight upward drift instead of swapping
      // them instantly.
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
      child: KeyedSubtree(key: ValueKey<int>(_index), child: _screens[_index]),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _railBreakpoint) {
          return Scaffold(
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: d.label,
                  ),
              ],
            ),
          );
        }

        // Wide enough for a desktop window to feel like one — a
        // permanent rail reads as native there, where a bottom bar
        // would just be a mobile habit with room to spare either side.
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                extended: constraints.maxWidth >= 860,
                labelType: constraints.maxWidth >= 860
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selected),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}
