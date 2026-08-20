import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../models/achievement.dart';
import '../models/word.dart';

/// A single-player "race" against a steadily-advancing panda: the panda
/// ticks forward on a fixed clock regardless of what you do, and every
/// correct translation moves you forward one step — first to the finish
/// line wins. Doesn't need a server or another human to feel competitive,
/// since the panda's pace is exactly the thing you're racing against.
class RaceScreen extends StatefulWidget {
  const RaceScreen({super.key});

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen> {
  static const _target = 8;
  static const _opponentTick = Duration(milliseconds: 2600);

  List<Word>? _allWords;
  Word? _prompt;
  List<Word> _options = const [];
  int _playerProgress = 0;
  int _opponentProgress = 0;
  Timer? _opponentTimer;
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
    _opponentTimer = Timer.periodic(_opponentTick, (_) => _opponentStep());
  }

  void _opponentStep() {
    if (_finished) return;
    setState(() => _opponentProgress += 1);
    if (_opponentProgress >= _target) _finish(playerWon: false);
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
    final correct = option.id == _prompt!.id;
    if (correct) setState(() => _playerProgress += 1);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    _answering = false;
    if (!mounted || _finished) return;
    if (_playerProgress >= _target) {
      await _finish(playerWon: true);
      return;
    }
    _nextQuestion();
  }

  Future<void> _finish({required bool playerWon}) async {
    _opponentTimer?.cancel();
    setState(() => _finished = true);
    final settings = context.read<AppSettings>();
    final repos = context.read<AppRepositories>();
    // A modest reward either way — showing up and answering correctly
    // still counts even on a loss, same spirit as the incorrect-attempt XP
    // elsewhere in the app.
    final xp = playerWon ? 15 : _playerProgress;
    if (xp > 0) {
      await repos.stats.addXpAndRecordActivity(xp);
    }
    var newAchievements = const <String>[];
    if (playerWon) {
      final stats = await repos.stats.recordRaceWin();
      newAchievements = await repos.achievements.evaluateAndUnlock(stats);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          playerWon ? settings.t('raceWinTitle') : settings.t('raceLoseTitle'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('+$xp XP'),
            if (newAchievements.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                settings.t('newAchievement'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final code in newAchievements)
                    Chip(
                      avatar: Text(_iconFor(code)),
                      label: Text(settings.t(_titleKeyFor(code))),
                      backgroundColor: Colors.amber.shade600,
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                ],
              ),
            ],
          ],
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

  String _iconFor(String code) => kAchievementDefs
      .firstWhere((a) => a.code == code, orElse: () => kAchievementDefs.first)
      .icon;

  String _titleKeyFor(String code) => kAchievementDefs
      .firstWhere((a) => a.code == code, orElse: () => kAchievementDefs.first)
      .titleKey;

  @override
  void dispose() {
    _opponentTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final prompt = _prompt;
    return Scaffold(
      appBar: AppBar(title: Text(settings.t('raceTitle'))),
      body: AppBackground(
        child: prompt == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _RaceTrack(
                        label: settings.t('raceYou'),
                        emoji: '🧑',
                        progress: _playerProgress,
                        target: _target,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 10),
                      _RaceTrack(
                        label: settings.t('racePanda'),
                        emoji: '🐼',
                        progress: _opponentProgress,
                        target: _target,
                        color: Colors.orange,
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

class _RaceTrack extends StatelessWidget {
  final String label;
  final String emoji;
  final int progress;
  final int target;
  final Color color;

  const _RaceTrack({
    required this.label,
    required this.emoji,
    required this.progress,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (progress / target).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 14,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fraction,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
