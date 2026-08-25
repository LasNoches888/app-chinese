import 'package:flutter/material.dart';

/// A small, living stand-in for a static panda `Image.asset` — cross-fades
/// between whatever asset the caller hands it instead of jump-cutting, so a
/// mood change reads as a reaction rather than a broken image swap.
class MascotWidget extends StatelessWidget {
  final String asset;
  final double size;

  const MascotWidget({super.key, required this.asset, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Image.asset(asset, key: ValueKey(asset), height: size),
    );
  }
}
