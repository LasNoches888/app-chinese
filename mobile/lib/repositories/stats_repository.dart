import 'package:sqflite/sqflite.dart';

import '../models/user_stats.dart';
import '../services/streak_service.dart';

/// Owns the single-row user_stats table: XP/level inputs, streak, and the
/// daily goal.
///
/// Mistakes cost nothing beyond landing the word back in spaced
/// repetition; there used to be a five-heart budget that could lock a
/// lesson mid-way through, which was pure friction with nothing to show
/// for it. The `hearts_*` columns survive that removal (see [UserStats]
/// for why they aren't migrated away) and are only ever written at the
/// two places a fresh row is created, because `hearts_updated_at` is NOT
/// NULL without a default.
class StatsRepository {
  final Database db;

  StatsRepository(this.db);

  Future<UserStats> getStats() async {
    final rows = await db.query('user_stats', where: 'id = 1');
    return UserStats.fromMap(rows.first);
  }

  Future<void> _save(UserStats stats) async {
    await db.update('user_stats', {
      'total_xp': stats.totalXp,
      'current_streak': stats.currentStreak,
      'longest_streak': stats.longestStreak,
      'last_activity_date': stats.lastActivityDate?.toIso8601String(),
      'daily_goal_xp': stats.dailyGoalXp,
      'xp_today': stats.xpToday,
      'xp_today_date': stats.xpTodayDate,
      'perfect_lessons_count': stats.perfectLessonsCount,
      'streak_freezes': stats.streakFreezes,
      'daily_challenges_completed': stats.dailyChallengesCompleted,
      'race_wins': stats.raceWins,
      'listening_completed': stats.listeningCompleted,
      'pronunciation_completed': stats.pronunciationCompleted,
      'mascot_character': stats.mascotCharacter,
      'equipped_outfit': stats.equippedOutfit,
    }, where: 'id = 1');
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Adds XP, rolls `xp_today` over on a date change, and records today's
  /// streak activity. Call once per answered question.
  ///
  /// [pronunciationCompleted] folds in the pronunciation-check counter so
  /// callers that need both don't pay for two separate read-modify-write
  /// round trips to the same row.
  Future<UserStats> addXpAndRecordActivity(
    int xp, {
    DateTime? now,
    bool pronunciationCompleted = false,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    var stats = await getStats();
    final todayKey = _dateKey(effectiveNow);
    final xpToday = stats.xpTodayDate == todayKey ? stats.xpToday + xp : xp;

    final streakUpdate = StreakService.recordActivity(
      lastActivityDate: stats.lastActivityDate,
      currentStreak: stats.currentStreak,
      longestStreak: stats.longestStreak,
      freezesAvailable: stats.streakFreezes,
      now: effectiveNow,
    );
    final remainingFreezes = stats.streakFreezes - streakUpdate.freezesUsed;
    final newFreezeCount = StreakService.maybeAwardFreeze(
      newStreak: streakUpdate.currentStreak,
      previousStreak: stats.currentStreak,
      currentFreezes: remainingFreezes,
    );

    stats = stats.copyWith(
      totalXp: stats.totalXp + xp,
      xpToday: xpToday,
      xpTodayDate: todayKey,
      currentStreak: streakUpdate.currentStreak,
      longestStreak: streakUpdate.longestStreak,
      lastActivityDate: streakUpdate.lastActivityDate,
      streakFreezes: newFreezeCount,
      pronunciationCompleted: pronunciationCompleted
          ? stats.pronunciationCompleted + 1
          : stats.pronunciationCompleted,
    );
    await _save(stats);
    return stats;
  }

  Future<UserStats> setDailyGoalXp(int xp) async {
    var stats = await getStats();
    stats = stats.copyWith(dailyGoalXp: xp);
    await _save(stats);
    return stats;
  }

  Future<UserStats> recordPerfectLesson() async {
    var stats = await getStats();
    stats = stats.copyWith(perfectLessonsCount: stats.perfectLessonsCount + 1);
    await _save(stats);
    return stats;
  }

  Future<UserStats> recordDailyChallengeCompleted() async {
    var stats = await getStats();
    stats = stats.copyWith(
      dailyChallengesCompleted: stats.dailyChallengesCompleted + 1,
    );
    await _save(stats);
    return stats;
  }

  Future<UserStats> recordListeningCompleted() async {
    var stats = await getStats();
    stats = stats.copyWith(listeningCompleted: stats.listeningCompleted + 1);
    await _save(stats);
    return stats;
  }

  Future<UserStats> recordPronunciationCompleted() async {
    var stats = await getStats();
    stats = stats.copyWith(
      pronunciationCompleted: stats.pronunciationCompleted + 1,
    );
    await _save(stats);
    return stats;
  }

  Future<UserStats> recordRaceWin() async {
    var stats = await getStats();
    stats = stats.copyWith(raceWins: stats.raceWins + 1);
    await _save(stats);
    return stats;
  }

  /// Switches the home-screen companion. Resets the equipped outfit back to
  /// "auto" (-1) — the two animals don't share an outfit set, so an index
  /// that pointed to a valid panda outfit could point at the wrong thing
  /// for the pug.
  Future<UserStats> setMascotCharacter(String character) async {
    var stats = await getStats();
    stats = stats.copyWith(mascotCharacter: character, equippedOutfit: -1);
    await _save(stats);
    return stats;
  }

  Future<UserStats> setEquippedOutfit(int outfitIndex) async {
    var stats = await getStats();
    stats = stats.copyWith(equippedOutfit: outfitIndex);
    await _save(stats);
    return stats;
  }

  /// Wipes all learning progress (XP, streak, SRS history, completed
  /// lessons, achievements) back to a fresh install. The word bank itself
  /// (words/decks) is untouched — it's seed content, not user data.
  Future<void> resetAllProgress() async {
    await db.delete('review_history');
    await db.delete('completed_lessons');
    await db.delete('achievements_unlocked');
    await db.delete('user_stats');
    await db.insert('user_stats', {
      'id': 1,
      // Dead column from the removed lives system, but NOT NULL with no
      // default, so a fresh row still has to name it.
      'hearts_updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
