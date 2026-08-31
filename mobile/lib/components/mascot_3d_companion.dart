import 'dart:async';

import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

import '../services/mascot_service.dart';

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
  // and the light off that same axis gives it a visible shading gradient.
  late final _cameraPosition = Vector3(1.3, 1.3, 2.6);
  late final _directLight = DirectLight.sun(
    direction: Vector3(-0.6, -1, -0.2),
    intensity: 150000,
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

  /// Games built for this exact "toy character" look (Subway Surfers
  /// among them) mostly skip dynamic lighting altogether — shading is
  /// baked into the texture with an unlit shader, so there's never a dark
  /// side to get wrong. Thermion's PBR pipeline doesn't give us that
  /// shortcut, so the next best thing is lighting from enough directions
  /// that nothing reads as unlit — three fills roughly opposite and
  /// perpendicular to the key light, all close to it in strength rather
  /// than one dim accent, rather than chasing one "correct" light angle.
  Future<void> _onViewerAvailable(ThermionViewer viewer) async {
    await viewer.addDirectLight(
      DirectLight.sun(direction: Vector3(0.6, -0.3, 0.8), intensity: 110000),
    );
    await viewer.addDirectLight(
      DirectLight.sun(direction: Vector3(0, 0.8, -0.4), intensity: 70000),
    );
    await viewer.addDirectLight(
      DirectLight.sun(direction: Vector3(-0.3, -0.6, 0.5), intensity: 70000),
    );
  }

  Future<void> _onAssetLoaded(ThermionViewer viewer, ThermionAsset asset) async {
    _asset = asset;
    await asset.addAnimationComponent();
    await asset.playGltfAnimation(
      MascotService.idleAnimationIndex(widget.character),
      loop: true,
    );

    // See mobile/lib/components/mascot_3d_stage.dart for why this is
    // needed — ViewerWidget's transformToUnitCube flag is a no-op.
    final bounds = MascotService.modelBounds(widget.character);
    final scale = 1.0 / bounds.height;
    await asset.setTransform(
      Matrix4.compose(
        Vector3(0, -scale * bounds.centerY, -scale * bounds.centerZ),
        Quaternion.identity(),
        Vector3.all(scale),
      ),
    );
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
    if (!mounted) return;
    _cueTimer = Timer(MascotService.cueDuration(widget.character, cue), () async {
      if (_asset != null) {
        await _asset!.playGltfAnimation(idleIndex, loop: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_message != null)
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
              _message!,
              style: TextStyle(fontSize: 13, color: scheme.onSurface),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(widget.size / 2),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: ViewerWidget(
              assetPath: MascotService.model3DAsset(widget.character),
              initialCameraPosition: _cameraPosition,
              manipulatorType: ManipulatorType.NONE,
              directLight: _directLight,
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
