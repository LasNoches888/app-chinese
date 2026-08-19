import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../data/tone_pairs.dart';
import '../services/speech_service.dart';

/// Minimal-pair tone drill: the device speaks one word from a same-syllable
/// set (妈/麻/马/骂...) and the learner picks which tone they heard. Kept
/// separate from the vocab SRS — this targets one specific, well-known
/// difficulty for Russian-speaking learners rather than any particular word.
class ToneTrainerScreen extends StatefulWidget {
  const ToneTrainerScreen({super.key});

  @override
  State<ToneTrainerScreen> createState() => _ToneTrainerScreenState();
}

class _ToneTrainerScreenState extends State<ToneTrainerScreen>
    with StopSpeechOnDispose {
  final _rng = Random();
  late TonePairSet _set;
  late ToneWord _target;
  ToneWord? _selected;
  int _correct = 0;
  int _asked = 0;
  static const _roundLength = 10;

  @override
  void initState() {
    super.initState();
    _nextRound();
  }

  void _nextRound() {
    _set = kTonePairSets[_rng.nextInt(kTonePairSets.length)];
    _target = _set.words[_rng.nextInt(_set.words.length)];
    _selected = null;
    setState(() {});
    // Autoplay so the learner hears the target immediately, without an
    // extra tap before they can even attempt the round.
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  void _play() => SpeechService.speak(_target.hanzi, rate: 0.4);

  Future<void> _select(ToneWord word) async {
    if (_selected != null) return;
    setState(() {
      _selected = word;
      _asked++;
      if (word.tone == _target.tone) _correct++;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    if (_asked >= _roundLength) {
      await _finish();
    } else {
      _nextRound();
    }
  }

  Future<void> _finish() async {
    final settings = context.read<AppSettings>();
    final xp = _correct * 2;
    if (xp > 0) {
      await context.read<AppRepositories>().stats.addXpAndRecordActivity(xp);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(settings.t('toneTrainerDone')),
        content: Text('$_correct / $_roundLength\n+$xp XP'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(settings.t('continueLabel')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      _correct = 0;
      _asked = 0;
    });
    _nextRound();
  }

  Color? _colorFor(ToneWord word) {
    if (_selected == null) return null;
    if (word.tone == _target.tone) return Colors.green.withValues(alpha: 0.25);
    if (word == _selected) return Colors.red.withValues(alpha: 0.25);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('toneTrainerTitle')),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text('$_asked/$_roundLength')),
          ),
        ],
      ),
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  settings.t('toneTrainerPrompt'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                IconButton.filled(
                  iconSize: 40,
                  padding: const EdgeInsets.all(20),
                  icon: const Icon(Icons.volume_up),
                  onPressed: _play,
                ),
                const SizedBox(height: 28),
                for (final word in _set.words)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _colorFor(word),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _select(word),
                        child: Text(
                          '${word.hanzi}  ${word.pinyin}  —  ${word.translationRu}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
