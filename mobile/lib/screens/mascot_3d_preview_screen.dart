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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('3D')),
      body: ViewerWidget(
        assetPath: MascotService.model3DAsset(character),
        initialCameraPosition: Vector3(0, 1, 3),
        manipulatorType: ManipulatorType.ORBIT,
        directLight: DirectLight.sun(),
        transformToUnitCube: true,
      ),
    );
  }
}
