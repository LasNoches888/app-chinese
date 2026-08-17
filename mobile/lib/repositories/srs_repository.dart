import 'package:sqflite/sqflite.dart';

import '../services/srs_service.dart';

class WordSrsState {
  final int repetitions;
  final double easeFactor;
  final int intervalDays;
  final DateTime nextReviewAt;

  const WordSrsState({
    required this.repetitions,
    required this.easeFactor,
    required this.intervalDays,
    required this.nextReviewAt,
  });

  factory WordSrsState.fresh() => WordSrsState(
        repetitions: 0,
        easeFactor: SrsService.defaultEaseFactor,
        intervalDays: 0,
        nextReviewAt: DateTime.now(),
      );
}

/// Owns review_history (the SRS event log), completed_lessons, and the
/// queries derived from them (due words, learned-word count, accuracy).
///
/// review_history is append-only: each row is a full snapshot of the
/// word's SM-2 state *after* that review. "Current" state for a word is
/// therefore its most recent row. We resolve that in Dart rather than
/// with a SQL window function, since window-function support depends on
/// the SQLite version bundled with the device's Android build.
class SrsRepository {
  final Database db;

  SrsRepository(this.db);

  Future<WordSrsState> getState(String wordId) async {
    final rows = await db.query(
      'review_history',
      where: 'word_id = ?',
      whereArgs: [wordId],
      orderBy: 'reviewed_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return WordSrsState.fresh();
    final r = rows.first;
    return WordSrsState(
      repetitions: r['repetitions'] as int,
      easeFactor: r['ease_factor'] as double,
      intervalDays: r['interval_days'] as int,
      nextReviewAt:
          DateTime.fromMillisecondsSinceEpoch(r['next_review_at'] as int),
    );
  }

  Future<void> recordReview({
    required String wordId,
    required bool wasCorrect,
    required String exerciseType,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final prev = await getState(wordId);
    final quality = wasCorrect ? 5 : 1;
    final result = SrsService.review(
      prevRepetitions: prev.repetitions,
      prevEaseFactor: prev.easeFactor,
      prevIntervalDays: prev.intervalDays,
      quality: quality,
      now: effectiveNow,
    );
    await db.insert('review_history', {
      'word_id': wordId,
      'reviewed_at': effectiveNow.millisecondsSinceEpoch,
      'was_correct': wasCorrect ? 1 : 0,
      'exercise_type': exerciseType,
      'repetitions': result.repetitions,
      'ease_factor': result.easeFactor,
      'interval_days': result.intervalDays,
      'next_review_at': result.nextReviewAt.millisecondsSinceEpoch,
    });
  }

  Future<Map<String, Map<String, Object?>>> _latestRowPerWord() async {
    final rows = await db.query('review_history', orderBy: 'reviewed_at ASC');
    final latest = <String, Map<String, Object?>>{};
    for (final r in rows) {
      latest[r['word_id'] as String] = r;
    }
    return latest;
  }

  Future<List<String>> getDueWordIds({DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final latest = await _latestRowPerWord();
    return latest.entries
        .where((e) =>
            (e.value['next_review_at'] as int) <=
            effectiveNow.millisecondsSinceEpoch)
        .map((e) => e.key)
        .toList();
  }

  Future<int> countLearnedWords() async {
    final latest = await _latestRowPerWord();
    return latest.values
        .where((r) => SrsService.isLearned(r['repetitions'] as int))
        .length;
  }

  /// Word ids the learner has graduated past the first two reviews —
  /// sent to the chat backend so the AI tutor can lean on vocabulary the
  /// learner actually knows (the backend itself stores nothing).
  Future<List<String>> getKnownWordIds() async {
    final latest = await _latestRowPerWord();
    return latest.entries
        .where((e) => SrsService.isLearned(e.value['repetitions'] as int))
        .map((e) => e.key)
        .toList();
  }

  /// Word ids whose most recent review was a miss — surfaced to the chat
  /// backend so it can gently reinforce them.
  Future<List<String>> getWeakWordIds() async {
    final latest = await _latestRowPerWord();
    return latest.entries
        .where((e) => (e.value['was_correct'] as int) == 0)
        .map((e) => e.key)
        .toList();
  }

  Future<int> countTotalReviews() async {
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM review_history')) ??
        0;
  }

  Future<double> accuracyPercent({Duration? within}) async {
    String? where;
    List<Object?>? args;
    if (within != null) {
      where = 'reviewed_at >= ?';
      args = [DateTime.now().subtract(within).millisecondsSinceEpoch];
    }
    final rows =
        await db.query('review_history', where: where, whereArgs: args);
    if (rows.isEmpty) return 0;
    final correct = rows.where((r) => (r['was_correct'] as int) == 1).length;
    return correct / rows.length * 100;
  }

  /// Distinct calendar days (date-only, local time) with at least one
  /// review since [since] — used for the 30-day streak calendar. Derived
  /// straight from the review log rather than a separate "daily activity"
  /// table, since the log already has full history.
  Future<Set<DateTime>> getActiveDaysSince(DateTime since) async {
    final rows = await db.rawQuery(
      'SELECT DISTINCT reviewed_at FROM review_history WHERE reviewed_at >= ?',
      [since.millisecondsSinceEpoch],
    );
    final days = <DateTime>{};
    for (final r in rows) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r['reviewed_at'] as int);
      days.add(DateTime(dt.year, dt.month, dt.day));
    }
    return days;
  }

  Future<Set<String>> getCompletedLessonIds() async {
    final rows = await db.query('completed_lessons');
    return rows.map((r) => r['deck_id'] as String).toSet();
  }

  Future<void> markLessonCompleted(String deckId) async {
    await db.insert(
      'completed_lessons',
      {
        'deck_id': deckId,
        'completed_at': DateTime.now().millisecondsSinceEpoch
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
