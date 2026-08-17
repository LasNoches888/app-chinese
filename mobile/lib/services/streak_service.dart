import 'dart:math' as math;

class StreakUpdate {
  final int currentStreak;
  final int longestStreak;
  final DateTime lastActivityDate;

  const StreakUpdate({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastActivityDate,
  });
}

/// Streak bookkeeping as pure functions over (date-only) values, so the
/// day-boundary edge cases can be unit-tested without a clock/database.
class StreakService {
  /// Call once per completed exercise; safe to call multiple times in the
  /// same day — later calls the same day don't double-increment.
  static StreakUpdate recordActivity({
    required DateTime? lastActivityDate,
    required int currentStreak,
    required int longestStreak,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());

    if (lastActivityDate == null) {
      return StreakUpdate(
          currentStreak: 1,
          longestStreak: math.max(1, longestStreak),
          lastActivityDate: today);
    }

    final last = _dateOnly(lastActivityDate);
    final dayDiff = today.difference(last).inDays;

    if (dayDiff <= 0) {
      // Same day (or a clock going backwards) — no change to the streak.
      return StreakUpdate(
          currentStreak: currentStreak,
          longestStreak: longestStreak,
          lastActivityDate: last);
    }
    if (dayDiff == 1) {
      final newStreak = currentStreak + 1;
      return StreakUpdate(
        currentStreak: newStreak,
        longestStreak: math.max(longestStreak, newStreak),
        lastActivityDate: today,
      );
    }
    // A day (or more) was skipped: streak resets.
    return StreakUpdate(
        currentStreak: 1,
        longestStreak: math.max(longestStreak, 1),
        lastActivityDate: today);
  }

  /// True once more than one full day has passed since the last logged
  /// activity — used to show the streak as broken in the UI without
  /// mutating stored state (the actual reset happens on next activity).
  static bool isBroken({required DateTime? lastActivityDate, DateTime? now}) {
    if (lastActivityDate == null) return false;
    final today = _dateOnly(now ?? DateTime.now());
    final last = _dateOnly(lastActivityDate);
    return today.difference(last).inDays > 1;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
