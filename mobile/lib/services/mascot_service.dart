import '../models/user_stats.dart';
import 'xp_service.dart';

/// A moment worth reacting to with the companion mid-lesson.
enum MascotCue { hello, correct, incorrect }

/// The animal a learner has picked as their home-screen companion.
enum MascotCharacter {
  panda('panda'),
  pug('pug'),
  owl('owl');

  final String dbValue;
  const MascotCharacter(this.dbValue);

  static MascotCharacter fromDb(String value) =>
      values.firstWhere((c) => c.dbValue == value, orElse: () => panda);
}

/// One equippable look for a [MascotCharacter]: an asset, a level gate, and
/// a display-string key ([Strings]/[AppSettings.t]).
class MascotOutfit {
  final int index;
  final String asset;
  final String labelKey;
  final int requiredLevel;

  const MascotOutfit({
    required this.index,
    required this.asset,
    required this.labelKey,
    required this.requiredLevel,
  });
}

/// Picks which mascot still fits the moment, and owns the outfit catalog
/// each character can be dressed in. Kept separate from the widgets that
/// render it so the picking logic is plain and testable without a widget
/// tree.
///
/// The panda art is a set of themed outfits (backpacker, chef, kung fu,
/// pilot...), not a baby-to-adult size progression, so "growing" is
/// modelled as unlocking a fancier outfit as the level goes up rather than
/// a literal size change that the art can't actually back up.
///
/// The pug and owl each ship with a single look for now — there's no outfit
/// set drawn for either yet.
class MascotService {
  MascotService._();

  /// Highest-level tier first, so [effectiveOutfit] can return on the first
  /// match when falling back.
  static const pandaOutfits = [
    MascotOutfit(
      index: 0,
      asset: 'assets/mascot/panda_02.png',
      labelKey: 'outfitStarter',
      requiredLevel: 1,
    ),
    MascotOutfit(
      index: 1,
      asset: 'assets/mascot/panda_05.png',
      labelKey: 'outfitStarBadge',
      requiredLevel: 3,
    ),
    MascotOutfit(
      index: 2,
      asset: 'assets/mascot/panda_17.png',
      labelKey: 'outfitReadingGlasses',
      requiredLevel: 5,
    ),
    MascotOutfit(
      index: 3,
      asset: 'assets/mascot/panda_21.png',
      labelKey: 'outfitBubbleTea',
      requiredLevel: 7,
    ),
    MascotOutfit(
      index: 4,
      asset: 'assets/mascot/panda_22.png',
      labelKey: 'outfitKungFu',
      requiredLevel: 10,
    ),
    MascotOutfit(
      index: 5,
      asset: 'assets/mascot/panda_28.png',
      labelKey: 'outfitChef',
      requiredLevel: 13,
    ),
    MascotOutfit(
      index: 6,
      asset: 'assets/mascot/panda_27.png',
      labelKey: 'outfitSamurai',
      requiredLevel: 16,
    ),
    MascotOutfit(
      index: 7,
      asset: 'assets/mascot/panda_33.png',
      labelKey: 'outfitPilot',
      requiredLevel: 20,
    ),
  ];

  /// The pug's one look, now drawn to match the panda's flat "die-cut
  /// sticker" art style instead of reusing a portrait from the removed
  /// hearts indicator.
  static const pugOutfits = [
    MascotOutfit(
      index: 0,
      asset: 'assets/mascot/pug_01.png',
      labelKey: 'outfitPugDefault',
      requiredLevel: 1,
    ),
  ];

  /// The owl's one look — same "ships with a single look until a real
  /// outfit set is drawn" precedent as the pug above.
  static const owlOutfits = [
    MascotOutfit(
      index: 0,
      asset: 'assets/mascot/owl_01.png',
      labelKey: 'outfitOwlDefault',
      requiredLevel: 1,
    ),
  ];

  /// The "missing you" still shown after a stale streak, per character.
  /// The pug has no dedicated sleepy pose, so this reuses the desaturated,
  /// low-health portrait — it already reads as "not doing great". The owl
  /// has no entry at all yet: [homeAsset] falls back to its normal outfit
  /// asset for a lonely owl rather than crashing, the same way it would for
  /// any future character before dedicated sleepy art exists.
  static const _sleepingAssets = {
    MascotCharacter.panda: 'assets/mascot/panda_14.png',
    MascotCharacter.pug: 'assets/mascot/hearts/pug_1.png',
  };

  /// How long a stale streak gets before the mascot reads as "missing you"
  /// rather than just quietly waiting.
  static const _lonelyAfter = Duration(days: 2);

  static List<MascotOutfit> outfitsFor(MascotCharacter character) =>
      switch (character) {
        MascotCharacter.panda => pandaOutfits,
        MascotCharacter.pug => pugOutfits,
        MascotCharacter.owl => owlOutfits,
      };

  static List<MascotOutfit> unlockedOutfits(
    MascotCharacter character,
    int level,
  ) => outfitsFor(character).where((o) => o.requiredLevel <= level).toList();

  /// An [equippedIndex] of -1 means "nothing explicitly picked yet" — the
  /// companion should auto-follow the highest outfit the current level has
  /// earned, same as it always has, until the learner opens the wardrobe
  /// and picks one. A non-negative index is honoured as long as it's still
  /// unlocked (it can stop being valid across a character switch, or in
  /// theory a level dropping); otherwise this falls back the same way.
  static MascotOutfit effectiveOutfit(
    MascotCharacter character,
    int equippedIndex,
    int level,
  ) {
    final outfits = outfitsFor(character);
    if (equippedIndex >= 0) {
      final equipped = outfits
          .where((o) => o.index == equippedIndex)
          .firstOrNull;
      if (equipped != null && equipped.requiredLevel <= level) return equipped;
    }
    final unlocked = unlockedOutfits(character, level);
    return unlocked.isNotEmpty ? unlocked.last : outfits.first;
  }

  /// The home-screen companion: asleep once the learner has been away a
  /// couple of days, otherwise wearing whatever [effectiveOutfit] resolves
  /// to. A character with no dedicated sleepy pose in [_sleepingAssets]
  /// (currently the owl) just stays in its normal outfit instead of
  /// crashing on a missing entry.
  static String homeAsset(UserStats stats, {DateTime? now}) {
    final character = MascotCharacter.fromDb(stats.mascotCharacter);
    final last = stats.lastActivityDate;
    final effectiveNow = now ?? DateTime.now();
    if (last != null && effectiveNow.difference(last) >= _lonelyAfter) {
      final sleepy = _sleepingAssets[character];
      if (sleepy != null) return sleepy;
    }
    final level = XpService.levelForXp(stats.totalXp);
    return effectiveOutfit(character, stats.equippedOutfit, level).asset;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
