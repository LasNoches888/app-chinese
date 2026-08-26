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
import 'lesson_session_screen.dart';
import 'mascot_wardrobe_screen.dart';

const _brandStart = Color(0xFFFF7A59);
const _brandEnd = Color(0xFF6C5CE7);

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
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
    final knownIds = (await repos.srs.getKnownWordIds()).toSet();
    final stats = await repos.stats.getStats();
    final due = await repos.srs.getDueWordIds();

    final result = <DeckProgress>[];
    for (var i = 0; i < decks.length; i++) {
      final deckWords = await repos.words.getWordsForDeck(decks[i].id);
      final learned = deckWords.where((w) => knownIds.contains(w.id)).length;
      result.add(
        DeckProgress(
          deck: decks[i],
          completed: completed.contains(decks[i].id),
          unlocked: i == 0 || completed.contains(decks[i - 1].id),
          learnedWords: learned,
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _decks = result;
      _stats = stats;
      _dueCount = due.length;
    });
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

  Future<void> _openWardrobe() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MascotWardrobeScreen()));
    _load();
  }

  /// The deck the learner should open next: the first unlocked one that
  /// isn't finished, so the header's call to action is a single tap rather
  /// than "scan 21 rows and figure out where you left off".
  DeckProgress? get _nextDeck {
    final decks = _decks;
    if (decks == null) return null;
    for (final d in decks) {
      if (d.unlocked && !d.completed) return d;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final decks = _decks;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('lessons')),
        actions: const [AppBarActions()],
      ),
      body: AppBackground(
        child: decks == null
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
                      onMascotTap: _openWardrobe,
                    ),
                    const SizedBox(height: 20),
                    ..._buildGroupedDecks(decks, settings),
                  ],
                ),
              ),
      ),
    );
  }

  /// Splits the deck list under HSK level headings. With 20+ decks a flat
  /// list reads as an undifferentiated wall; the headings give it shape and
  /// make the jump from HSK1 to HSK2 legible as progress.
  List<Widget> _buildGroupedDecks(
    List<DeckProgress> decks,
    AppSettings settings,
  ) {
    final widgets = <Widget>[];
    int? lastLevel;
    for (final dp in decks) {
      if (dp.deck.hskLevel != lastLevel) {
        lastLevel = dp.deck.hskLevel;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 20, bottom: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _brandEnd.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'HSK $lastLevel',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _brandEnd,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Divider(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      widgets.add(
        _DeckCard(deckProgress: dp, settings: settings, onTap: _openDeck),
      );
    }
    return widgets;
  }
}

/// The "what should I do right now" card. Without it the app opens onto a
/// list of decks and leaves the learner to work out where they left off.
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
          colors: [_brandStart, _brandEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _brandEnd.withValues(alpha: 0.3),
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
                          color: _brandEnd,
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
                  foregroundColor: _brandEnd,
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

class _DeckCard extends StatelessWidget {
  final DeckProgress deckProgress;
  final AppSettings settings;
  final void Function(Deck) onTap;

  const _DeckCard({
    required this.deckProgress,
    required this.settings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deck = deckProgress.deck;
    final locked = !deckProgress.unlocked;
    final accent = deckProgress.completed
        ? const Color(0xFF23C58F)
        : locked
        ? theme.colorScheme.outline
        : _brandEnd;

    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: locked
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: locked ? null : () => onTap(deck),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      deckProgress.completed
                          ? Icons.check_rounded
                          : locked
                          ? Icons.lock_outline
                          : Icons.menu_book_rounded,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deck.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (locked)
                          Text(
                            settings.t('deckLocked'),
                            style: theme.textTheme.bodySmall,
                          )
                        else ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: deckProgress.fraction,
                              minHeight: 6,
                              backgroundColor: accent.withValues(alpha: 0.15),
                              valueColor: AlwaysStoppedAnimation(accent),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${deckProgress.learnedWords}/${deck.wordCount} '
                            '${settings.t('deckWordsLearned')}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!locked)
                    Icon(Icons.chevron_right, color: theme.colorScheme.outline),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
