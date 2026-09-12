import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../components/app_bar_actions.dart';
import '../models/deck.dart';
import '../models/user_stats.dart';
import '../services/mascot_service.dart';
import '../services/xp_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'dictionary_screen.dart';
import 'lesson_session_screen.dart';
import 'lessons_screen.dart';
import 'mascot_wardrobe_screen.dart';
import 'practice_hub_screen.dart';
import 'review_screen.dart';

/// The app's dashboard tab: today's progress card plus quick shortcuts to
/// every other part of the app that isn't a bottom-nav tab of its own.
///
/// Split out of what used to be `LessonsScreen`'s header (the old
/// `_TodayCard`) so the deck list can be its own screen reached from here,
/// like everything else, instead of being what the bottom nav opened onto
/// by default.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DeckProgress>? _decks;
  UserStats? _stats;
  bool _continueDismissed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final repos = context.read<AppRepositories>();
    final decks = await repos.words.getDecks();
    final completed = await repos.srs.getCompletedLessonIds();
    final stats = await repos.stats.getStats();

    final result = <DeckProgress>[
      for (var i = 0; i < decks.length; i++)
        DeckProgress(
          deck: decks[i],
          completed: completed.contains(decks[i].id),
          unlocked: i == 0 || completed.contains(decks[i - 1].id),
        ),
    ];
    if (!mounted) return;
    setState(() {
      _decks = result;
      _stats = stats;
    });
  }

  /// The deck the learner should open next: the first unlocked one that
  /// isn't finished, so the card's call to action is a single tap rather
  /// than "open the deck list and figure out where you left off".
  DeckProgress? get _nextDeck {
    final decks = _decks;
    if (decks == null) return null;
    for (final d in decks) {
      if (d.unlocked && !d.completed) return d;
    }
    return null;
  }

  Future<void> _openDeck(Deck deck) async {
    final repos = context.read<AppRepositories>();
    final words = await repos.words.getWordsForDeck(deck.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonSessionScreen(
          wordIds: words.map((w) => w.id).toList(),
          title: deck.title,
          deckIdToComplete: deck.id,
        ),
      ),
    );
    _load();
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('home')),
        actions: const [AppBarActions()],
      ),
      body: AppBackground(
        child: _decks == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _GreetingHeader(
                      stats: _stats,
                      settings: settings,
                      onMascotTap: () =>
                          _push(const MascotWardrobeScreen()),
                    ),
                    const SizedBox(height: 16),
                    _LevelCard(stats: _stats, settings: settings),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatBadge(
                            icon: '🔥',
                            iconBackground: AppColors.orange,
                            label: settings.t('streakShort'),
                            value: '${_stats?.currentStreak ?? 0}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatBadge(
                            icon: '🎯',
                            iconBackground: AppColors.greenDark,
                            label: settings.t('dailyGoal'),
                            value:
                                '${_stats?.xpToday ?? 0}/${_stats?.dailyGoalXp ?? 0}',
                          ),
                        ),
                      ],
                    ),
                    if (!_continueDismissed && _nextDeck != null) ...[
                      const SizedBox(height: 12),
                      _ContinueCard(
                        deck: _nextDeck!.deck,
                        settings: settings,
                        onContinue: () => _openDeck(_nextDeck!.deck),
                        onDismiss: () =>
                            setState(() => _continueDismissed = true),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _ShortcutGrid(
                      settings: settings,
                      onLessons: () => _push(const LessonsScreen()),
                      onReview: () => _push(const ReviewScreen()),
                      onPractice: () => _push(const PracticeHubScreen()),
                      onDictionary: () => _push(const DictionaryScreen()),
                      onChat: () => _push(const ChatScreen()),
                      onWardrobe: () => _push(const MascotWardrobeScreen()),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// "Привет!" + a tap-to-dress mascot avatar. Plain text on the page
/// background rather than a card — the mockup treats the greeting as a
/// page title, not a content block.
class _GreetingHeader extends StatelessWidget {
  final UserStats? stats;
  final AppSettings settings;
  final VoidCallback onMascotTap;

  const _GreetingHeader({
    required this.stats,
    required this.settings,
    required this.onMascotTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = stats;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings.t('homeGreeting'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                settings.t('homeGreetingSubtitle'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Asleep if the streak has gone cold for a couple of days,
        // otherwise wearing whatever outfit is equipped — tapping it opens
        // the wardrobe to pick a companion and dress it up.
        GestureDetector(
          onTap: onMascotTap,
          child: ClipOval(
            child: SizedBox(
              width: 52,
              height: 52,
              child: Image.asset(
                s == null
                    ? 'assets/mascot/panda_02.png'
                    : MascotService.homeAsset(s),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// White card wrapper every dashboard block shares — the mockup's cards
/// are plain white/surface with a soft shadow, no colored fills or
/// gradients of their own (those live only on the small icon badges).
class _DashboardCard extends StatelessWidget {
  final Widget child;
  const _DashboardCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Level badge + a progress bar for XP *within* the current level (e.g.
/// "560/1000 XP") — distinct from the daily-goal number shown in
/// [_StatBadge] below it.
class _LevelCard extends StatelessWidget {
  final UserStats? stats;
  final AppSettings settings;

  const _LevelCard({required this.stats, required this.settings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalXp = stats?.totalXp ?? 0;
    final level = XpService.levelForXp(totalXp);
    final floor = XpService.thresholdForLevel(level);
    final ceiling = XpService.thresholdForLevel(level + 1);
    final span = ceiling - floor;
    final fraction = span == 0 ? 0.0 : ((totalXp - floor) / span).clamp(0.0, 1.0);

    return _DashboardCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.green,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${settings.t('level')} $level',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 8,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.green,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${totalXp - floor}/$span XP',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the two side-by-side stat cards (streak, daily goal) — an emoji
/// badge on a tinted circle, a small label, and the number itself in bold.
class _StatBadge extends StatelessWidget {
  final String icon;
  final Color iconBackground;
  final String label;
  final String value;

  const _StatBadge({
    required this.icon,
    required this.iconBackground,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _DashboardCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                Text(
                  value,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Продолжить обучение" card: a dismissible nudge naming the next unlocked
/// deck, with a full-width primary button into it.
class _ContinueCard extends StatelessWidget {
  final Deck deck;
  final AppSettings settings;
  final VoidCallback onContinue;
  final VoidCallback onDismiss;

  const _ContinueCard({
    required this.deck,
    required this.settings,
    required this.onContinue,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  settings.t('continueLearningTitle'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deck.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'HSK ${deck.hskLevel} · ${deck.wordCount} '
                        '${settings.t('deckWordsLearned').split(' ').first}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(settings.t('continueLearning')),
            ),
          ),
        ],
      ),
    );
  }
}

/// The mockup's row of colored icon tiles — one per part of the app that
/// isn't reachable from the bottom nav. The mockup itself shows four
/// (Уроки/Словарь/Чат/Гардероб); Повторить and Практика are added here
/// rather than dropped, since both were live bottom-nav tabs before this
/// screen existed.
class _ShortcutGrid extends StatelessWidget {
  final AppSettings settings;
  final VoidCallback onLessons;
  final VoidCallback onReview;
  final VoidCallback onPractice;
  final VoidCallback onDictionary;
  final VoidCallback onChat;
  final VoidCallback onWardrobe;

  const _ShortcutGrid({
    required this.settings,
    required this.onLessons,
    required this.onReview,
    required this.onPractice,
    required this.onDictionary,
    required this.onChat,
    required this.onWardrobe,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (
        icon: Icons.menu_book_rounded,
        color: AppColors.blue,
        label: settings.t('lessons'),
        onTap: onLessons,
      ),
      (
        icon: Icons.refresh_rounded,
        color: AppColors.purple,
        label: settings.t('review'),
        onTap: onReview,
      ),
      (
        icon: Icons.auto_awesome_rounded,
        color: AppColors.greenDark,
        label: settings.t('practiceHub'),
        onTap: onPractice,
      ),
      (
        icon: Icons.menu_book_outlined,
        color: AppColors.green,
        label: settings.t('dictionaryTitle'),
        onTap: onDictionary,
      ),
      (
        icon: Icons.chat_bubble_rounded,
        color: AppColors.blue,
        label: settings.t('chat'),
        onTap: onChat,
      ),
      (
        icon: Icons.checkroom_rounded,
        color: AppColors.orange,
        label: settings.t('mascotWardrobeTitle'),
        onTap: onWardrobe,
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.92,
      children: [for (final t in tiles) _ShortcutTile(spec: t)],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final ({
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  })
  spec;

  const _ShortcutTile({required this.spec});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: spec.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: spec.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(spec.icon, color: spec.color),
              ),
              const SizedBox(height: 8),
              Text(
                spec.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
