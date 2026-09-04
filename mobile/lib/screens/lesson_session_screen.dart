import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../api/app_strings.dart';
import '../app_repositories.dart';
import '../components/exercise_widgets.dart';
import '../components/mascot_companion.dart';
import '../data/mascot_jokes.dart';
import '../models/exercise_question.dart';
import '../services/exercise_generator.dart';
import '../services/mascot_service.dart';
import '../services/reward_service.dart';
import '../services/xp_service.dart';
import 'results_screen.dart';

/// Runs a queue of exercises (a lesson, or a review session over due SRS
/// words) end to end: question generation, grading against the local DB,
/// and handing off to ResultsScreen when done.
///
/// A mistake costs nothing here beyond landing the word back in spaced
/// repetition — there used to be a five-heart budget that could lock the
/// whole lesson mid-way through. Learning a language is already the hard
/// part; running out of attempts and being timed out of the app on top of
/// it was pure friction with nothing to show for it.
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
  int _xpEarned = 0;
  final Set<String> _mistakeIds = {};
  bool _loading = true;
  bool _answering = false;
  MascotCharacter _character = MascotCharacter.panda;
  int _correctStreak = 0;
  final _mascotController = MascotCompanionController();
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repos = context.read<AppRepositories>();
    final lessonWords = await repos.words.getWordsByIds(widget.wordIds);
    final allWords = await repos.words.getAllWords();
    final questions = ExerciseGenerator.build(
      lessonWords: lessonWords,
      allWords: allWords,
      availableStrokeChars: repos.strokeData.availableCharacters,
    );
    final stats = await repos.stats.getStats();
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _character = MascotCharacter.fromDb(stats.mascotCharacter);
      _loading = false;
    });
    if (questions.isNotEmpty) {
      final settings = context.read<AppSettings>();
      _mascotController.react(
        MascotCue.hello,
        settings.locale == AppLocale.ru ? 'Погнали! 🐼' : "Let's go! 🐼",
      );
    }
  }

  /// What the correct answer actually was, for the mascot's mid-lesson hint
  /// after a miss — built from whichever fields this question type
  /// populates, since each exercise type carries the answer differently.
  String _correctAnswerText(ExerciseQuestion q) {
    switch (q.type) {
      case ExerciseType.flip:
        final parts = [
          if (q.hanzi != null) q.hanzi!,
          if (q.pinyin != null) '(${q.pinyin})',
          if (q.translation != null) q.translation!,
        ];
        return parts.join(' ');
      case ExerciseType.chooseTranslation:
      case ExerciseType.chooseHanzi:
        return q.correctOption ?? '';
      case ExerciseType.buildSentence:
        return (q.correctOrder ?? const []).join(' ');
      case ExerciseType.typePinyin:
        return q.correctPinyin ?? '';
      case ExerciseType.writeHanzi:
        return q.hanzi ?? '';
    }
  }

  Future<void> _handleAnswer(bool correct) async {
    // Exercise widgets already guard against double-submission themselves,
    // but this is the shared choke point for every type — guard here too
    // so a rapid double-tap can never double-write SRS/XP.
    if (_answering) return;
    _answering = true;
    try {
      final repos = context.read<AppRepositories>();
      final question = _questions![_index];
      final earned = XpService.xpForAnswer(correct);

      // The exercise widgets already show their own inline feedback before
      // calling this, so the mascot's pop-up is a second beat rather than
      // the only one: a nudge toward the right answer on a miss, or an
      // occasional joke once a streak's actually built up (every answer
      // would just turn into noise).
      final settings = context.read<AppSettings>();
      if (correct) {
        _correctStreak += 1;
        if (_correctStreak % 3 == 0) {
          final joke = MascotJokes.all[_random.nextInt(MascotJokes.all.length)];
          _mascotController.react(
            MascotCue.correct,
            settings.locale == AppLocale.ru ? joke.ru : joke.en,
          );
        }
      } else {
        _correctStreak = 0;
        final answer = _correctAnswerText(question);
        _mascotController.react(
          MascotCue.incorrect,
          settings.locale == AppLocale.ru
              ? 'Ничего, бывает! Правильный ответ: $answer'
              : "No worries! The answer was: $answer",
        );
      }

      await repos.srs.recordReview(
        wordId: question.wordId,
        wasCorrect: correct,
        exerciseType: question.type.name,
      );
      await repos.stats.addXpAndRecordActivity(earned);
      if (!correct) _mistakeIds.add(question.wordId);

      if (!mounted) return;
      setState(() => _xpEarned += earned);

      final isLastQuestion = _index + 1 >= _questions!.length;
      if (isLastQuestion) {
        await _finish();
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

    // Not every lesson — see RewardService for why that's the point.
    final reward = RewardService.roll();
    if (reward != null && reward.kind == RewardKind.bonusXp) {
      await repos.stats.addXpAndRecordActivity(reward.xp);
      _xpEarned += reward.xp;
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
            reward: reward,
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

    final progress = _index / _questions!.length;
    final question = _questions![_index];

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Center(
                      // The writing exercise's canvas only recognizes
                      // onPanUpdate/onPanEnd, which lose the gesture-arena
                      // race against a scrollable ancestor's own vertical
                      // drag recognizer for any top-to-bottom stroke — the
                      // most common stroke direction in Chinese characters.
                      // That reads as "drawing doesn't register" even
                      // though every other exercise type genuinely
                      // benefits from scrolling on short screens.
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
            // A floating companion rather than inline in the header — it
            // needs room for its speech bubble.
            Positioned(
              right: 8,
              bottom: 8,
              child: MascotCompanion(
                character: _character,
                controller: _mascotController,
              ),
            ),
          ],
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
