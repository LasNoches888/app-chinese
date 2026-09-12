import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../components/app_bar_actions.dart';
import '../models/deck.dart';
import '../theme/app_theme.dart';
import 'lesson_session_screen.dart';

/// The HSK deck list, grouped by level. Reached from HomeScreen's shortcut
/// grid — this used to also carry the "today" dashboard card at its top,
/// before that was split out into its own Home tab.
class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  List<DeckProgress>? _decks;

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
    setState(() => _decks = result);
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
                  children: _buildGroupedDecks(decks, settings),
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
                    color: AppColors.purple.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'HSK $lastLevel',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.purple,
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
        ? AppColors.green
        : locked
        ? theme.colorScheme.outline
        : AppColors.purple;

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
