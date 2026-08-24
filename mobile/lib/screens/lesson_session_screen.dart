import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/exercise_widgets.dart';
import '../components/hearts_row.dart';
import '../models/exercise_question.dart';
import '../models/user_stats.dart';
import '../services/exercise_generator.dart';
import '../services/hearts_service.dart';
import '../services/xp_service.dart';
import 'results_screen.dart';

/// Runs a queue of exercises (a lesson, or a review session over due SRS
/// words) end to end: question generation, grading against the local DB,
/// hearts/XP bookkeeping, and handing off to ResultsScreen when done.
class LessonSessionScreen extends StatefulWidget {
  final List<String> wordIds;
  final String title;
  final String? deckIdToComplete;
  final bool isReview;

  /// Runs before achievements are evaluated, so a counter it bumps (e.g.
  /// "daily challenges completed") is reflected in *this* session's unlock
  /// check rather than lagging a session behind.
  final Future<void> Function()? onFinished;

  const LessonSessionScreen({
    super.key,
    required this.wordIds,
    required this.title,
    this.deckIdToComplete,
    this.isReview = false,
    this.onFinished,
  });

  @override
  State<LessonSessionScreen> createState() => _LessonSessionScreenState();
}

class _LessonSessionScreenState extends State<LessonSessionScreen> {
  List<ExerciseQuestion>? _questions;
  int _index = 0;
  int _hearts = 5;

