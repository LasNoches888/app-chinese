import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../models/reading_passage.dart';
import 'reading_passage_screen.dart';

class _RankedPassage {
  final ReadingPassage passage;
  final double coverage;

  const _RankedPassage(this.passage, this.coverage);
}

/// Lists reading passages ranked by how much of their vocabulary the
/// learner already knows — a lightweight, fully offline stand-in for "i+1"
/// personalization: rather than generating text tailored to the learner
/// (which would need a live LLM call), it ranks a small hand-written pool
/// so what's shown first is whatever's closest to their current level.
class ReadingListScreen extends StatefulWidget {
  const ReadingListScreen({super.key});

  @override
  State<ReadingListScreen> createState() => _ReadingListScreenState();
}

class _ReadingListScreenState extends State<ReadingListScreen> {
  List<_RankedPassage>? _ranked;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ranked == null) _load();
  }

  Future<void> _load() async {
    final repos = context.read<AppRepositories>();
    final allWords = await repos.words.getAllWords();
    final knownIds = (await repos.srs.getKnownWordIds()).toSet();
    final passages = repos.reading.all;

    final ranked = passages.map((p) {
      final matched = allWords.where((w) => p.text.contains(w.hanzi));
      final matchedList = matched.toList();
      final coverage = matchedList.isEmpty
          ? 0.0
          : matchedList.where((w) => knownIds.contains(w.id)).length /
                matchedList.length;
      return _RankedPassage(p, coverage);
    }).toList()..sort((a, b) => b.coverage.compareTo(a.coverage));

    if (!mounted) return;
    setState(() => _ranked = ranked);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final ranked = _ranked;
    return Scaffold(
      appBar: AppBar(title: Text(settings.t('readingTitle'))),
      body: AppBackground(
        child: ranked == null
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: ranked.length,
                itemBuilder: (ctx, i) {
                  final item = ranked[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(
                        item.passage.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16),
                      ),
                      subtitle: Text(
                        '${(item.coverage * 100).round()}% ${settings.t('readingKnownWords')}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ReadingPassageScreen(passage: item.passage),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
