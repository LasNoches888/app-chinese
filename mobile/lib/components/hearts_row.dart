import 'package:flutter/material.dart';

const _pillTint = Color(0xFFE01F53);

/// The lives indicator — a pug whose face reflects how many hearts are
/// left, standing in for a plain row of heart icons.
///
/// [hearts] is clamped to 0–5, the range the art was drawn for; the
/// app's heart cap has always been 5 (see HeartsService), so there's
/// nothing above that to show.
class HeartsRow extends StatelessWidget {
  final int hearts;

  /// Larger, unlabelled treatment for the out-of-hearts screen, where
  /// the pug is the subject rather than a status chip.
  final bool large;

  const HeartsRow({super.key, required this.hearts, this.large = false});

  static String _assetFor(int hearts) =>
      'assets/mascot/hearts/pug_${hearts.clamp(0, 5)}.png';

  @override
  Widget build(BuildContext context) {
    final clamped = hearts.clamp(0, 5);
    final asset = _assetFor(clamped);

    if (large) {
      // Keyed so a change in the count (e.g. a heart regenerating while
      // this screen is up) re-plays the pop instead of snapping.
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Image.asset(asset, key: ValueKey(clamped), height: 150),
      );
    }

    final theme = Theme.of(context);
    final empty = clamped == 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        // Running out is worth registering as a change of state, not
        // just a smaller number.
        color: empty
            ? theme.colorScheme.surfaceContainerHighest
            : _pillTint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Image.asset(asset, key: ValueKey(clamped), height: 34),
          ),
          const SizedBox(width: 6),
          Text(
            '$clamped',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: empty ? theme.colorScheme.outline : _pillTint,
            ),
          ),
        ],
      ),
    );
  }
}