  /// Kept alongside [_hearts] purely so the out-of-hearts screen can show
  /// a live countdown — that needs heartsUpdatedAt, not just the count.
  UserStats? _stats;
  int _xpEarned = 0;
  final Set<String> _mistakeIds = {};
  bool _outOfHearts = false;
  bool _loading = true;
  bool _answering = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repos = context.read<AppRepositories>();
    final lessonWords = await repos.words.getWordsByIds(widget.wordIds);
    final allWords = await repos.words.getAllWords();
    final stats = await repos.stats.getStats();
    final questions = ExerciseGenerator.build(
      lessonWords: lessonWords,
      allWords: allWords,
      availableStrokeChars: repos.strokeData.availableCharacters,
    );
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _hearts = stats.heartsCurrent;
      _stats = stats;
      _outOfHearts = stats.heartsCurrent <= 0 && questions.isNotEmpty;
      _loading = false;
    });
  }

  Future<void> _handleAnswer(bool correct) async {
    // Exercise widgets already guard against double-submission themselves,
    // but this is the shared choke point for every type — guard here too
    // so a rapid double-tap can never double-write SRS/XP/hearts.
    if (_answering) return;
    _answering = true;
    try {
      final repos = context.read<AppRepositories>();
      final question = _questions![_index];
      final earned = XpService.xpForAnswer(correct);

      await repos.srs.recordReview(
        wordId: question.wordId,
        wasCorrect: correct,
        exerciseType: question.type.name,
      );
      await repos.stats.addXpAndRecordActivity(earned);

      var hearts = _hearts;
      UserStats? statsAfterHeart;
      if (!correct) {
        statsAfterHeart = await repos.stats.loseHeart();
        hearts = statsAfterHeart.heartsCurrent;
        _mistakeIds.add(question.wordId);
      }

      if (!mounted) return;
      setState(() {
        _xpEarned += earned;
        _hearts = hearts;
        if (statsAfterHeart != null) _stats = statsAfterHeart;
      });

      final isLastQuestion = _index + 1 >= _questions!.length;
      if (isLastQuestion) {
        // Every question got answered — always show results, even if the
        // last answer also happened to drain the last heart. Running out
        // of hearts only needs to block *further* questions, and there
        // are none left.
        await _finish();
      } else if (hearts <= 0) {
        setState(() => _outOfHearts = true);
      } else {
        setState(() => _index += 1);
      }
    } finally {
      _answering = false;
    }
  }

  Future<void> _finish() async {
    final repos = context.read<AppRepositories>();
    final perfect = _mistakeIds.isEmpty;

    if (widget.deckIdToComplete != null) {
      await repos.srs.markLessonCompleted(widget.deckIdToComplete!);
    }
    if (perfect) {
      await repos.stats.recordPerfectLesson();
    }
    if (widget.isReview) {
      // Documented reward for clearing your review queue: an instant full
      // heart refill, in addition to the passive time-based regen.
      await repos.stats.restoreHeartsFully();
    }

    await widget.onFinished?.call();
    final latestStats = await repos.stats.getStats();
    final newAchievements = await repos.achievements.evaluateAndUnlock(
      latestStats,
    );
    final mistakeWords = await repos.words.getWordsByIds(_mistakeIds.toList());

    if (!mounted) return;
    final settings = context.read<AppSettings>();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          result: LessonResult(
            xpEarned: _xpEarned,
            mistakes: mistakeWords,
            perfect: perfect,
            isReview: widget.isReview,
            newAchievements: newAchievements,
          ),
          settings: settings,
          onContinue: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_questions!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(child: Text(settings.t('noReviewDue'))),
      );
    }

    if (_outOfHearts) {
      return _OutOfHeartsView(settings: settings, stats: _stats);
    }

    final progress = _index / _questions!.length;
    final question = _questions![_index];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: HeartsRow(hearts: _hearts)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: progress, minHeight: 8),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  // The writing exercise's canvas only recognizes
                  // onPanUpdate/onPanEnd, which lose the gesture-arena
                  // race against a scrollable ancestor's own vertical drag
                  // recognizer for any top-to-bottom stroke — the most
                  // common stroke direction in Chinese characters. That
                  // reads as "drawing doesn't register" even though every
                  // other exercise type genuinely benefits from scrolling
                  // on short screens.
                  child: question.type == ExerciseType.writeHanzi
                      ? _buildExercise(question, settings)
                      : SingleChildScrollView(
                          child: _buildExercise(question, settings),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExercise(ExerciseQuestion question, AppSettings settings) {
    switch (question.type) {
      case ExerciseType.flip:
        return FlipExerciseWidget(
          key: ValueKey(question.id),
          question: question,
          settings: settings,
          onAnswer: _handleAnswer,
        );
      case ExerciseType.chooseTranslation:
      case ExerciseType.chooseHanzi:
        return ChoiceExerciseWidget(
          key: ValueKey(question.id),
          question: question,
          settings: settings,
          onAnswer: _handleAnswer,
        );
      case ExerciseType.buildSentence:
        return BuildSentenceExerciseWidget(
          key: ValueKey(question.id),
          question: question,
          settings: settings,
          onAnswer: _handleAnswer,
        );
      case ExerciseType.typePinyin:
        return TypePinyinExerciseWidget(
          key: ValueKey(question.id),
          question: question,
          settings: settings,
          onAnswer: _handleAnswer,
        );
      case ExerciseType.writeHanzi:
        final strokeJson = context
            .read<AppRepositories>()
            .strokeData
            .strokeOrderJson(question.hanzi!);
        return WriteHanziExerciseWidget(
          key: ValueKey(question.id),
          question: question,
          settings: settings,
          strokeOrderJson: strokeJson!,
          onAnswer: _handleAnswer,
        );
    }
  }
}

class _OutOfHeartsView extends StatefulWidget {
  final AppSettings settings;
  final UserStats? stats;

  const _OutOfHeartsView({required this.settings, required this.stats});

  @override
  State<_OutOfHeartsView> createState() => _OutOfHeartsViewState();
}

class _OutOfHeartsViewState extends State<_OutOfHeartsView> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // "Wait for hearts to refill" with no number attached is the kind of
    // dead end that just makes people close the app. HeartsService already
    // knew how long the wait was — nothing was showing it.
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final stats = widget.stats;
    final remaining = stats == null
        ? null
        : HeartsService.timeToNextHeart(
            hearts: stats.heartsCurrent,
            updatedAt: stats.heartsUpdatedAt,
          );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HeartsRow(hearts: 0, large: true),
                const SizedBox(height: 16),
                Text(
                  settings.t('outOfHearts'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  settings.t('outOfHeartsBody'),
                  textAlign: TextAlign.center,
                ),
                if (remaining != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite,
                          size: 18,
                          color: Color(0xFFFF4D6D),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${settings.t('nextHeartIn')} ${_format(remaining)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(settings.t('backToLessons')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
