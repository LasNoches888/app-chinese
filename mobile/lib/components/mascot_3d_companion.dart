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
    this.size = 96,
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
  late final _cameraPosition = Vector3(0, 1, 3);
  late final _directLight = DirectLight.sun();
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

  Future<void> _onAssetLoaded(ThermionViewer viewer, ThermionAsset asset) async {
    _asset = asset;
    await asset.addAnimationComponent();
    await asset.playGltfAnimation(
      MascotService.idleAnimationIndex(widget.character),
      loop: true,
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
    // Cheap approximation rather than querying the clip's real duration —
    // this is a reaction pop-up, not a cutscene, so a slightly early or
    // late return to idle is not worth another native round trip for.
    _cueTimer = Timer(const Duration(seconds: 2), () async {
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
              transformToUnitCube: true,
              background: _background,
              onAssetLoaded: _onAssetLoaded,
            ),
          ),
        ),
      ],
    );
  }
}
