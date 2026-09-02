import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

import '../services/mascot_service.dart';
import 'mascot_3d_instance.dart';

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
  // What loadGltf returned, kept only so it can be destroyed; and the
  // instance every animation, bone and transform call has to target
  // instead — see poseTarget in mascot_3d_instance.dart.
  ThermionAsset? _asset;
  ThermionAsset? _posed;
  Camera? _camera;
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

  // Bumped on every character load so a load that's been superseded (two
  // quick taps between panda and pug) can notice mid-flight and drop what
  // it was building instead of racing the newer one into _asset.
  int _loadGeneration = 0;

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

  /// Horizontal distance from the origin the auto-spin orbits at — taken
  /// straight from [_cameraPosition] so the spin can never drift away
  /// from the framing that was measured for it.
  late final _orbitRadius = math.sqrt(
    _cameraPosition.x * _cameraPosition.x +
        _cameraPosition.z * _cameraPosition.z,
  );
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
    // Both a character and an outfit change are now handled in place, on
    // the one viewer this widget creates and keeps — see _loadCharacter.
    if (widget.character != oldWidget.character) {
      unawaited(_loadCharacter());
    } else if (widget.outfitIndex != oldWidget.outfitIndex) {
      unawaited(_updateProp());
    }
  }

  Future<void> _updateProp() async {
    // The instance, not the asset — _attachProp reads bones off it.
    final asset = _posed;
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

  /// Sets the IBL to the intensity the cartoon look needs (ViewerWidget
  /// hardcodes thermion's 30000 default — see MascotService.iblIntensity),
  /// then loads the character itself. `loadIbl` defaults to
  /// `destroyExisting: true` and this runs after _configure()'s own load,
  /// so it replaces rather than stacks.
  Future<void> _onViewerAvailable(ThermionViewer viewer) async {
    _viewer = viewer;
    _camera = await viewer.getActiveCamera();
    await viewer.loadIbl(
      MascotService.iblAsset,
      intensity: MascotService.iblIntensity,
    );
    await _loadCharacter();
    _startSpin();
  }

  /// Orbits the camera around the model rather than rotating the model.
  ///
  /// This used to spin the character itself, calling `asset.setTransform`
  /// 25 times a second. That is the one thing this widget did that the
  /// lesson companion — which sets a transform once and has rendered
  /// correctly throughout — never did, and it's why the podium showed a
  /// shredded mesh while the companion showed the same GLB intact at the
  /// same moment. This rig's root node is `CharacterArmature`, which is
  /// also the parent of the whole bone hierarchy, so writing its
  /// transform on a timer means overwriting the node the glTF animator is
  /// concurrently computing the skinning matrices from. Torn geometry
  /// with correct materials is exactly what losing that race looks like.
  ///
  /// Moving the model is never necessary here anyway: the camera always
  /// looks at the origin and the model is normalized to sit there, so
  /// orbiting the eye gives the identical picture while leaving the
  /// asset's transform to the animation system alone.
  void _startSpin() {
    _spinTimer ??= Timer.periodic(const Duration(milliseconds: 40), (_) async {
      final camera = _camera;
      if (!mounted || camera == null) return;
      _angle += 0.012;
      await camera.lookAt(
        Vector3(
          _orbitRadius * math.sin(_angle),
          _cameraPosition.y,
          _orbitRadius * math.cos(_angle),
        ),
      );
    });
  }

  /// Swaps the model on the viewer this widget already has, rather than
  /// letting a new widget bring a whole new viewer with it.
  ///
  /// The character used to arrive through ViewerWidget's `assetPath`,
  /// which can't change once built, so the wardrobe keyed this widget on
  /// the character and a panda/pug tap replaced the whole thing — new
  /// widget, new viewer, new Filament resources. That was never really
  /// safe. It first showed up as a crash (the outgoing widget destroying
  /// the shared engine under the incoming one), and once that was fixed
  /// the same race surfaced instead as a shredded mesh: the outgoing
  /// viewer's teardown freeing GLB buffers the incoming viewer had
  /// already loaded and was drawing from. The lesson companion, which
  /// only ever builds one viewer, was fine throughout — which is the
  /// clearest evidence it's the recreation itself that's the problem.
  ///
  /// So this widget now owns the model's lifetime: one viewer for as long
  /// as the wardrobe is open, and a character change is a destroy plus a
  /// load on it — exactly what an outfit's prop swap already did.
  Future<void> _loadCharacter() async {
    final viewer = _viewer;
    if (viewer == null) return;
    final generation = ++_loadGeneration;

    final oldProp = _propAsset;
    final oldAsset = _asset;
    _propAsset = null;
    _asset = null;
    _posed = null;
    _attachedOutfitIndex = null;
    if (oldProp != null) await viewer.destroyAsset(oldProp);
    if (oldAsset != null) await viewer.destroyAsset(oldAsset);
    if (!mounted || generation != _loadGeneration) return;

    final asset = await viewer.loadGltf(
      MascotService.model3DAsset(widget.character),
    );
    if (!mounted || generation != _loadGeneration) {
      // Superseded while the GLB was loading — drop it rather than let it
      // become the visible model over the newer character's.
      await viewer.destroyAsset(asset);
      return;
    }
    _asset = asset;
    // Animation, bones and the pose transform all have to go to the
    // asset's instance, not the asset — see poseTarget. Mixing the two is
    // what left the skeleton undriven and the mesh shredded.
    final posed = await poseTarget(asset);
    _posed = posed;

    // Without this, the model just sits in its raw glTF bind pose — for
    // this rig that's a T-pose (arms straight out to the sides), not a
    // standing idle.
    await posed.addAnimationComponent();
    await posed.playGltfAnimation(
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
    // Set once and never touched again — the spin is the camera's job now,
    // see _startSpin.
    await posed.setTransform(
      Matrix4.compose(
        Vector3(0, -scale * bounds.centerY, -scale * bounds.centerZ),
        Quaternion.identity(),
        Vector3.all(scale),
      ),
    );

    await _attachProp(viewer, posed);
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
          // No assetPath on purpose: it can't change once the widget is
          // built, which is what forced a whole new viewer per character.
          // _loadCharacter loads and swaps the model itself instead.
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
          // A no-op in this version — see the comment in _loadCharacter,
          // which does the equivalent normalization itself. Left false
          // (rather than omitted) so it doesn't look like an oversight.
          transformToUnitCube: false,
          background: _background,
          // Deliberately NOT destroyEngineOnUnload. That flag reads like
          // "clean up after this widget", but ViewerWidget implements it
          // as `FilamentApp.instance!.destroy()` — the process-wide
          // singleton, not this widget's engine. Setting it here (this
          // was the only place in the app that did) meant leaving the
          // wardrobe tore down the engine for everything else, so the
          // lesson companion afterwards rendered an empty circle.
          //
          // Nothing leaks by leaving it off: _performTearDown always
          // disposes this widget's own viewer and its texture regardless
          // of the flag. Only the shared engine survives, which is what
          // you want when 3D appears on more than one screen.
          onViewerAvailable: _onViewerAvailable,
        ),
      ),
    );
  }
}
