import 'dart:math' as math;

class StreakUpdate {
  final int currentStreak;
  final int longestStreak;
  final DateTime lastActivityDate;
  final int freezesUsed;

  const StreakUpdate({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastActivityDate,
    this.freezesUsed = 0,
  });
}

/// Streak bookkeeping as pure functions over (date-only) values, so the
/// day-boundary edge cases can be unit-tested without a clock/database.
class StreakService {
  /// A stockpile cap: unlimited freezes would make the streak meaningless,
  /// so at most this many can be banked at once.
  static const maxFreezes = 2;

  /// Call once per completed exercise; safe to call multiple times in the
  /// same day — later calls the same day don't double-increment.
  ///
  /// [freezesAvailable] banked streak freezes; each one silently covers a
  /// single fully-missed day instead of resetting the streak.
  static StreakUpdate recordActivity({
    required DateTime? lastActivityDate,
    required int currentStreak,
    required int longestStreak,
    int freezesAvailable = 0,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());

    if (lastActivityDate == null) {
      return StreakUpdate(
        currentStreak: 1,
        longestStreak: math.max(1, longestStreak),
        lastActivityDate: today,
      );
    }

    final last = _dateOnly(lastActivityDate);
    final dayDiff = today.difference(last).inDays;

    if (dayDiff <= 0) {
      // Same day (or a clock going backwards) — no change to the streak.
      return StreakUpdate(
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        lastActivityDate: last,
      );
    }
    if (dayDiff == 1) {
      final newStreak = currentStreak + 1;
      return StreakUpdate(
        currentStreak: newStreak,
        longestStreak: math.max(longestStreak, newStreak),
        lastActivityDate: today,
      );
    }
    // At least one full day was skipped: a freeze for each missed day
    // covers the gap, otherwise the streak resets.
    final missedDays = dayDiff - 1;
    if (missedDays <= freezesAvailable) {
      final newStreak = currentStreak + 1;
      return StreakUpdate(
        currentStreak: newStreak,
        longestStreak: math.max(longestStreak, newStreak),
        lastActivityDate: today,
        freezesUsed: missedDays,
      );
    }
    return StreakUpdate(
      currentStreak: 1,
      longestStreak: math.max(longestStreak, 1),
      lastActivityDate: today,
    );
  }

  /// True once the gap since the last logged activity exceeds what the
  /// banked freezes can cover — used to show the streak as broken in the
  /// UI without mutating stored state (the actual reset happens on next
  /// activity).
  static bool isBroken({
    required DateTime? lastActivityDate,
    int freezesAvailable = 0,
    DateTime? now,
  }) {
    if (lastActivityDate == null) return false;
    final today = _dateOnly(now ?? DateTime.now());
    final last = _dateOnly(lastActivityDate);
    final missedDays = today.difference(last).inDays - 1;
    return missedDays > freezesAvailable;
  }

  /// Every 7-day milestone reached by a genuine increment (not a same-day
  /// repeat) banks one more freeze, up to [maxFreezes].
  static int maybeAwardFreeze({
    required int newStreak,
    required int previousStreak,
    required int currentFreezes,
  }) {
    if (newStreak <= previousStreak) return currentFreezes;
    if (newStreak % 7 != 0) return currentFreezes;
    return math.min(maxFreezes, currentFreezes + 1);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
