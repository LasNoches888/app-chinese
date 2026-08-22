import 'package:flutter/material.dart';

const _heartRed = Color(0xFFFF4D6D);
const _heartDeep = Color(0xFFC9184A);

/// The hearts/lives indicator.
///
/// Losing a heart is the one moment in a lesson where the app pushes back
/// on the learner, so it gets a real beat: the heart that just went out
/// pops and fades to a hollow outline instead of silently switching icon,
/// and the remaining hearts sit in a soft pill so they read as a single
/// "life bar" rather than five loose icons in the app bar.
class HeartsRow extends StatelessWidget {
  final int hearts;
  final int max;

  /// Larger, centered treatment for the results/out-of-hearts screens,
  /// where the hearts are the subject rather than a status chip.
  final bool large;

  const HeartsRow({
    super.key,
    required this.hearts,
    this.max = 5,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = large ? 34.0 : 19.0;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: large ? 3 : 1),
            child: _Heart(filled: i < hearts, size: size),
          ),
      ],
    );

    if (large) return row;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _heartRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: row,
    );
  }
}

class _Heart extends StatelessWidget {
  final bool filled;
  final double size;

  const _Heart({required this.filled, required this.size});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Keyed on `filled` so the tween re-runs from 0 each time this
      // heart's state flips, rather than only animating once on first
      // build.
      key: ValueKey(filled),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        // Empty hearts don't need the pop — only the transition *into*
        // full should feel like a gain.
        final scale = filled ? 0.6 + 0.4 * t : 1.0;
        return Transform.scale(scale: scale, child: child);
      },
      child: filled
          ? Icon(
              Icons.favorite,
              size: size,
              color: _heartRed,
              shadows: const [
                Shadow(color: _heartDeep, blurRadius: 6, offset: Offset(0, 1)),
              ],
            )
          : Icon(
              Icons.favorite,
              size: size,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.22),
            ),
    );
  }
}
