import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../models/word.dart';

/// One-off "already know this?" pass over a random sample of the word
/// bank. Marking a word known fast-forwards its SRS state (via
/// [SrsRepository.markKnownFromPlacement]) so lessons stop re-teaching
/// vocabulary the learner already had — useful for someone who isn't
/// starting from absolute zero.
class PlacementTestScreen extends StatefulWidget {
  const PlacementTestScreen({super.key});

  @override
  State<PlacementTestScreen> createState() => _PlacementTestScreenState();
}

class _PlacementTestScreenState extends State<PlacementTestScreen> {
  static const _sampleSize = 20;

  List<Word>? _words;
  int _index = 0;
  int _markedKnown = 0;
  bool _revealed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_words == null) _load();
  }

  Future<void> _load() async {
    final all = await context.read<AppRepositories>().words.getAllWords();
    all.shuffle(Random());
    if (!mounted) return;
    setState(() => _words = all.take(_sampleSize).toList());
  }

  Future<void> _answer(bool knowsIt) async {
    final word = _words![_index];
    if (knowsIt) {
      await context.read<AppRepositories>().srs.markKnownFromPlacement(word.id);
      _markedKnown++;
    }
    if (!mounted) return;
    if (_index + 1 >= _words!.length) {
      await _finish();
    } else {
      setState(() {
        _index++;
        _revealed = false;
      });
    }
  }

  Future<void> _finish() async {
    final settings = context.read<AppSettings>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(settings.t('placementDoneTitle')),
        content: Text(
          settings
              .t('placementDoneBody')
              .replaceFirst('{count}', '$_markedKnown'),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(settings.t('continueLabel')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final words = _words;
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('placementTitle')),
        actions: [
          if (words != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: Text('${_index + 1}/${words.length}')),
            ),
        ],
      ),
      body: AppBackground(
        child: words == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        settings.t('placementPrompt'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _revealed
                            ? null
                            : () => setState(() => _revealed = true),
                        child: Card(
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 40,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  words[_index].hanzi,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.displaySmall,
                                ),
                                if (_revealed) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    words[_index].pinyin,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    words[_index].translationRu,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                ] else
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(settings.t('tapToReveal')),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (_revealed)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.grey,
                              ),
                              onPressed: () => _answer(false),
                              child: Text(settings.t('placementDontKnow')),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: () => _answer(true),
                              child: Text(settings.t('placementKnow')),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
