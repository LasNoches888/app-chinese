import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../models/dialogue.dart';
import 'listening_screen.dart';

class _RankedDialogue {
  final Dialogue dialogue;
  final String deckTitle;
  final int hskLevel;
  final double coverage;

  const _RankedDialogue({
    required this.dialogue,
    required this.deckTitle,
    required this.hskLevel,
    required this.coverage,
  });
}

/// Lets the learner pick which dialogue to listen to instead of always
/// getting a random one — the same shape as ReadingListScreen, ranked by
/// how much of the dialogue's vocabulary they already know so the easiest
/// unheard material floats to the top.
///
/// The dialogue text itself is deliberately not shown here: this is the
/// entry point to a listening exercise, so previewing the transcript in
/// the list would give away exactly what the exercise hides.
class ListeningListScreen extends StatefulWidget {
  const ListeningListScreen({super.key});

  @override
  State<ListeningListScreen> createState() => _ListeningListScreenState();
}

class _ListeningListScreenState extends State<ListeningListScreen> {
  List<_RankedDialogue>? _ranked;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ranked == null) _load();
  }

  Future<void> _load() async {
    final repos = context.read<AppRepositories>();
    final allWords = await repos.words.getAllWords();
    final knownIds = (await repos.srs.getKnownWordIds()).toSet();
    final decks = await repos.words.getDecks();
    final deckByTopic = {for (final d in decks) d.topic: d};

    final ranked =
        repos.dialogues.all.map((d) {
          final text = d.fullText;
          final matched = allWords
              .where((w) => text.contains(w.hanzi))
              .toList();
          final coverage = matched.isEmpty
              ? 0.0
              : matched.where((w) => knownIds.contains(w.id)).length /
                    matched.length;
          final deck = deckByTopic[d.topic];
          return _RankedDialogue(
            dialogue: d,
            deckTitle: deck?.title ?? d.topic,
            hskLevel: deck?.hskLevel ?? 1,
            coverage: coverage,
          );
        }).toList()..sort((a, b) {
          final byCoverage = b.coverage.compareTo(a.coverage);
          return byCoverage != 0
              ? byCoverage
              : a.hskLevel.compareTo(b.hskLevel);
        });

    if (!mounted) return;
    setState(() => _ranked = ranked);
  }

  void _open(Dialogue? dialogue) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListeningScreen(dialogue: dialogue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final ranked = _ranked;
    return Scaffold(
      appBar: AppBar(title: Text(settings.t('listeningPickTitle'))),
      body: AppBackground(
        child: ranked == null
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: ranked.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: ListTile(
                        leading: const Text(
                          '🎲',
                          style: TextStyle(fontSize: 26),
                        ),
                        title: Text(
                          settings.t('listeningRandom'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(settings.t('listeningRandomDesc')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(null),
                      ),
                    );
                  }
                  final item = ranked[i - 1];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: Text(
                          'HSK${item.hskLevel}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        item.deckTitle,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${item.dialogue.lines.length} ${settings.t('listeningLines')} · '
                        '${(item.coverage * 100).round()}% ${settings.t('readingKnownWords')}',
                      ),
                      trailing: const Icon(Icons.play_arrow_rounded),
                      onTap: () => _open(item.dialogue),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
