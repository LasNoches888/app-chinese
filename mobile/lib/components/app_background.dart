import 'package:flutter/material.dart';

/// Shared page backdrop: a soft themed base colour with the ink-wash
/// mountain scene sitting along the bottom edge.
///
/// Uses [DecorationImage] rather than stacking an [Image] behind the
/// content — one less layout box in the tree, and the child keeps the exact
/// constraints it would have had without a background at all.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141F) : const Color(0xFFF5F6FA),
        image: DecorationImage(
          image: const AssetImage('assets/images/bg_scene.png'),
          alignment: Alignment.bottomCenter,
          fit: BoxFit.fitWidth,
          // The artwork is already low-alpha; dark mode needs it dimmer
          // still so it reads as atmosphere rather than content.
          opacity: isDark ? 0.35 : 0.75,
        ),
      ),
      child: child,
    );
  }
}

/// The same scene in white, sized to sit inside the brand gradient banner.
class BrandHeaderArt extends StatelessWidget {
  const BrandHeaderArt({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/bg_header.png',
      fit: BoxFit.cover,
      alignment: Alignment.bottomCenter,
    );
  }
}
