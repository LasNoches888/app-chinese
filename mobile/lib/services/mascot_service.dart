import '../models/user_stats.dart';
import 'xp_service.dart';

/// A moment worth reacting to with the 3D companion mid-lesson.
enum Mascot3DCue { hello, correct, incorrect }

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

/// A 3D prop worn by real bone attachment, for outfits that have one.
/// Coordinates are local to the target bone, in the character rig's own
/// native units — Thermion's whole-asset unit-cube normalization scales
/// the bone hierarchy (and anything parented under it) uniformly, so a
/// prop parented to a bone stays correctly sized without needing to know
/// that scale factor itself. Only one outfit has a prop so far: this is
/// a pilot for the bone-attachment mechanism (see entities.mdx's
/// `setParent` — there's no dedicated "equip" API) before building out
/// the rest, so the exact offset/scale below is a first guess, not a
/// calibrated fit — expect it to need adjustment once seen on a device.
class Mascot3DProp {
  final String asset;
  final String boneName;
  final double offsetX;
  final double offsetY;
  final double offsetZ;
  final double scale;

  const Mascot3DProp({
    required this.asset,
    required this.boneName,
    this.offsetX = 0,
    this.offsetY = 0,
    this.offsetZ = 0,
    this.scale = 1,
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

  /// Only the panda's reading-glasses outfit (index 2) has a 3D prop so
  /// far — see [Mascot3DProp].
  static const _propsByOutfit = {
    MascotCharacter.panda: {
      2: Mascot3DProp(
        asset: 'assets/mascot_3d/props/glasses.glb',
        boneName: 'Head',
        offsetY: 0.3,
        offsetZ: 0.15,
        scale: 0.7,
      ),
    },
  };

  static Mascot3DProp? propForOutfit(MascotCharacter character, int outfitIndex) =>
      _propsByOutfit[character]?[outfitIndex];

  static List<MascotOutfit> unlockedOutfits(
    MascotCharacter character,
    int level,
  ) => outfitsFor(character).where((o) => o.requiredLevel <= level).toList();

  static const _idleAnimationIndex = {
    MascotCharacter.panda: 0,
    MascotCharacter.pug: 0,
  };

  /// One-shot glTF animation clips played mid-lesson before falling back to
  /// idle. The panda's clips came from Quaternius's "Universal Animation
  /// Library" with their names stripped by the FBX→GLB conversion, so these
  /// were picked by eye from mid-clip stills, not from a names list — see
  /// assets/mascot_3d/SOURCES.md. The pug's rig only has Idle and Jump, so
  /// every cue reuses Jump (or Idle for "incorrect", since a jump reads as
  /// upbeat regardless of context and a wrong answer shouldn't).
  static const _cueAnimationIndex = {
    MascotCharacter.panda: {
      Mascot3DCue.hello: 5, // arm raised — reads as a wave
      Mascot3DCue.correct: 22, // the longest clip (80 frames) — a dance
      Mascot3DCue.incorrect: 6, // head tilted, hand near face — "thinking"
    },
    MascotCharacter.pug: {
      Mascot3DCue.hello: 1,
      Mascot3DCue.correct: 1,
      Mascot3DCue.incorrect: 0,
    },
  };

  /// How long each cue's clip actually runs (measured in Blender: frame
  /// count ÷ 24fps), plus a little headroom — the panda's "correct" clip
  /// alone is 3.33s, well past a one-size-fits-all wait. Getting this wrong
  /// either cuts a clip off mid-motion or leaves the model frozen on its
  /// last frame before [MascotService.idleAnimationIndex] takes back over.
  static const _cueDuration = {
    MascotCharacter.panda: {
      Mascot3DCue.hello: Duration(milliseconds: 1000), // clip: 0.77s
      Mascot3DCue.correct: Duration(milliseconds: 3600), // clip: 3.33s
      Mascot3DCue.incorrect: Duration(milliseconds: 1900), // clip: 1.67s
    },
    MascotCharacter.pug: {
      Mascot3DCue.hello: Duration(milliseconds: 1700), // clip (Jump): 1.5s
      Mascot3DCue.correct: Duration(milliseconds: 1700), // clip (Jump): 1.5s
      // "incorrect" plays Idle once, same clip idle already loops — the
      // switch back is a no-op visually, so this just needs to be short.
      Mascot3DCue.incorrect: Duration(milliseconds: 600),
    },
  };

  static int idleAnimationIndex(MascotCharacter character) =>
      _idleAnimationIndex[character]!;

  static int cueAnimationIndex(MascotCharacter character, Mascot3DCue cue) =>
      _cueAnimationIndex[character]![cue]!;

  static Duration cueDuration(MascotCharacter character, Mascot3DCue cue) =>
      _cueDuration[character]![cue]!;

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
