import 'dart:async';

import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

import '../services/mascot_service.dart';

/// A big, always-visible "podium" view of the companion — the primary way
/// to see it in 3D, embedded directly in the wardrobe rather than tucked
/// behind a button. No touch controls: earlier versions used
/// ManipulatorType.ORBIT, but embedded inside the wardrobe's scrollable
/// list, a drag meant to orbit the camera just as often got stolen by the
/// list's own scroll gesture instead, reading as "the camera is broken."
/// A slow automatic spin shows the model from every angle without needing
/// any gesture to fight over.
class Mascot3DStage extends StatefulWidget {
  final MascotCharacter character;
  final int outfitIndex;
  final double height;

  const Mascot3DStage({
    super.key,
    required this.character,
    required this.outfitIndex,
    this.height = 260,
  });

  @override
  State<Mascot3DStage> createState() => _Mascot3DStageState();
}

class _Mascot3DStageState extends State<Mascot3DStage> {
  Timer? _spinTimer;
  ThermionViewer? _viewer;
  ThermionAsset? _asset;
  Matrix4? _baseTransform;
  double _angle = 0;

  // Which outfit's prop (if any) is currently attached, and the loaded
  // prop asset itself — tracked so a later outfit switch can swap just
  // the prop instead of tearing down the whole stage. Recreating the
  // Filament engine per outfit tap (the previous approach, keyed on
  // outfitIndex) raced Thermion's "only one viewer can be active at a
  // time" constraint on rapid switches and is the likely source of the
  // crash-on-outfit-change report.
  int? _attachedOutfitIndex;
  ThermionAsset? _propAsset;

  // See mobile/lib/components/mascot_3d_companion.dart for why these are
  // cached rather than built fresh in build() — ViewerWidget throws if any
  // property other than manipulatorType differs across rebuilds, and
  // neither Vector3 nor DirectLight override value equality.
  //
  // Framed against the "toy character on a podium" reference look: the
  // character standing upright and filling most of the frame, seen from
  // roughly eye level. The previous (0.4, 1.15, 2.6) was 2.87 units out
  // and 24° above a model that's only 1 unit tall, which left it filling
  // 39% of the frame height and viewed steeply from above — small, and
  // foreshortened enough to read as "leaning over" rather than standing.
  //
  // thermion never sets a lens itself, so the camera keeps Filament's
  // default 28mm (thermion's kFocalLength) against a 24mm sensor height —
  // a fixed 2*atan(12/28) = 46.4° vertical FOV, which setViewport
  // preserves across resizes since it reads getFocalLength() back. So the
  // visible height at the origin is 2*d*tan(23.2°) and the fraction of the
  // frame the character fills is just height/that. d = 1.62 puts it at
  // 70%, and 0.23 of height gives an 8° downward tilt. Verified by
  // projecting the posed mesh through this exact camera at every 30° of
  // the auto-spin: worst-case margin to the frame edge is 17%.
  late final _cameraPosition = Vector3(0, 0.23, 1.60);
  late final _keyLight = DirectLight.sun(
    direction: Vector3(-0.6, -1, -0.2),
    intensity: MascotService.keyLightIntensity,
  );
  late final _background = Theme.of(context).colorScheme.surfaceContainerHighest;

