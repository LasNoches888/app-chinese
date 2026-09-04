import 'package:flutter/material.dart';

import '../services/mascot_service.dart';
import 'mascot_animated_image.dart';

/// A big, always-visible "podium" view of the companion in the wardrobe --
/// idles, cross-fades between characters/outfits, and boops on tap. A flat
/// 2D sprite has no back side, so unlike the old 3D podium there's nothing
/// to swipe-turn.
class MascotStage extends StatelessWidget {
  final MascotCharacter character;
  final int outfitIndex;
  final double height;

  const MascotStage({
    super.key,
    required this.character,
    required this.outfitIndex,
    this.height = 260,
  });

  String get _asset {
    final outfits = MascotService.outfitsFor(character);
    final outfit = outfits.firstWhere(
      (o) => o.index == outfitIndex,
      orElse: () => outfits.first,
    );
    return outfit.asset;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: MascotAnimatedImage(
        asset: _asset,
        size: height * 0.82,
        width: double.infinity,
        tappable: true,
      ),
    );
  }
}
