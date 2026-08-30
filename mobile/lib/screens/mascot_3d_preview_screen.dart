import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

import '../services/mascot_service.dart';

/// A first, minimal 3D look at the companion — the base model only, no
/// outfits yet (those are still 2D-only, see [MascotService.outfitsFor]).
/// Orbit-draggable so the model actually reads as 3D rather than a static
/// render.
class Mascot3DPreviewScreen extends StatelessWidget {
  final MascotCharacter character;

  const Mascot3DPreviewScreen({super.key, required this.character});

  // ViewerWidget only allows manipulatorType to change after it's built —
  // any other property differing across rebuilds throws ("create a new
  // widget to change this property"). Vector3/DirectLight don't override
  // value equality, so a fresh instance built inline in build() reads as
  // "changed" the moment this widget rebuilds for any reason (e.g. a
  // system theme/orientation change rippling down the tree) — this
  // screen is normally stable, but mobile/lib/components/mascot_3d_companion.dart
  // hit exactly this crash from its much more frequent rebuilds, so these
  // are hoisted the same way here rather than waiting to hit it too.
  static final _cameraPosition = Vector3(0, 1, 3);
  static final _directLight = DirectLight.sun();

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
      ),
    );
  }
}
