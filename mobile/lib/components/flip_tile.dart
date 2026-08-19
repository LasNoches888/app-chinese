import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A single card that animates a real 3D flip (rotateY) between [back] and
/// [front] whenever [faceUp] changes, rather than just cross-fading —
/// that rotation is most of what makes tapping a memory-match tile feel
/// tactile instead of like toggling a checkbox.
class FlipTile extends StatefulWidget {
  final bool faceUp;
  final Widget front;
  final Widget back;
  final VoidCallback? onTap;

  const FlipTile({
    super.key,
    required this.faceUp,
    required this.front,
    required this.back,
    this.onTap,
  });

  @override
  State<FlipTile> createState() => _FlipTileState();
}

class _FlipTileState extends State<FlipTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: widget.faceUp ? 1 : 0,
  );

  @override
  void didUpdateWidget(FlipTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.faceUp != oldWidget.faceUp) {
      if (widget.faceUp) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * math.pi;
          final showFront = angle > math.pi / 2;
          // The card being drawn past the halfway point would render its
          // content mirror-flipped — swap in the other face and un-mirror
          // it there instead of showing backwards text mid-flip.
          final content = showFront
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: widget.front,
                )
              : widget.back;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: content,
          );
        },
      ),
    );
  }
}
