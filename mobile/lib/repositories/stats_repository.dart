import 'package:sqflite/sqflite.dart';

import '../models/user_stats.dart';
import '../services/hearts_service.dart';
import '../services/streak_service.dart';

/// Owns the single-row user_stats table: XP/level inputs, hearts (with
/// time-based regen applied lazily on read), streak, and the daily goal.
class StatsRepository {
  final Database db;

  StatsRepository(this.db);

  Future<UserStats> getStats() async {
    final rows = await db.query('user_stats', where: 'id = 1');
    final stats = UserStats.fromMap(rows.first);
    return _applyHeartRegenIfNeeded(stats);
  }

  Future<UserStats> _applyHeartRegenIfNeeded(UserStats stats) async {
    final (newHearts, newUpdatedAt) = HeartsService.applyRegen(
      hearts: stats.heartsCurrent,
      updatedAt: stats.heartsUpdatedAt,
    );
    if (newHearts == stats.heartsCurrent) return stats;
    final updated = stats.copyWith(
      heartsCurrent: newHearts,
      heartsUpdatedAt: newUpdatedAt,
    );
    await _save(updated);
    return updated;
  }

  Future<void> _save(UserStats stats) async {
    await db.update('user_stats', {
      'total_xp': stats.totalXp,
      'current_streak': stats.currentStreak,
      'longest_streak': stats.longestStreak,
      'last_activity_date': stats.lastActivityDate?.toIso8601String(),
      'hearts_current': stats.heartsCurrent,
      'hearts_max': stats.heartsMax,
      'hearts_updated_at': stats.heartsUpdatedAt.millisecondsSinceEpoch,
      'daily_goal_xp': stats.dailyGoalXp,
      'xp_today': stats.xpToday,
      'xp_today_date': stats.xpTodayDate,
      'perfect_lessons_count': stats.perfectLessonsCount,
      'streak_freezes': stats.streakFreezes,
      'daily_challenges_completed': stats.dailyChallengesCompleted,
      'race_wins': stats.raceWins,
      'listening_completed': stats.listeningCompleted,
      'pronunciation_completed': stats.pronunciationCompleted,
    }, where: 'id = 1');
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Adds XP, rolls `xp_today` over on a date change, and records today's
  /// streak activity. Call once per answered question.
  Future<UserStats> addXpAndRecordActivity(int xp, {DateTime? now}) async {
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
    );
    await _save(stats);
    return stats;
  }

  Future<UserStats> loseHeart() async {
    var stats = await getStats();
    if (stats.heartsCurrent <= 0) return stats;
    final wasFull = stats.heartsCurrent >= stats.heartsMax;
    stats = stats.copyWith(
      heartsCurrent: stats.heartsCurrent - 1,
      heartsUpdatedAt: wasFull ? DateTime.now() : stats.heartsUpdatedAt,
    );
    await _save(stats);
    return stats;
  }

  Future<UserStats> restoreHeartsFully() async {
    var stats = await getStats();
    stats = stats.copyWith(
      heartsCurrent: stats.heartsMax,
      heartsUpdatedAt: DateTime.now(),
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

  /// Wipes all learning progress (XP, streak, hearts, SRS history,
  /// completed lessons, achievements) back to a fresh install. The word
  /// bank itself (words/decks) is untouched — it's seed content, not
  /// user data.
  Future<void> resetAllProgress() async {
    await db.delete('review_history');
    await db.delete('completed_lessons');
    await db.delete('achievements_unlocked');
    await db.delete('user_stats');
    await db.insert('user_stats', {
      'id': 1,
      'hearts_updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
