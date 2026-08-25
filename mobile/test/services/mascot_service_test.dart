import 'package:flutter_test/flutter_test.dart';

import 'package:app_chinese/models/user_stats.dart';
import 'package:app_chinese/services/mascot_service.dart';

UserStats _stats({int totalXp = 0, DateTime? lastActivityDate}) => UserStats(
  totalXp: totalXp,
  currentStreak: 0,
  longestStreak: 0,
  lastActivityDate: lastActivityDate,
  heartsCurrent: 5,
  heartsMax: 5,
  heartsUpdatedAt: DateTime(2024),
  dailyGoalXp: 50,
  xpToday: 0,
  xpTodayDate: null,
  perfectLessonsCount: 0,
  streakFreezes: 0,
  dailyChallengesCompleted: 0,
  raceWins: 0,
  listeningCompleted: 0,
  pronunciationCompleted: 0,
);

void main() {
  group('MascotService.reactionAsset', () {
    test('each reaction has a distinct still', () {
      final assets = MascotReaction.values.map(MascotService.reactionAsset);
      expect(assets.toSet().length, MascotReaction.values.length);
    });
  });

  group('MascotService.homeAsset', () {
    final now = DateTime(2026, 1, 10);

    test('a fresh profile with no activity yet gets the starter look', () {
      final asset = MascotService.homeAsset(_stats(), now: now);
      expect(asset, 'assets/mascot/panda_02.png');
    });

    test('recent activity shows the level-appropriate outfit, not asleep', () {
      final asset = MascotService.homeAsset(
        _stats(totalXp: 5000, lastActivityDate: now),
        now: now,
      );
      expect(asset, isNot('assets/mascot/panda_14.png'));
    });

    test('two quiet days puts the mascot to sleep, regardless of level', () {
      final asset = MascotService.homeAsset(
        _stats(
          totalXp: 5000,
          lastActivityDate: now.subtract(const Duration(days: 2)),
        ),
        now: now,
      );
      expect(asset, 'assets/mascot/panda_14.png');
    });

    test('a higher level unlocks a fancier outfit', () {
      final low = MascotService.homeAsset(
        _stats(totalXp: 0, lastActivityDate: now),
        now: now,
      );
      final high = MascotService.homeAsset(
        _stats(totalXp: 5000, lastActivityDate: now),
        now: now,
      );
      expect(low, isNot(high));
    });
  });
}
