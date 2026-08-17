import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../models/deck.dart';
import 'lesson_session_screen.dart';
import 'settings_screen.dart';

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
    final result = <DeckProgress>[];
    for (var i = 0; i < decks.length; i++) {
      final isCompleted = completed.contains(decks[i].id);
      final isUnlocked = i == 0 || completed.contains(decks[i - 1].id);
      result.add(DeckProgress(
          deck: decks[i], completed: isCompleted, unlocked: isUnlocked));
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
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('lessons')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: AppBackground(
        child: _decks == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    for (final dp in _decks!)
                      _DeckTile(
                          deckProgress: dp,
                          settings: settings,
                          onTap: _openDeck),
                  ],
                ),
              ),
      ),
    );
  }
}

class _DeckTile extends StatelessWidget {
  final DeckProgress deckProgress;
  final AppSettings settings;
  final void Function(Deck) onTap;

  const _DeckTile(
      {required this.deckProgress,
      required this.settings,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final deck = deckProgress.deck;
    final color = deckProgress.completed
        ? Colors.green
        : deckProgress.unlocked
            ? Theme.of(context).colorScheme.primary
            : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        child: ListTile(
          enabled: deckProgress.unlocked,
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(
              deckProgress.completed
                  ? Icons.check_circle
                  : deckProgress.unlocked
                      ? Icons.menu_book
                      : Icons.lock,
              color: color,
            ),
          ),
          title: Text(deck.title),
          subtitle: Text(
            'HSK${deck.hskLevel} · ${deck.wordCount} '
            '${deckProgress.completed ? "· ${settings.t('deckCompleted')}" : deckProgress.unlocked ? "" : "· ${settings.t('deckLocked')}"}',
          ),
          onTap: deckProgress.unlocked ? () => onTap(deck) : null,
        ),
      ),
    );
  }
}
