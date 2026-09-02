import 'dart:async';

import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

import '../services/mascot_service.dart';
import 'mascot_3d_instance.dart';

/// Lets a screen trigger the mascot's mid-lesson reactions without holding
/// a reference to the widget's private State — same shape as
/// TextEditingController.
class Mascot3DCompanionController {
  _Mascot3DCompanionState? _state;

  void _attach(_Mascot3DCompanionState state) => _state = state;
  void _detach(_Mascot3DCompanionState state) {
    if (_state == state) _state = null;
  }

  /// Plays [cue]'s one-shot animation, shows [message] in a speech bubble
  /// for a few seconds, then settles back to idle. A no-op if the widget
  /// isn't mounted (e.g. called right as the screen is being popped).
  void react(Mascot3DCue cue, String message) => _state?._react(cue, message);
}

/// A small, persistent 3D companion — kept alive for the whole screen
/// rather than recreated per reaction, since spinning up a new Filament
/// engine instance is far too slow to do every time a question is
/// answered. Only its animation and speech bubble change.
class Mascot3DCompanion extends StatefulWidget {
  final MascotCharacter character;
  final Mascot3DCompanionController controller;
  final double size;

  const Mascot3DCompanion({
    super.key,
    required this.character,
    required this.controller,
    this.size = 116,
  });

  @override
  State<Mascot3DCompanion> createState() => _Mascot3DCompanionState();
}

class _Mascot3DCompanionState extends State<Mascot3DCompanion> {
  ThermionAsset? _asset;
  String? _message;
  Timer? _messageTimer;
  Timer? _cueTimer;

  /// The scale-and-centre transform, kept so it can be put back after every
  /// animation change — see [_applyPose].
  Matrix4? _poseTransform;

