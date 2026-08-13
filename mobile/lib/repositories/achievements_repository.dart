import 'package:sqflite/sqflite.dart';

import '../models/user_stats.dart';
import '../services/srs_service.dart';
import 'srs_repository.dart';
import 'word_repository.dart';

/// Computes and persists unlocked achievements. Unlock checks run against
/// live progress (SrsRepository/WordRepository); once a code is written to
/// achievements_unlocked it stays unlocked even if the underlying stat
/// later drops (e.g. a streak breaking doesn't revoke `streak_7`).
class AchievementsRepository {
  final Database db;
  final SrsRepository srs;
  final WordRepository words;

  AchievementsRepository(this.db, this.srs, this.words);

  Future<Map<String, DateTime>> getUnlockedMap() async {
    final rows = await db.query('achievements_unlocked');
    return {
      for (final r in rows) r['code'] as String: DateTime.fromMillisecondsSinceEpoch(r['unlocked_at'] as int),
    };
  }

  Future<bool> _isHsk1Complete() async {
    final hsk1Words = (await words.getAllWords()).where((w) => w.hskLevel == 1).toList();
    if (hsk1Words.isEmpty) return false;
    for (final w in hsk1Words) {
      final state = await srs.getState(w.id);
      if (!SrsService.isLearned(state.repetitions)) return false;
    }
    return true;
  }

  /// Evaluates all achievement thresholds and persists any newly-unlocked
  /// ones. Call after finishing a lesson or review session. Returns the
  /// codes unlocked by this call (empty if nothing new).
  Future<List<String>> evaluateAndUnlock(UserStats stats) async {
    final unlocked = await getUnlockedMap();
    final learnedWords = await srs.countLearnedWords();

    final results = <String, bool>{
      'streak_3': stats.currentStreak >= 3,
      'streak_7': stats.currentStreak >= 7,
      'streak_30': stats.currentStreak >= 30,
      'words_50': learnedWords >= 50,
      'words_100': learnedWords >= 100,
      'words_300': learnedWords >= 300,
      'perfect_lesson': stats.perfectLessonsCount >= 1,
      'hsk1_complete': await _isHsk1Complete(),
    };

    final newlyUnlocked = <String>[];
    for (final entry in results.entries) {
      if (unlocked.containsKey(entry.key)) continue;
      if (entry.value) {
        await db.insert('achievements_unlocked', {
          'code': entry.key,
          'unlocked_at': DateTime.now().millisecondsSinceEpoch,
        });
        newlyUnlocked.add(entry.key);
      }
    }
    return newlyUnlocked;
  }
}
