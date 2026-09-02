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

/// A model's real, measured bounds (Y-up, from the mesh's bind pose —
/// see assets/mascot_3d/SOURCES.md), used to normalize it to roughly a
/// 1-unit-tall character centered at the origin.
///
/// ViewerWidget's own `transformToUnitCube: true` looks like it should do
/// this, but it's a documented no-op in thermion_flutter 0.5.0 (checked
/// the widget's source directly: the flag is stored and compared in
/// `didUpdateWidget`, but `_configure()` never actually calls
/// `transformToUnitCube()` on the loaded asset) — so both 3D widgets
/// apply this themselves in onAssetLoaded instead of trusting that flag.
/// Height, not the model's overall bounding-box size, is what's used to
/// pick the scale: a T-pose's arm-span can be wider than the character is
/// tall, and normalizing to the widest axis would make an idle (arms-down)
/// pose render far smaller than intended — height stays the same in
/// either pose.
class MascotModelBounds {
  final double height;
  final double centerY;
  final double centerZ;

  const MascotModelBounds({
    required this.height,
    required this.centerY,
    required this.centerZ,
  });
}

/// A 3D prop worn by real bone attachment, for outfits that have one.
/// Coordinates are local to the target bone, in the character rig's own
/// native units — [MascotModelBounds]-driven normalization (see above)
/// scales the whole bone hierarchy (and anything parented under it)
/// uniformly, so a prop parented to a bone stays correctly sized without
/// needing to know that scale factor itself. Only one outfit has a prop so
/// far: this is a pilot for the bone-attachment mechanism (see
/// entities.mdx's `setParent` — there's no dedicated "equip" API) before
/// building out the rest, so the exact offset/scale below is a first
/// guess, not a calibrated fit — expect it to need adjustment once seen on
/// a device (doubly so now that the base model's own scale was wrong until
/// this fix).
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

  /// thermion's own generic studio IBL. Supplies the ambient term Filament
  /// otherwise has none of — see assets/mascot_3d/SOURCES.md.
  static const iblAsset = 'assets/mascot_3d/env/default_env_ibl.ktx';

  /// The mascot is meant to read as a flat, toy-like cartoon (the look
  /// Subway Surfers and friends get by baking shading into the texture and
  /// drawing it unlit). This atlas has no baked shading, so going fully
  /// unlit isn't an option: the panda's arms and torso are the same navy
  /// `#403c57`, and with no shading at all they merge into one shape and
  /// the muzzle disappears off the face. What works instead is keeping
  /// shading but flattening it — rendering the model across the range
  /// showed the character stops reading somewhere past 80% ambient and
  /// starts looking like a lit 3D object rather than a cartoon below 60%.
  ///
  /// A single key light rather than the old key-plus-three-fills: filling
  /// from every side is exactly what an indirect light already does, and
  /// stacking direct lights to fake it was what made the old setup both
  /// contrasty and hard to reason about.
  ///
  /// These two numbers are NOT in comparable units, which is the trap
  /// here. A first pass at this treated both as lux and set ibl=180000
  /// against key=50000, reasoning that the 230000 total was below the old
  /// setup's 430000 and would therefore be no brighter. On device it came
  /// out badly overexposed — the navy washed to pale lavender and the
  /// sash to pale yellow. A directional light's intensity is the
  /// illuminance it casts from one direction; an IBL's scales an
  /// environment lighting the model from every direction at once, so it
  /// buys far more total light per unit. Treat raising `iblIntensity` as
  /// a much bigger change than the same delta on the key light, and
  /// change it in small steps.
  ///
  /// So the ambient share is still the thing being tuned — the darkest
  /// lit surface wants to sit near 78% of the brightest — but the level
  /// is now anchored to the old setup's exposure, which was correct even
  /// though its contrast wasn't: this keeps the IBL close to the 30000 it
  /// used to run at and takes the flattening out of the direct side
  /// instead, where the units are known.
  static const iblIntensity = 40000.0;
  static const keyLightIntensity = 110000.0;

  /// The 3D model for a companion's base look — a single glTF/GLB per
  /// character, not yet split per outfit (see assets/mascot_3d/SOURCES.md
  /// for provenance).
  static String model3DAsset(MascotCharacter character) => switch (character) {
    MascotCharacter.panda => 'assets/mascot_3d/panda.glb',
    MascotCharacter.pug => 'assets/mascot_3d/pug.glb',
  };

  /// Measured directly off each GLB's mesh vertices (bind pose) — see
  /// [MascotModelBounds] for why this exists, and
  /// `tool/mascot3d/check_framing.py`, which re-measures them from the GLB
  /// and fails if these drift.
  ///
  /// The pug's numbers were wrong until they were checked that way: height
  /// 1.052 against a real 2.659, and every figure short by the same factor
  /// of 2.53, so they'd clearly been taken from a differently-scaled copy
  /// of the model. That left it scaled by 1/1.052 instead of 1/2.659 —
  /// still two and a half units tall against a camera 1.6 units out, i.e.
  /// the camera inside the dog, which is exactly how it looked.
  static const _modelBounds = {
    MascotCharacter.panda: MascotModelBounds(
      height: 3.334,
      centerY: 1.665,
      centerZ: -0.204,
    ),
    MascotCharacter.pug: MascotModelBounds(
      height: 2.659,
      centerY: 1.312,
      centerZ: 0.282,
    ),
  };

  static MascotModelBounds modelBounds(MascotCharacter character) =>
      _modelBounds[character]!;

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
    MascotCharacter.panda: 10,
    MascotCharacter.pug: 0,
  };

  /// One-shot glTF animation clips played mid-lesson before falling back to
  /// idle. The panda's clips are Quaternius's "Universal Animation Library"
  /// — the GLB's own animations array has them cleanly named (Idle, Wave,
  /// No, ...), but an earlier pass here inspected the rig in Blender
  /// instead, whose glTF importer renames every action to a generic
  /// "Chara.NNN" on a name-length collision — so these were picked by eye
  /// against that scrambled order rather than the real one. Re-derived by
  /// reading the glTF JSON's `animations[].name` directly — see
  /// assets/mascot_3d/SOURCES.md. The pug's rig only has Idle and Jump, so
  /// every cue reuses Jump (or Idle for "incorrect", since a jump reads as
  /// upbeat regardless of context and a wrong answer shouldn't).
  ///
  /// "correct" used to be clip 23, chosen only for being the longest at
  /// 3.37s. Measuring how far the skinned mesh actually travels over each
  /// clip (peak vertex range, against a model normalized to 1 unit tall)
  /// showed why that read as the mascot doing nothing: clip 23 peaks at
  /// 0.158, barely above Idle's own 0.062, so a correct answer bought
  /// three and a half seconds of near-stillness. Jump peaks at 0.630 and
  /// is unambiguous as celebration. Wave (0.895) is the only clip with
  /// both big motion and real length, and it's already "hello". Punch
  /// (0.969) and Sword (0.871) move more than Jump but read as aggression
  /// — wrong note for a child getting an answer right.
  static const _cueAnimationIndex = {
    MascotCharacter.panda: {
      Mascot3DCue.hello: 28, // "Wave"
      Mascot3DCue.correct: 11, // "Jump"
      Mascot3DCue.incorrect: 14, // "No"
    },
    MascotCharacter.pug: {
      Mascot3DCue.hello: 1,
      Mascot3DCue.correct: 1,
      Mascot3DCue.incorrect: 0,
    },
  };

  /// How long each cue's clip actually runs (read from the glTF's own
  /// animation sampler timings), plus a little headroom — the panda's
  /// "correct" clip alone is 3.37s, well past a one-size-fits-all wait.
  /// Getting this wrong either cuts a clip off mid-motion or leaves the
  /// model frozen on its last frame before
  /// [MascotService.idleAnimationIndex] takes back over.
  static const _cueDuration = {
    MascotCharacter.panda: {
      Mascot3DCue.hello: Duration(milliseconds: 1950), // clip: 1.7s
      // Jump is short and snappy; the speech bubble stays up for its own
      // 4s regardless, so the mascot settling back to idle well before
      // then is fine — better than holding a last frame.
      Mascot3DCue.correct: Duration(milliseconds: 550), // clip (Jump): 0.3s
      Mascot3DCue.incorrect: Duration(milliseconds: 1950), // clip: 1.7s
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
