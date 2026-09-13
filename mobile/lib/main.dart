import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'api/app_settings.dart';
import 'app_repositories.dart';
import 'screens/chat_screen.dart';
import 'screens/dialects_map_screen.dart';
import 'screens/dictionary_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lessons_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/plans_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return MaterialApp(
      title: 'Uchi',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _SmoothScrollBehavior(),
      themeMode: settings.themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Every screen was built assuming a phone-width viewport — on a
      // desktop window that's suddenly 1280px+ wide, the same layouts
      // stretch edge to edge and run their trailing content (chips,
      // badges, buttons) straight off the visible window instead of
      // wrapping or centering. A generous-but-bounded ceiling here keeps
      // every screen readable (long text lines, wide cards) without
      // needing a max-width constraint added to two dozen screens
      // individually. 1280 rather than the old 900: HomeShell's desktop
      // sidebar plus a real dashboard grid needs more room than a
      // slightly-stretched phone layout did.
      builder: (context, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
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
  int _mobileIndex = 0;
  int _desktopIndex = 0;

  /// The phone bottom bar keeps exactly the tabs it already had — this
  /// pass is about giving desktop its own real layout, not about
  /// reshuffling a mobile nav that's already been tuned.
  static const _mobileScreens = [
    HomeScreen(),
    DialectsMapScreen(),
    PlansScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  /// Desktop gets Уроки/Словарь/Чат as sidebar destinations of their own
  /// instead of two taps deep through Home's shortcut grid — that grid
  /// is a phone-width compromise, not a design goal, and a sidebar has
  /// the room to just list everything. Планы sits next to Уроки because
  /// they're the two halves of the same thing: the deck list is the
  /// material, the plans are the route through it.
  static const _desktopScreens = [
    HomeScreen(),
    LessonsScreen(),
    PlansScreen(),
    DialectsMapScreen(),
    DictionaryScreen(),
    ChatScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  /// Below this, a sidebar would leave less room for content than a
  /// phone screen already gets — the bottom bar stays the right call
  /// all the way up to a small desktop window.
  static const _railBreakpoint = 700.0;

  Widget _animatedBody(Widget child, Object key) => AnimatedSwitcher(
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
    child: KeyedSubtree(key: ValueKey(key), child: child),
  );

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final mobileDestinations = [
      (
        icon: Icons.home_outlined,
        selected: Icons.home,
        label: settings.t('home'),
      ),
      (
        icon: Icons.location_on_outlined,
        selected: Icons.location_on,
        label: settings.t('dialects'),
      ),
      (
        icon: Icons.map_outlined,
        selected: Icons.map,
        label: settings.t('plansTitle'),
      ),
      (
        icon: Icons.bar_chart_outlined,
        selected: Icons.bar_chart,
        label: settings.t('progress'),
      ),
      (
        icon: Icons.person_outline,
        selected: Icons.person,
        label: settings.t('settings'),
      ),
    ];

    final desktopDestinations = [
      (
        icon: Icons.home_outlined,
        selected: Icons.home,
        label: settings.t('home'),
      ),
      (
        icon: Icons.menu_book_outlined,
        selected: Icons.menu_book,
        label: settings.t('lessons'),
      ),
      (
        icon: Icons.map_outlined,
        selected: Icons.map,
        label: settings.t('plansTitle'),
      ),
      (
        icon: Icons.location_on_outlined,
        selected: Icons.location_on,
        label: settings.t('dialects'),
      ),
      (
        icon: Icons.import_contacts_outlined,
        selected: Icons.import_contacts,
        label: settings.t('dictionaryTitle'),
      ),
      (
        icon: Icons.chat_bubble_outline,
        selected: Icons.chat_bubble,
        label: settings.t('chat'),
      ),
      (
        icon: Icons.bar_chart_outlined,
        selected: Icons.bar_chart,
        label: settings.t('progress'),
      ),
      (
        icon: Icons.person_outline,
        selected: Icons.person,
        label: settings.t('settings'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _railBreakpoint) {
          return Scaffold(
            body: _animatedBody(
              _mobileScreens[_mobileIndex],
              _mobileIndex,
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _mobileIndex,
              onDestinationSelected: (i) => setState(() => _mobileIndex = i),
              destinations: [
                for (final d in mobileDestinations)
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
        // permanent, labeled sidebar reads as native there, where a
        // bottom bar would just be a mobile habit with room to spare
        // either side.
        return Scaffold(
          body: Row(
            children: [
              _DesktopSidebar(
                key: const Key('desktopSidebar'),
                selectedIndex: _desktopIndex,
                destinations: desktopDestinations,
                onSelect: (i) => setState(() => _desktopIndex = i),
              ),
              Expanded(
                child: _animatedBody(
                  _desktopScreens[_desktopIndex],
                  _desktopIndex,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A fixed-width, always-labeled desktop nav — deliberately not Material's
/// [NavigationRail]: that widget's collapsed icon-only state and its
/// pill-less selection highlight read as a generic Flutter default, not
/// the brand. This matches the same sidebar built for the web app
/// (website/js/shell.js) so the two feel like one product.
class _DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final List<({IconData icon, IconData selected, String label})>
  destinations;
  final ValueChanged<int> onSelect;

  const _DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 240,
      decoration: BoxDecoration(
        // surfaceContainerLowest is the rail colour specifically: in the
        // night-mode panel the sidebar sits a shade *under* the canvas
        // rather than on a lighter card like the rest of the surfaces.
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Image.asset(
                        'assets/mascot/panda_02.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Uchi',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < destinations.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3,
                ),
                child: _SidebarItem(
                  spec: destinations[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelect(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final ({IconData icon, IconData selected, String label}) spec;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // The active pill is a solid wash from the palette rather than a
    // translucent blue: over the navy night canvas an alpha-blended blue
    // turns muddy, while the pinned pillDark keeps the same crispness the
    // light panel has.
    final activeInk = scheme.onPrimaryContainer;
    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                selected ? spec.selected : spec.icon,
                size: 20,
                color: selected ? activeInk : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  spec.label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? activeInk : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
