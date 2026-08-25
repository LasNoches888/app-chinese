import '../models/user_stats.dart';
import 'xp_service.dart';

/// How the mascot should look mid-lesson, right after an answer.
enum MascotReaction { idle, correct, incorrect }

/// Picks which mascot still fits the moment. Kept separate from the widget
/// that renders it so the picking logic is plain and testable without a
/// widget tree.
///
/// The panda art is a set of themed outfits (backpacker, chef, kung fu,
/// pilot...), not a baby-to-adult size progression, so "growing" is
/// modelled as unlocking a fancier outfit as the level goes up rather than
/// a literal size change that the art can't actually back up.
class MascotService {
  MascotService._();

  static const _idle = 'assets/mascot/panda_02.png';
  static const _correct = 'assets/mascot/panda_04.png';
  static const _incorrect = 'assets/mascot/panda_17.png';
  static const _sleeping = 'assets/mascot/panda_14.png';
  static const _starterOutfit = 'assets/mascot/panda_02.png';

  /// Highest-level tier first, so the loop in [homeAsset] can return on the
  /// first match.
  static const _outfitsByLevel = [
    (level: 20, asset: 'assets/mascot/panda_33.png'), // pilot
    (level: 16, asset: 'assets/mascot/panda_27.png'), // samurai
    (level: 13, asset: 'assets/mascot/panda_28.png'), // chef
    (level: 10, asset: 'assets/mascot/panda_22.png'), // kung fu
    (level: 7, asset: 'assets/mascot/panda_21.png'), // bubble tea
    (level: 5, asset: 'assets/mascot/panda_17.png'), // reading glasses
    (level: 3, asset: 'assets/mascot/panda_05.png'), // star badge
  ];

  /// How long a stale streak gets before the mascot reads as "missing you"
  /// rather than just quietly waiting.
  static const _lonelyAfter = Duration(days: 2);

  static String reactionAsset(MascotReaction reaction) => switch (reaction) {
    MascotReaction.correct => _correct,
    MascotReaction.incorrect => _incorrect,
    MascotReaction.idle => _idle,
  };

  /// The home-screen companion: asleep once the learner has been away a
  /// couple of days, otherwise wearing whatever it has earned so far.
  static String homeAsset(UserStats stats, {DateTime? now}) {
    final last = stats.lastActivityDate;
    final effectiveNow = now ?? DateTime.now();
    if (last != null && effectiveNow.difference(last) >= _lonelyAfter) {
      return _sleeping;
    }
    final level = XpService.levelForXp(stats.totalXp);
    for (final tier in _outfitsByLevel) {
      if (level >= tier.level) return tier.asset;
    }
    return _starterOutfit;
  }
}