  @override
  void dispose() {
    _spinTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(Mascot3DStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The character can't change without a new widget (a new assetPath,
    // which ViewerWidget can't apply in place — see the key in
    // mascot_wardrobe_screen.dart). Only the outfit can change here, so
    // just swap the prop rather than reloading the whole model.
    if (widget.outfitIndex != oldWidget.outfitIndex) {
      unawaited(_updateProp());
    }
  }

  Future<void> _updateProp() async {
    final asset = _asset;
    final viewer = _viewer;
    if (asset == null || viewer == null) return;
    if (_attachedOutfitIndex == widget.outfitIndex) return;

    final oldProp = _propAsset;
    _propAsset = null;
    _attachedOutfitIndex = null;
    if (oldProp != null) {
      await viewer.destroyAsset(oldProp);
    }
    if (!mounted) return;
    await _attachProp(viewer, asset);
  }

  /// Reloads the IBL that ViewerWidget already loaded, at the intensity the
  /// cartoon look needs — see MascotService.iblIntensity for the ratio and
  /// why there are no fill lights any more. ViewerWidget hardcodes
  /// `loadIbl(path)`, taking thermion's 30000 default, which against the
  /// old 400000 of stacked direct lights left ambient at barely a
  /// thirteenth of the total: the model came out contrasty and muddy
  /// rather than flat and toy-like. `loadIbl` defaults to
  /// `destroyExisting: true` and this runs after _configure()'s own load,
  /// so it replaces rather than stacks.
  Future<void> _onViewerAvailable(ThermionViewer viewer) async {
    await viewer.loadIbl(
      MascotService.iblAsset,
      intensity: MascotService.iblIntensity,
    );
  }

  Future<void> _onAssetLoaded(ThermionViewer viewer, ThermionAsset asset) async {
    _viewer = viewer;
    _asset = asset;
    // Without this, the model just sits in its raw glTF bind pose — for
    // this rig that's a T-pose (arms straight out to the sides), not a
    // standing idle. Same call the lesson companion already makes; the
    // stage was missing it.
    await asset.addAnimationComponent();
    await asset.playGltfAnimation(
      MascotService.idleAnimationIndex(widget.character),
      loop: true,
    );
    // ViewerWidget's transformToUnitCube flag doesn't actually do anything
    // (see MascotModelBounds) — without this the model renders at its raw
    // export scale, several units tall, putting the camera almost inside
    // its legs. Scale by real measured height and recenter so the
    // character's vertical midpoint sits at the origin, matching what
    // `initialCameraPosition` (which always looks at the origin) expects.
    final bounds = MascotService.modelBounds(widget.character);
    final scale = 1.0 / bounds.height;
    _baseTransform = Matrix4.compose(
      Vector3(0, -scale * bounds.centerY, -scale * bounds.centerZ),
      Quaternion.identity(),
      Vector3.all(scale),
    );
    await asset.setTransform(_baseTransform!);
    _spinTimer = Timer.periodic(const Duration(milliseconds: 40), (_) async {
      final asset = _asset;
      final base = _baseTransform;
      if (!mounted || asset == null || base == null) return;
      _angle += 0.012;
      await asset.setTransform(Matrix4.rotationY(_angle) * base);
    });

    await _attachProp(viewer, asset);
  }

  /// Attaches the currently-equipped outfit's 3D prop, if it has one —
  /// same pilot mechanism as before, just now shared between the initial
  /// load and a later outfit switch (see [_updateProp]).
  Future<void> _attachProp(ThermionViewer viewer, ThermionAsset asset) async {
    final prop = MascotService.propForOutfit(widget.character, widget.outfitIndex);
    if (prop == null) {
      _attachedOutfitIndex = widget.outfitIndex;
      return;
    }
    try {
      final boneNames = await asset.getBoneNames();
      final boneIndex = boneNames.indexOf(prop.boneName);
      if (boneIndex == -1) return;
      final bones = await asset.getBones();
      final boneEntity = bones[boneIndex];

      final propAsset = await viewer.loadGltf(prop.asset);
      await viewer.app.setParent(propAsset.entity, boneEntity);
      await propAsset.setTransform(
        Matrix4.compose(
          Vector3(prop.offsetX, prop.offsetY, prop.offsetZ),
          Quaternion.identity(),
          Vector3.all(prop.scale),
        ),
      );
      if (!mounted) return;
      _propAsset = propAsset;
      _attachedOutfitIndex = widget.outfitIndex;
    } catch (_) {
      // First attempt at bone attachment — better to show the mascot
      // without its prop than crash the whole stage over it.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: ViewerWidget(
          assetPath: MascotService.model3DAsset(widget.character),
          initialCameraPosition: _cameraPosition,
          manipulatorType: ManipulatorType.NONE,
          directLight: _keyLight,
          // Direct lights alone leave any face they don't hit fully black
          // (Filament has no ambient term without one) — hence the
          // "dark/see-through-looking patches" once the model was finally
          // framed correctly. It only supplies ambient fill, independent
          // of the `background` color below (only skyboxPath would
          // conflict with that). Loaded here so ViewerWidget has one from
          // the first frame; _onViewerAvailable immediately reloads it at
          // the intensity the flat cartoon look actually needs.
          iblPath: MascotService.iblAsset,
          // A no-op in this version — see the comment in _onAssetLoaded,
          // which does the equivalent normalization itself. Left false
          // (rather than omitted) so it doesn't look like an oversight.
          transformToUnitCube: false,
          background: _background,
          // This widget is recreated (via a character-only key, in
          // mascot_wardrobe_screen.dart) when the character changes,
          // since ViewerWidget can't change its assetPath in place — so
          // the old engine needs to actually be torn down each time
          // rather than leaking. An outfit change alone doesn't recreate
          // it — see didUpdateWidget.
          destroyEngineOnUnload: true,
          onViewerAvailable: _onViewerAvailable,
          onAssetLoaded: _onAssetLoaded,
        ),
      ),
    );
  }
}
