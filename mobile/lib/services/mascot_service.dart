import '../models/user_stats.dart';
import 'xp_service.dart';

/// How the mascot should look mid-lesson, right after an answer. Only the
/// panda has stills for this — see [MascotService.reactionAsset].
enum MascotReaction { idle, correct, incorrect }

/// The animal a learner has picked as their home-screen companion.
enum MascotCharacter {
  panda('panda'),
  pug('pug');

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
/// The pug only has the six portraits left over from the removed hearts
/// indicator (full health down to spent) — there's no outfit set for it
/// yet, so it ships with a single look until new art exists.
class MascotService {
  MascotService._();

  static const _idle = 'assets/mascot/panda_02.png';
  static const _correct = 'assets/mascot/panda_04.png';
  static const _incorrect = 'assets/mascot/panda_17.png';

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

  /// Reuses the least-damaged of the old hearts portraits as the pug's one
  /// look, until a real outfit set is drawn for it.
  static const pugOutfits = [
    MascotOutfit(
      index: 0,
      asset: 'assets/mascot/hearts/pug_5.png',
      labelKey: 'outfitPugDefault',
      requiredLevel: 1,
    ),
  ];

  /// The "missing you" still shown after a stale streak, per character.
  /// The pug has no dedicated sleepy pose, so this reuses the desaturated,
  /// low-health portrait — it already reads as "not doing great".
  static const _sleepingAssets = {
    MascotCharacter.panda: 'assets/mascot/panda_14.png',
    MascotCharacter.pug: 'assets/mascot/hearts/pug_1.png',
  };

  /// How long a stale streak gets before the mascot reads as "missing you"
  /// rather than just quietly waiting.
  static const _lonelyAfter = Duration(days: 2);

  /// The 3D model for a companion's base look — a single glTF/GLB per
  /// character, not yet split per outfit (see assets/mascot_3d/SOURCES.md
  /// for provenance).
  static String model3DAsset(MascotCharacter character) => switch (character) {
    MascotCharacter.panda => 'assets/mascot_3d/panda.glb',
    MascotCharacter.pug => 'assets/mascot_3d/pug.glb',
  };

  static List<MascotOutfit> outfitsFor(MascotCharacter character) =>
      switch (character) {
        MascotCharacter.panda => pandaOutfits,
        MascotCharacter.pug => pugOutfits,
      };

  static List<MascotOutfit> unlockedOutfits(
    MascotCharacter character,
    int level,
  ) => outfitsFor(character).where((o) => o.requiredLevel <= level).toList();

  static String reactionAsset(MascotReaction reaction) => switch (reaction) {
    MascotReaction.correct => _correct,
    MascotReaction.incorrect => _incorrect,
    MascotReaction.idle => _idle,
  };

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
  /// to.
  static String homeAsset(UserStats stats, {DateTime? now}) {
    final character = MascotCharacter.fromDb(stats.mascotCharacter);
    final last = stats.lastActivityDate;
    final effectiveNow = now ?? DateTime.now();
    if (last != null && effectiveNow.difference(last) >= _lonelyAfter) {
      return _sleepingAssets[character]!;
    }
    final level = XpService.levelForXp(stats.totalXp);
    return effectiveOutfit(character, stats.equippedOutfit, level).asset;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
