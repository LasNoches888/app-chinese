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
  ThermionAsset? _asset;
  Matrix4? _baseTransform;
  double _angle = 0;

  // See mobile/lib/components/mascot_3d_companion.dart for why these are
  // cached rather than built fresh in build() — ViewerWidget throws if any
  // property other than manipulatorType differs across rebuilds, and
  // neither Vector3 nor DirectLight override value equality.
  late final _cameraPosition = Vector3(0.4, 1.15, 2.6);
  late final _keyLight = DirectLight.sun(
    direction: Vector3(-0.6, -1, -0.2),
    intensity: 150000,
  );
  late final _background = Theme.of(context).colorScheme.surfaceContainerHighest;

  @override
  void dispose() {
    _spinTimer?.cancel();
    super.dispose();
  }

  /// A single directional light leaves anything not facing it essentially
  /// unlit — there's no ambient/IBL fill in this scene, so the shadowed
  /// side of the model was reading as solid black. A second, dimmer light
  /// from roughly the opposite side stands in for that fill.
  Future<void> _onViewerAvailable(ThermionViewer viewer) async {
    await viewer.addDirectLight(
      DirectLight.sun(direction: Vector3(0.6, -0.3, 0.8), intensity: 45000),
    );
  }

  Future<void> _onAssetLoaded(ThermionViewer viewer, ThermionAsset asset) async {
    _asset = asset;
    _baseTransform = await asset.getLocalTransform();
    _spinTimer = Timer.periodic(const Duration(milliseconds: 40), (_) async {
      final asset = _asset;
      final base = _baseTransform;
      if (!mounted || asset == null || base == null) return;
      _angle += 0.012;
      await asset.setTransform(Matrix4.rotationY(_angle) * base);
    });

    // Attach the equipped outfit's 3D prop, if it has one — same pilot
    // mechanism as before, just now live in the wardrobe's own stage.
    final prop = MascotService.propForOutfit(widget.character, widget.outfitIndex);
    if (prop == null) return;
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
          transformToUnitCube: true,
          background: _background,
          // This widget is recreated (via a character+outfit key) rather
          // than updated whenever either changes, since ViewerWidget can't
          // change its assetPath in place — so the old engine needs to
          // actually be torn down each time rather than leaking.
          destroyEngineOnUnload: true,
          onViewerAvailable: _onViewerAvailable,
          onAssetLoaded: _onAssetLoaded,
        ),
      ),
    );
  }
}
