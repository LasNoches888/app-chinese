import 'package:flutter/material.dart';

const _heartLight = Color(0xFFFF7A93);
const _heartDeep = Color(0xFFE01F53);

/// The lives indicator.
///
/// Two treatments, because it is doing two different jobs. In a lesson it
/// is a status chip and shows one heart with a count: five separate icons
/// in a row is a lot of pixels spent on a number, and it reads as clutter
/// beside the progress bar. On the out-of-hearts screen the hearts *are*
/// the subject, so there it draws all of them, empty, at size.
///
/// The heart is painted rather than taken from the icon font. The stock
/// Material heart is a flat, wide shape that looks like a symbol on a
/// form; this one has the narrower waist and rounded lobes of a real
/// heart, plus a gradient and a soft glow that keep it from reading as
/// clip art.
class HeartsRow extends StatelessWidget {
  final int hearts;
  final int max;

  /// Larger, spelled-out treatment for the results and out-of-hearts
  /// screens.
  final bool large;

  const HeartsRow({
    super.key,
    required this.hearts,
    this.max = 5,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    if (large) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < max; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _Heart(filled: i < hearts, size: 34),
            ),
        ],
      );
    }

    final theme = Theme.of(context);
    final empty = hearts <= 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
      decoration: BoxDecoration(
        // Running out is worth registering as a change of state, not just
        // a smaller number.
        color: empty
            ? theme.colorScheme.surfaceContainerHighest
            : _heartDeep.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Heart(filled: !empty, size: 17),
          const SizedBox(width: 7),
          // The count is the thing that changes, so it gets the animation
          // rather than the heart beside it.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Text(
              '$hearts',
              key: ValueKey(hearts),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: empty ? theme.colorScheme.outline : _heartDeep,
              ),
            ),
          ),
        ],
      ),
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
      // Keyed on `filled` so the tween re-runs from the start each time
      // this heart flips, rather than only animating once on first build.
      key: ValueKey(filled),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        // Only gaining a heart should feel like a gain; an empty one just
        // sits there.
        final scale = filled ? 0.65 + 0.35 * t : 1.0;
        return Transform.scale(scale: scale, child: child);
      },
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _HeartPainter(
            filled: filled,
            outline: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.30),
          ),
        ),
      ),
    );
  }
}

class _HeartPainter extends CustomPainter {
  final bool filled;
  final Color outline;

  const _HeartPainter({required this.filled, required this.outline});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _heartPath(size);

    if (filled) {
      // A glow under the shape rather than a drop shadow: the heart
      // should look lit, not stuck to the background with an offset.
      canvas.drawPath(
        path,
        Paint()
          ..color = _heartDeep.withValues(alpha: 0.34)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_heartLight, _heartDeep],
          ).createShader(Offset.zero & size),
      );
    } else {
      canvas.drawPath(path, Paint()..color = outline.withValues(alpha: 0.12));
      canvas.drawPath(
        path,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.09
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  /// Two mirrored cubics: down to the point, out through each lobe, and
  /// back to the dip at the top.
  static Path _heartPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.5, h * 0.94)
      ..cubicTo(w * -0.10, h * 0.56, w * 0.10, h * -0.08, w * 0.5, h * 0.30)
      ..cubicTo(w * 0.90, h * -0.08, w * 1.10, h * 0.56, w * 0.5, h * 0.94)
      ..close();
  }

  @override
  bool shouldRepaint(_HeartPainter old) =>
      old.filled != filled || old.outline != outline;
}
