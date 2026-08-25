import 'dart:math';

import '../data/china_facts.dart';
import '../data/mascot_cheers.dart';

enum RewardKind { bonusXp, cheer, fact }

/// A little unprompted extra handed out after a lesson — never required,
/// never lost, just an occasional "oh, nice" moment.
class LessonReward {
  final RewardKind kind;
  final int xp;
  final MascotCheer? cheer;
  final ChinaFact? fact;

  const LessonReward.bonusXp(this.xp)
    : kind = RewardKind.bonusXp,
      cheer = null,
      fact = null;

  const LessonReward.cheer(this.cheer)
    : kind = RewardKind.cheer,
      xp = 0,
      fact = null;

  const LessonReward.fact(this.fact)
    : kind = RewardKind.fact,
      xp = 0,
      cheer = null;
}

/// Rolls an occasional bonus after a lesson: a little extra XP, a cheerful
/// line from the mascot, or a fact about China. Unpredictable on purpose —
/// a reward that shows up every single time stops feeling like one, and
/// unlike the old hearts system, missing the roll costs the learner
/// nothing.
class RewardService {
  RewardService._();

  static final Random _rng = Random();

  /// Roughly one lesson in four gets something extra.
  static const double _chance = 0.25;

  static LessonReward? roll({Random? random}) {
    final rng = random ?? _rng;
    if (rng.nextDouble() >= _chance) return null;
    switch (RewardKind.values[rng.nextInt(RewardKind.values.length)]) {
      case RewardKind.bonusXp:
        // 10, 15, 20, or 25 — small enough to stay a bonus, not a target.
        return LessonReward.bonusXp(10 + rng.nextInt(4) * 5);
      case RewardKind.cheer:
        return LessonReward.cheer(
          MascotCheers.all[rng.nextInt(MascotCheers.all.length)],
        );
      case RewardKind.fact:
        return LessonReward.fact(
          ChinaFacts.all[rng.nextInt(ChinaFacts.all.length)],
        );
    }
  }
}
