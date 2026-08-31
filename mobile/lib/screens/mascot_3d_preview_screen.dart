import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

import '../services/mascot_service.dart';

/// A 3D look at the companion, orbit-draggable so it actually reads as 3D
/// rather than a static render. Most outfits are still 2D-only stills (see
/// [MascotService.outfitsFor]) — only one has a real 3D prop attached by
/// bone (see [MascotService.propForOutfit]), as a pilot for the mechanism.
class Mascot3DPreviewScreen extends StatelessWidget {
  final MascotCharacter character;

  /// Which outfit is equipped, so its [Mascot3DProp] (if any) gets
  /// attached — see [_onAssetLoaded].
  final int outfitIndex;

  const Mascot3DPreviewScreen({
    super.key,
    required this.character,
    required this.outfitIndex,
  });

  // ViewerWidget only allows manipulatorType to change after it's built —
  // any other property differing across rebuilds throws ("create a new
  // widget to change this property"). Vector3/DirectLight don't override
  // value equality, so a fresh instance built inline in build() reads as
  // "changed" the moment this widget rebuilds for any reason (e.g. a
  // system theme/orientation change rippling down the tree) — this
  // screen is normally stable, but mobile/lib/components/mascot_3d_companion.dart
  // hit exactly this crash from its much more frequent rebuilds, so these
  // are hoisted the same way here rather than waiting to hit it too.
  //
  // A dead-on camera lit from the same axis flattens the model — every
  // visible face gets roughly the same light, so it reads as a 2D cutout
  // rather than something with volume. Angling the camera to a 3/4 view
  // and the light off that same axis gives it a visible shading gradient.
  static final _cameraPosition = Vector3(1.3, 1.3, 2.6);
  static final _directLight = DirectLight.sun(
    direction: Vector3(-0.6, -1, -0.2),
    intensity: 150000,
  );

  /// Attaches the equipped outfit's 3D prop (if it has one) to its target
  /// bone by real hierarchy parenting — there's no dedicated "equip" API,
  /// this is the pattern Thermion's own docs show for entity hierarchies
  /// (`viewer.app.setParent`). Wrapped defensively: this is the first
  /// outfit to try bone attachment at all, so a missing bone name or a
  /// asset that fails to load should leave the character visible without
  /// its prop rather than taking down the whole viewer.
  Future<void> _onAssetLoaded(ThermionViewer viewer, ThermionAsset asset) async {
    final prop = MascotService.propForOutfit(character, outfitIndex);
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
      // without its prop than crash the whole 3D view over it.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D')),
      body: ViewerWidget(
        assetPath: MascotService.model3DAsset(character),
        initialCameraPosition: _cameraPosition,
        manipulatorType: ManipulatorType.ORBIT,
        directLight: _directLight,
        transformToUnitCube: true,
        onAssetLoaded: _onAssetLoaded,
      ),
    );
  }
}
