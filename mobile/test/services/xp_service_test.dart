import 'dart:math' as math;

import 'package:app_chinese/services/xp_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors XpService's private threshold formula (100 * level^1.2) so
/// tests assert against the real curve instead of a hand-computed
/// (and easily wrong) constant.
int _threshold(int level) =>
    level <= 1 ? 0 : (100 * math.pow(level.toDouble(), 1.2)).floor();

void main() {
  group('XpService.xpForAnswer', () {
    test('awards 10 XP for a correct answer', () {
      expect(XpService.xpForAnswer(true), 10);
    });

    test('awards 2 XP for an incorrect attempt', () {
      expect(XpService.xpForAnswer(false), 2);
    });
  });

  group('XpService.levelForXp', () {
    test('starts at level 1 with zero XP', () {
      expect(XpService.levelForXp(0), 1);
    });

    test('stays at level 1 just below the level-2 threshold', () {
      final t2 = _threshold(2);
      expect(XpService.levelForXp(t2 - 1), 1);
    });

    test('reaches level 2 exactly at its threshold', () {
      final t2 = _threshold(2);
      expect(XpService.levelForXp(t2), 2);
    });

    test('level increases monotonically with more XP', () {
      final level1 = XpService.levelForXp(500);
      final level2 = XpService.levelForXp(5000);
      expect(level2, greaterThan(level1));
    });
  });

  group('XpService.xpToNextLevel', () {
    test('matches the gap to the next threshold from zero', () {
      expect(XpService.xpToNextLevel(0), _threshold(2));
    });

    test('reaching total_xp + xpToNextLevel always bumps the level', () {
      const totalXp = 150;
      final level = XpService.levelForXp(totalXp);
      final toNext = XpService.xpToNextLevel(totalXp);
      expect(XpService.levelForXp(totalXp + toNext), level + 1);
    });
  });
}
