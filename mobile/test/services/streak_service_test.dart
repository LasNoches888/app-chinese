import 'package:app_chinese/services/streak_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreakService.recordActivity', () {
    test('first-ever activity starts a streak of 1', () {
      final result = StreakService.recordActivity(
        lastActivityDate: null,
        currentStreak: 0,
        longestStreak: 0,
        now: DateTime(2026, 1, 10),
      );
      expect(result.currentStreak, 1);
      expect(result.longestStreak, 1);
    });

    test('a second session on the same day does not double-increment', () {
      final morning = StreakService.recordActivity(
        lastActivityDate: DateTime(2026, 1, 9),
        currentStreak: 3,
        longestStreak: 5,
        now: DateTime(2026, 1, 10, 8),
      );
      final evening = StreakService.recordActivity(
        lastActivityDate: morning.lastActivityDate,
        currentStreak: morning.currentStreak,
        longestStreak: morning.longestStreak,
        now: DateTime(2026, 1, 10, 20),
      );
      expect(morning.currentStreak, 4);
      expect(evening.currentStreak, 4);
    });

    test('activity on the very next day extends the streak', () {
      final result = StreakService.recordActivity(
        lastActivityDate: DateTime(2026, 1, 9),
        currentStreak: 3,
        longestStreak: 3,
        now: DateTime(2026, 1, 10),
      );
      expect(result.currentStreak, 4);
      expect(result.longestStreak, 4);
    });

    test('skipping a day resets the streak to 1', () {
      final result = StreakService.recordActivity(
        lastActivityDate: DateTime(2026, 1, 8),
        currentStreak: 5,
        longestStreak: 10,
        now: DateTime(2026, 1, 10),
      );
      expect(result.currentStreak, 1);
      expect(result.longestStreak, 10); // longest record is preserved
    });

    test('longest streak updates only when the current streak surpasses it',
        () {
      final result = StreakService.recordActivity(
        lastActivityDate: DateTime(2026, 1, 9),
        currentStreak: 2,
        longestStreak: 2,
        now: DateTime(2026, 1, 10),
      );
      expect(result.currentStreak, 3);
      expect(result.longestStreak, 3);
    });
  });

  group('StreakService.isBroken', () {
    test('is false with no recorded activity yet', () {
      expect(
          StreakService.isBroken(
              lastActivityDate: null, now: DateTime(2026, 1, 10)),
          isFalse);
    });

    test('is false the same day or the very next day', () {
      expect(
        StreakService.isBroken(
            lastActivityDate: DateTime(2026, 1, 10),
            now: DateTime(2026, 1, 10)),
        isFalse,
      );
      expect(
        StreakService.isBroken(
            lastActivityDate: DateTime(2026, 1, 9), now: DateTime(2026, 1, 10)),
        isFalse,
      );
    });

    test('is true once a full day has been skipped', () {
      expect(
        StreakService.isBroken(
            lastActivityDate: DateTime(2026, 1, 8), now: DateTime(2026, 1, 10)),
        isTrue,
      );
    });
  });
}
