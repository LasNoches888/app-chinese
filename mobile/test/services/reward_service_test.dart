import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_chinese/services/reward_service.dart';

/// A Random stand-in whose nextDouble()/nextInt() are scripted, so the
/// probabilistic roll can be tested deterministically.
class _ScriptedRandom implements Random {
  final double _double;
  final List<int> _ints;
  int _intCalls = 0;

  _ScriptedRandom(this._double, this._ints);

  @override
  double nextDouble() => _double;

  @override
  int nextInt(int max) => _ints[_intCalls++];

  @override
  bool nextBool() => false;
}

void main() {
  group('RewardService.roll', () {
    test('misses most of the time', () {
      // nextDouble() at or above the 25% threshold is a miss.
      final rng = _ScriptedRandom(0.25, const []);
      expect(RewardService.roll(random: rng), isNull);
    });

    test('a hit picks bonus XP within the small, bounded range', () {
      // First nextInt selects the reward kind (0 = bonusXp), second picks
      // the XP step.
      final rng = _ScriptedRandom(0.0, const [0, 2]);
      final reward = RewardService.roll(random: rng);
      expect(reward, isNotNull);
      expect(reward!.kind, RewardKind.bonusXp);
      expect(reward.xp, 20); // 10 + 2*5
    });

    test('a hit can pick a cheer', () {
      final rng = _ScriptedRandom(0.0, const [1, 0]);
      final reward = RewardService.roll(random: rng);
      expect(reward!.kind, RewardKind.cheer);
      expect(reward.cheer, isNotNull);
    });

    test('a hit can pick a China fact', () {
      final rng = _ScriptedRandom(0.0, const [2, 0]);
      final reward = RewardService.roll(random: rng);
      expect(reward!.kind, RewardKind.fact);
      expect(reward.fact, isNotNull);
    });
  });
}
