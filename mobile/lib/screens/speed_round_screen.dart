import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../models/word.dart';

/// 60-second arcade quiz: as many translations as you can pick correctly
/// before time runs out, independent of hearts/SRS — a fast, low-stakes
/// mode that scores against your own best rather than gating on lesson
/// progress the way the core loop does.
class SpeedRoundScreen extends StatefulWidget {
  const SpeedRoundScreen({super.key});

  @override
  State<SpeedRoundScreen> createState() => _SpeedRoundScreenState();
}

class _SpeedRoundScreenState extends State<SpeedRoundScreen> {
  static const _roundSeconds = 60;

  List<Word>? _allWords;
  Word? _prompt;
  List<Word> _options = const [];
  int _score = 0;
  int _secondsLeft = _roundSeconds;
  Timer? _timer;
  bool _finished = false;
  bool _answering = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_allWords == null) _load();
  }

  Future<void> _load() async {
    final all = await context.read<AppRepositories>().words.getAllWords();
    if (!mounted) return;
    setState(() => _allWords = all);
    _nextQuestion();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    if (_secondsLeft <= 1) {
      _timer?.cancel();
      setState(() {
        _secondsLeft = 0;
        _finished = true;
      });
      _finish();
      return;
    }
    setState(() => _secondsLeft -= 1);
  }

  void _nextQuestion() {
    final all = _allWords!;
    final prompt = all[Random().nextInt(all.length)];
    final distractors = List<Word>.from(all)
      ..removeWhere((w) => w.id == prompt.id)
      ..shuffle();
    final options = [prompt, ...distractors.take(3)]..shuffle();
    setState(() {
      _prompt = prompt;
      _options = options;
    });
  }

  Future<void> _choose(Word option) async {
    if (_answering || _finished) return;
    _answering = true;
    if (option.id == _prompt!.id) _score += 1;
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 150));
    _answering = false;
    if (!mounted || _finished) return;
    _nextQuestion();
  }

  Future<void> _finish() async {
    final settings = context.read<AppSettings>();
    final xp = _score * 2;
    if (xp > 0) {
      await context.read<AppRepositories>().stats.addXpAndRecordActivity(xp);
    }
    await settings.reportSpeedRoundScore(_score);
    if (!mounted) return;
    final isNewBest = _score >= settings.speedRoundBest && _score > 0;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(settings.t('speedRoundDone')),
        content: Text(
          isNewBest
              ? '${settings.t('speedRoundScore')}: $_score\n+$xp XP\n${settings.t('speedRoundNewBest')}'
              : '${settings.t('speedRoundScore')}: $_score\n+$xp XP',
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
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final prompt = _prompt;
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('speedRoundTitle')),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                '⏱ $_secondsLeft',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: _secondsLeft <= 10 ? Colors.red : null,
                ),
              ),
            ),
          ),
        ],
      ),
      body: AppBackground(
        child: prompt == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        '${settings.t('speedRoundScore')}: $_score',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text(
                        prompt.hanzi,
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        prompt.pinyin,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.grey),
                      ),
                      const Spacer(),
                      ..._options.map(
                        (o) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              onPressed: () => _choose(o),
                              child: Text(o.translationRu),
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
