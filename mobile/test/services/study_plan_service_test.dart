import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_chinese/data/study_plans.dart';
import 'package:app_chinese/models/user_stats.dart';
import 'package:app_chinese/services/study_plan_service.dart';

/// Plan progress is read off real activity rather than manual ticks, so
/// these lock down the mapping from "what the learner did" to "what the
/// plan says they've achieved".
void main() {
  UserStats stats({
    int currentStreak = 0,
    int perfectLessons = 0,
    int dailyChallenges = 0,
    int listening = 0,
    int pronunciation = 0,
  }) => UserStats(
    totalXp: 0,
    currentStreak: currentStreak,
    longestStreak: 99,
    lastActivityDate: null,
    heartsCurrent: 5,
    heartsMax: 5,
    heartsUpdatedAt: DateTime(2026),
    dailyGoalXp: 20,
    xpToday: 0,
    xpTodayDate: null,
    perfectLessonsCount: perfectLessons,
    streakFreezes: 0,
    dailyChallengesCompleted: dailyChallenges,
    raceWins: 0,
    listeningCompleted: listening,
    pronunciationCompleted: pronunciation,
  );

  const plan = StudyPlan(
    id: 'test',
    emoji: '🌱',
    titleRu: 'Тест',
    descriptionRu: 'описание',
    outcomesRu: ['сможешь'],
    samples: [PlanSample('你好', 'nǐ hǎo', 'привет')],
    paceRu: 'темп',
    stage: 1,
    steps: [
      PlanStep.deck('greetings', 'Здороваться', 'подробности'),
      PlanStep.words(10, 'Выучить 10 слов', 'подробности'),
      PlanStep.streak(3, 'Серия 3 дня', 'подробности'),
      PlanStep.listening(2, 'Два диалога', 'подробности'),
    ],
  );

  PlanProgress evaluate({
    Set<String> decks = const {},
    int known = 0,
    UserStats? s,
  }) => StudyPlanService.evaluate(
    plan: plan,
    stats: s ?? stats(),
    completedDeckIds: decks,
    knownWordCount: known,
  );

  group('StudyPlanService.evaluate', () {
    test('a fresh profile has nothing done', () {
      final p = evaluate();
      expect(p.doneCount, 0);
      expect(p.isComplete, isFalse);
      expect(p.isStarted, isFalse);
      expect(p.currentStep?.step.titleRu, 'Здороваться');
    });

    test('completing the deck ticks only that step', () {
      final p = evaluate(decks: {'greetings'});
      expect(p.steps.first.isDone, isTrue);
      expect(p.doneCount, 1);
      expect(p.currentStep?.step.titleRu, 'Выучить 10 слов');
    });

    test('a different deck does not tick the step', () {
      expect(evaluate(decks: {'numbers'}).steps.first.isDone, isFalse);
    });

    test('counting steps report partial progress', () {
      final p = evaluate(known: 4);
      final words = p.steps[1];
      expect(words.isDone, isFalse);
      expect(words.current, 4);
      expect(words.fraction, closeTo(0.4, 0.001));
      expect(p.isStarted, isTrue);
    });

    test('exceeding the target still counts as done, not over-full', () {
      final words = evaluate(known: 50).steps[1];
      expect(words.isDone, isTrue);
      expect(words.fraction, 1.0);
    });

    test('streak steps follow the current streak, not the record', () {
      // longestStreak is 99 in the fixture — a step asking for three days
      // running must not stay ticked once the streak actually breaks.
      final p = evaluate(s: stats(currentStreak: 0));
      expect(p.steps[2].isDone, isFalse);
      expect(evaluate(s: stats(currentStreak: 3)).steps[2].isDone, isTrue);
    });

    test('listening milestones follow the listening counter', () {
      expect(evaluate(s: stats(listening: 2)).steps[3].isDone, isTrue);
    });

    test('a fully finished plan reports complete', () {
      final p = evaluate(
        decks: {'greetings'},
        known: 10,
        s: stats(currentStreak: 3, listening: 2),
      );
      expect(p.isComplete, isTrue);
      expect(p.fraction, 1.0);
      expect(p.currentStep, isNull);
    });
  });

  group('StudyPlanService.recommended', () {
    test('prefers a started plan closest to finishing', () {
      // Part-way through "first steps": two of its decks done and the
      // 3-day streak met, so it outranks the bigger plans that this same
      // progress has only just nudged.
      final all = StudyPlanService.evaluateAll(
        stats: stats(currentStreak: 3),
        completedDeckIds: {'greetings', 'numbers'},
        knownWordCount: 5,
      );
      expect(StudyPlanService.recommended(all)!.plan.id, 'first_steps');
    });

    test('moves on once the leading plan is finished', () {
      // Same profile plus the last two steps of "first steps" — it drops
      // out of the running rather than staying pinned as "continue".
      final all = StudyPlanService.evaluateAll(
        stats: stats(currentStreak: 3, perfectLessons: 1),
        completedDeckIds: {'greetings', 'numbers', 'people'},
        knownWordCount: 5,
      );
      final rec = StudyPlanService.recommended(all)!;
      expect(rec.plan.id, isNot('first_steps'));
      expect(rec.isComplete, isFalse);
    });

    test('falls back to the first plan for a fresh profile', () {
      final all = StudyPlanService.evaluateAll(
        stats: stats(),
        completedDeckIds: const {},
        knownWordCount: 0,
      );
      expect(StudyPlanService.recommended(all)!.plan.id, kStudyPlans.first.id);
    });

    test('never recommends a plan that is already finished', () {
      final all = StudyPlanService.evaluateAll(
        stats: stats(
          currentStreak: 60,
          perfectLessons: 20,
          dailyChallenges: 20,
          listening: 50,
          pronunciation: 50,
        ),
        completedDeckIds: {
          for (final p in kStudyPlans)
            for (final s in p.steps)
              if (s.deckId != null) s.deckId!,
        },
        knownWordCount: 1000,
      );
      expect(StudyPlanService.recommended(all), isNull);
    });
  });

  group('bundled plans', () {
    test('plan ids are unique', () {
      final ids = kStudyPlans.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every plan has steps and a pace estimate', () {
      for (final p in kStudyPlans) {
        expect(p.steps, isNotEmpty, reason: p.id);
        expect(p.paceRu.trim(), isNotEmpty, reason: p.id);
        expect(p.stage, inInclusiveRange(1, 3), reason: p.id);
      }
    });

    test('deck steps point at decks that actually exist', () async {
      // Guards against a plan quietly referencing a renamed deck, which
      // would show a step that can never be completed.
      final decks = await _seedDeckIds();
      for (final p in kStudyPlans) {
        for (final s in p.steps) {
          if (s.deckId == null) continue;
          expect(decks, contains(s.deckId), reason: '${p.id}/${s.deckId}');
        }
      }
    });

    test('every plan explains what it buys and proves it with phrases', () {
      for (final p in kStudyPlans) {
        expect(p.outcomesRu, isNotEmpty, reason: p.id);
        expect(p.samples, isNotEmpty, reason: p.id);
        for (final s in p.samples) {
          expect(s.hanzi.trim(), isNotEmpty, reason: p.id);
          expect(s.pinyin.trim(), isNotEmpty, reason: p.id);
          expect(s.ru.trim(), isNotEmpty, reason: p.id);
        }
        for (final s in p.steps) {
          expect(s.detailRu.trim(), isNotEmpty, reason: '${p.id}/${s.titleRu}');
        }
      }
    });

    test('sample phrases only use characters the course teaches', () async {
      // The samples are shown as "фразы, которые откроются". A sample
      // built from a character no deck covers would be a promise the app
      // cannot keep.
      final taught = await _taughtCharacters();
      for (final p in kStudyPlans) {
        for (final s in p.samples) {
          final unknown = s.hanzi
              .split('')
              .where((c) => RegExp(r'[一-鿿]').hasMatch(c))
              .where((c) => !taught.contains(c))
              .toSet();
          expect(unknown, isEmpty, reason: '${p.id}: ${s.hanzi}');
        }
      }
    });

    test('plans cover listening and speaking, not just vocabulary', () {
      final kinds = {
        for (final p in kStudyPlans)
          for (final s in p.steps) s.kind,
      };
      expect(kinds, contains(PlanStepKind.listening));
      expect(kinds, contains(PlanStepKind.pronunciation));
    });
  });
}

Future<Set<String>> _taughtCharacters() async {
  final words = await _readSeed('assets/seed/words.json');
  return {for (final w in words) ...(w['hanzi'] as String).split('')};
}

Future<Set<String>> _seedDeckIds() async {
  final file = await _readSeed('assets/seed/decks.json');
  return file.map((d) => d['id'] as String).toSet();
}

Future<List<Map<String, dynamic>>> _readSeed(String path) async {
  final raw = await File(path).readAsString();
  return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
}
