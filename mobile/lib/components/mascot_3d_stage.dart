import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

import '../services/mascot_service.dart';
import 'mascot_3d_instance.dart';

/// A big, always-visible "podium" view of the companion — the primary way
/// to see it in 3D, embedded directly in the wardrobe rather than tucked
/// behind a button. Swipe sideways to turn it; see [_onDrag] for why the
/// gesture is horizontal-only rather than ManipulatorType.ORBIT.
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
  // frame the character fills is just height/that. d = 1.62 puts the panda
  // at 70%, and 0.23 of height gives an 8° downward tilt. Verified by
  // projecting the posed mesh through this exact camera at every 30° of
  // a full turn: worst-case margin to the frame edge is 17%.
  //
  // Only sets the STARTING distance ViewerWidget needs before this widget
  // can take over — that constructor argument can't change once built (see
  // build() below), unlike the live camera _lookFromAngle() drives, so this
  // is only really accurate for whichever character happens to be first.
  // [_orbitRadius] is what actually matters after that.
  late final _cameraPosition = Vector3(
    0,
    0.23,
    MascotService.stageCameraDistance(widget.character),
  );

  /// Horizontal distance from the origin the turntable orbits at.
  ///
  /// Deliberately NOT cached like [_cameraPosition] — it has to track
  /// [widget.character] across a switch, not just at construction. Sharing
  /// the panda's own 1.60 with the pug seemed fine from the couple of
  /// angles it was eyeballed at, but a pug is a quadruped, low and long
  /// nose-to-tail rather than roughly as wide as tall the way the panda
  /// stands, so at the rotations where that length faces across the frame
  /// instead of into it, 1.60 clips the edge by as much as 9% — never
  /// caught because nothing had swept a full turn on the pug specifically
  /// until it was. See MascotService.stageCameraDistance for the value
  /// this reads and how it was found the same way: sweeping every 15° of
  /// a full turn and requiring a positive margin at all of them.
  double get _orbitRadius => MascotService.stageCameraDistance(widget.character);
  late final _keyLight = DirectLight.sun(
    direction: Vector3(-0.6, -1, -0.2),
    intensity: MascotService.keyLightIntensity,
  );
  late final _background = Theme.of(context).colorScheme.surfaceContainerHighest;

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
  }

  /// Points the camera at the model from the current [_angle].
  ///
  /// Note this moves the camera, never the model. An earlier version
  /// turned the character itself by calling `asset.setTransform` on a
  /// timer, which meant overwriting the armature root the glTF animator
  /// computes its skinning matrices from, while it was doing so. Since the
  /// camera always looks at the origin and the model is normalized to sit
  /// there, orbiting the eye gives an identical picture and leaves the
  /// asset's transform alone.
  Future<void> _lookFromAngle() async {
    final camera = _camera;
    if (camera == null) return;
    await camera.lookAt(
      Vector3(
        _orbitRadius * math.sin(_angle),
        _cameraPosition.y,
        _orbitRadius * math.cos(_angle),
      ),
    );
  }

  /// Turntable drag: horizontal only, on purpose.
  ///
  /// An earlier version used ManipulatorType.ORBIT, and inside the
  /// wardrobe's scrolling list a drag meant to turn the model was as
  /// likely to be claimed by the list's own vertical drag recognizer,
  /// which read as "the camera is broken". Claiming only horizontal drags
  /// leaves vertical ones to the list, so the two gestures never compete:
  /// swipe sideways to turn the character, up and down to scroll.
  void _onDrag(DragUpdateDetails details) {
    // A full width of travel is a bit more than one full turn.
    _angle -= details.delta.dx * 0.012;
    unawaited(_lookFromAngle());
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
    // Set once and never touched again — turning the model is the
    // camera's job, see _onDrag.
    await posed.setTransform(
      Matrix4.compose(
        Vector3(0, -scale * bounds.centerY, -scale * bounds.centerZ),
        Quaternion.identity(),
        Vector3.all(scale),
      ),
    );

    await _attachProp(viewer, posed);
    // The orbit distance is per-character (MascotService.stageCameraDistance)
    // and _orbitRadius reads widget.character fresh, so a character switch
    // needs this re-run too — not just the very first load — or the camera
    // stays at the OLD character's distance until the next manual drag.
    await _lookFromAngle();
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
        // Horizontal drags turn the character; vertical ones fall through
        // to the wardrobe's list so scrolling still works — see _onDrag.
        child: GestureDetector(
          onHorizontalDragUpdate: _onDrag,
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
      ),
    );
  }
}