  // ViewerWidget only allows manipulatorType to change after it's built —
  // every other property throws ("create a new widget to change this
  // property") if it differs across rebuilds, which Vector3/DirectLight
  // instances built fresh in every build() would, since neither overrides
  // value equality. Built once and reused as the same instances for the
  // widget's whole lifetime, which the frequent rebuilds a lesson screen
  // triggers (one per answer) would otherwise hit constantly.
  //
  // A dead-on camera lit from the same axis flattens the model — every
  // visible face gets roughly the same light, so it reads as a 2D cutout
  // rather than something with volume. Angling the camera to a 3/4 view
  // (25° around) and the light off that same axis gives it a visible
  // shading gradient.
  //
  // Distance and height are derived the same way as the podium's — see
  // mascot_3d_stage.dart for the 46.4° vertical FOV this all hangs off.
  // The old (1.3, 1.3, 2.6) sat 3.18 units from a 1-unit character, so it
  // filled 39% of an already-small 116px circle: about 45px of actual
  // character, far too little to read a wave or a head-shake, which is
  // why the reactions came across as an indistinct twitch. d = 1.91 takes
  // that to 65%, and 0.26 of height gives the same 8° tilt as the podium.
  //
  // Sized against the circular crop rather than the square frame: this is
  // clipped to a circle (ClipRRect, radius = size/2), so a raised arm can
  // leave the visible area while still inside the viewport. Checked by
  // projecting every clip the companion plays — idle, Wave, "No", and the
  // long celebration — and taking the largest radius from centre, which
  // Wave reaches at 0.90 of the circle.
  late final _cameraPosition = Vector3(0.80, 0.26, 1.71);
  late final _directLight = DirectLight.sun(
    direction: Vector3(-0.6, -1, -0.2),
    intensity: MascotService.keyLightIntensity,
  );
  late final _background = Theme.of(context).colorScheme.surfaceContainerHighest;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _messageTimer?.cancel();
    _cueTimer?.cancel();
    super.dispose();
  }

  /// Same flat-cartoon lighting as the podium — see mascot_3d_stage.dart's
  /// _onViewerAvailable and MascotService.iblIntensity.
  Future<void> _onViewerAvailable(ThermionViewer viewer) async {
    await viewer.loadIbl(
      MascotService.iblAsset,
      intensity: MascotService.iblIntensity,
    );
  }

  Future<void> _onAssetLoaded(ThermionViewer viewer, ThermionAsset asset) async {
    // Animation and transform calls have to target the asset's instance,
    // not the asset ViewerWidget hands over — see poseTarget. Getting
    // this wrong left the skeleton undriven and the mesh shredded.
    final posed = await poseTarget(asset);
    _asset = posed;
    await posed.addAnimationComponent();
    await posed.playGltfAnimation(
      MascotService.idleAnimationIndex(widget.character),
      loop: true,
    );

    // See mobile/lib/components/mascot_3d_stage.dart for why this is
    // needed — ViewerWidget's transformToUnitCube flag is a no-op.
    final bounds = MascotService.modelBounds(widget.character);
    final scale = 1.0 / bounds.height;
    _poseTransform = Matrix4.compose(
      Vector3(0, -scale * bounds.centerY, -scale * bounds.centerZ),
      Quaternion.identity(),
      Vector3.all(scale),
    );
    await _applyPose();
  }

  /// Puts the scale-and-centre transform back on the model.
  ///
  /// Has to be re-applied after every [playGltfAnimation], not just once at
  /// load. Every clip in this rig — idle and each cue alike — carries
  /// translation/rotation/scale channels for the armature root, all of them
  /// identity, so starting a clip resets the very node this transform is
  /// written to. The model snaps back to its export scale, several units
  /// tall against a camera 1.9 units out, and the circle goes empty.
  ///
  /// It's why the mascot vanished on a reaction while the wardrobe podium
  /// stayed fine: the podium plays an animation once at load and never
  /// again, so nothing ever resets it, whereas a reaction plays a cue and
  /// then idle again.
  Future<void> _applyPose() async {
    final asset = _asset;
    final pose = _poseTransform;
    if (asset == null || pose == null) return;
    await asset.setTransform(pose);
  }

  Future<void> _react(Mascot3DCue cue, String message) async {
    if (!mounted) return;
    _messageTimer?.cancel();
    _cueTimer?.cancel();
    setState(() => _message = message);
    _messageTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _message = null);
    });

    final asset = _asset;
    if (asset == null) return;
    final idleIndex = MascotService.idleAnimationIndex(widget.character);
    final cueIndex = MascotService.cueAnimationIndex(widget.character, cue);
    await asset.playGltfAnimation(cueIndex, loop: false);
    // Starting a clip resets the armature root this transform lives on —
    // see _applyPose. Without putting it straight back, the mascot jumps to
    // its export scale and disappears off the edges of its own circle.
    await _applyPose();
    if (!mounted) return;
    _cueTimer = Timer(MascotService.cueDuration(widget.character, cue), () async {
      if (_asset != null) {
        await _asset!.playGltfAnimation(idleIndex, loop: true);
        await _applyPose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = _message;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // The bubble's slot is always occupied, and the viewer below is
        // keyed, so that showing a reaction can't disturb the viewer's
        // identity in this list.
        //
        // This was written as `if (_message != null) Container(...)`, which
        // reads harmlessly but isn't: Flutter matches a multi-child
        // widget's children by position and type, so the list going from
        // [ClipRRect] to [Container, ClipRRect] makes it compare a
        // Container against the old ClipRRect at index 0, decide they're
        // unrelated, and throw away that whole subtree — the ViewerWidget,
        // its State and its Filament viewer with it. Every reaction tore
        // the 3D companion down and rebuilt it, and the replacement raced
        // the teardown and came up blank. It showed up as the mascot
        // vanishing on wrong answers specifically, because a wrong answer
        // always reacts while a correct one only does every third time
        // (see lesson_session_screen.dart).
        if (message == null)
          const SizedBox.shrink()
        else
          Container(
            constraints: const BoxConstraints(maxWidth: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: scheme.onSurface),
            ),
          ),
        ClipRRect(
          key: const ValueKey('mascot-3d-viewer'),
          borderRadius: BorderRadius.circular(widget.size / 2),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: ViewerWidget(
              assetPath: MascotService.model3DAsset(widget.character),
              initialCameraPosition: _cameraPosition,
              manipulatorType: ManipulatorType.NONE,
              directLight: _directLight,
              // See mobile/lib/components/mascot_3d_stage.dart — without
              // this, faces the direct lights don't hit render fully
              // black (no ambient term otherwise). _onViewerAvailable
              // reloads it at the intensity the cartoon look needs.
              iblPath: MascotService.iblAsset,
              // A no-op in this version — see the comment in
              // _onAssetLoaded, which does the equivalent normalization
              // itself. Left false (rather than omitted) so it doesn't
              // look like an oversight.
              transformToUnitCube: false,
              background: _background,
              onViewerAvailable: _onViewerAvailable,
              onAssetLoaded: _onAssetLoaded,
            ),
          ),
        ),
      ],
    );
  }
}
