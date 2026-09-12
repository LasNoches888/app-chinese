import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../components/app_bar_actions.dart';
import '../components/mascot_widget.dart';
import '../models/deck.dart';
import '../models/user_stats.dart';
import '../services/mascot_service.dart';
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
  int _dueCount = 0;

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
    final due = await repos.srs.getDueWordIds();

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
      _dueCount = due.length;
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
                    _TodayCard(
                      stats: _stats,
                      dueCount: _dueCount,
                      settings: settings,
                      nextDeck: _nextDeck,
                      onContinue: _openDeck,
                      onMascotTap: () =>
                          _push(const MascotWardrobeScreen()),
                    ),
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

/// The "what should I do right now" card. Without it the app would open
/// onto a grid of shortcuts and leave the learner to work out where they
/// left off.
class _TodayCard extends StatelessWidget {
  final UserStats? stats;
  final int dueCount;
  final AppSettings settings;
  final DeckProgress? nextDeck;
  final void Function(Deck) onContinue;
  final VoidCallback onMascotTap;

  const _TodayCard({
    required this.stats,
    required this.dueCount,
    required this.settings,
    required this.nextDeck,
    required this.onContinue,
    required this.onMascotTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final goalFraction = s == null || s.dailyGoalXp == 0
        ? 0.0
        : (s.xpToday / s.dailyGoalXp).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [AppColors.orange, AppColors.purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Asleep if the streak has gone cold for a couple of days,
              // otherwise wearing whatever outfit is equipped — tapping it
              // opens the wardrobe to pick a companion and dress it up.
              GestureDetector(
                onTap: onMascotTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    MascotWidget(
                      asset: s == null
                          ? 'assets/mascot/panda_02.png'
                          : MascotService.homeAsset(s),
                      size: 64,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.checkroom,
                          size: 14,
                          color: AppColors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.t('todayTitle'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Pill(icon: '🔥', label: '${s?.currentStreak ?? 0}'),
                        const SizedBox(width: 8),
                        _Pill(icon: '⭐', label: '${s?.xpToday ?? 0} XP'),
                        if ((s?.streakFreezes ?? 0) > 0) ...[
                          const SizedBox(width: 8),
                          _Pill(icon: '🧊', label: '${s!.streakFreezes}'),
                        ],
                        if (dueCount > 0) ...[
                          const SizedBox(width: 8),
                          _Pill(icon: '🔄', label: '$dueCount'),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: goalFraction,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${settings.t('dailyGoal')}: ${s?.xpToday ?? 0}/${s?.dailyGoalXp ?? 0} XP',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12,
            ),
          ),
          if (nextDeck != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => onContinue(nextDeck!.deck),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  '${settings.t('continueLearning')} · ${nextDeck!.deck.title}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String icon;
  final String label;

  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$icon $label',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
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
        color: AppColors.purple,
        label: settings.t('lessons'),
        onTap: onLessons,
      ),
      (
        icon: Icons.refresh_rounded,
        color: AppColors.blue,
        label: settings.t('review'),
        onTap: onReview,
      ),
      (
        icon: Icons.auto_awesome_rounded,
        color: AppColors.orange,
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
        color: AppColors.greenDark,
        label: settings.t('chat'),
        onTap: onChat,
      ),
      (
        icon: Icons.checkroom_rounded,
        color: AppColors.amber,
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
