import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One waypoint in a motion: where the image sits at time fraction [t]
/// (0..1) relative to its own rest pose. [dx]/[dy] are fractions of the
/// widget's own size, not literal pixels, so the same table drives both a
/// small lesson companion and a large wardrobe podium.
///
/// Ported from the approved HTML prototype's CSS `@keyframes`, whose
/// reference box was a fixed 172x172px square -- each [dx]/[dy] here is
/// that prototype's own px value divided by 172 ([_refSize]).
///
/// Every waypoint sets scale/rotation explicitly (defaulting to identity)
/// even where the source CSS keyframe omitted a `scale(...)` function --
/// CSS treats a missing transform function as identity for that keyframe
/// rather than carrying over an earlier value, and the stumble motion
/// below relies on that.
class _Keyframe {
  final double t;
  final double dx;
  final double dy;
  final double scaleX;
  final double scaleY;
  final double rotationDeg;

  const _Keyframe(
    this.t, {
    this.dx = 0,
    this.dy = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotationDeg = 0,
  });
}

/// A sampled pose: how far to translate/scale/rotate the image at some
/// instant. [translateFraction] is still a fraction of the widget's size,
/// not pixels -- the caller multiplies by its own size.
class MascotPose {
  final Offset translateFraction;
  final double scaleX;
  final double scaleY;
  final double rotation; // radians

  const MascotPose({
    this.translateFraction = Offset.zero,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
  });

  static const identity = MascotPose();
}

class _MotionSpec {
  final Duration duration;
  final Curve curve;
  final List<_Keyframe> keyframes; // sorted by t; first t=0, last t=1

  const _MotionSpec(this.duration, this.curve, this.keyframes);

  MascotPose sample(double t) {
    final eased = curve.transform(t.clamp(0, 1));
    var a = keyframes.first;
    var b = keyframes.last;
    for (var i = 0; i < keyframes.length - 1; i++) {
      if (eased >= keyframes[i].t && eased <= keyframes[i + 1].t) {
        a = keyframes[i];
        b = keyframes[i + 1];
        break;
      }
    }
    final span = b.t - a.t;
    final localT = span == 0 ? 0.0 : (eased - a.t) / span;
    double lerp(double x, double y) => x + (y - x) * localT;
    return MascotPose(
      translateFraction: Offset(lerp(a.dx, b.dx), lerp(a.dy, b.dy)),
      scaleX: lerp(a.scaleX, b.scaleX),
      scaleY: lerp(a.scaleY, b.scaleY),
      rotation: lerp(a.rotationDeg, b.rotationDeg) * math.pi / 180,
    );
  }
}

/// Named one-shot reactions a [MascotAnimatedImage] can play, plus the
/// always-looping idle it falls back to between them.
enum MascotMotion { hello, correct, incorrect, boop }

const _refSize = 172.0; // the HTML prototype's fixed companion box, in px

/// A slow rise-and-settle so the mascot never reads as a static picture,
/// even with no reaction playing. Runs on an `AnimationController.repeat
/// (reverse: true)`, so only the 0->1 half needs describing -- the
/// controller supplies the return trip.
const _idleBreathe = _MotionSpec(Duration(milliseconds: 3100), Curves.easeInOut, [
  _Keyframe(0),
  _Keyframe(1, dy: -5 / _refSize, scaleX: 1.015, scaleY: 1.015, rotationDeg: -0.4),
]);

/// A greeting rock -- repurposed from the prototype's "are you still
/// there?" idle nudge, which is visually the closest thing to a wave.
const _hello = _MotionSpec(Duration(milliseconds: 1500), Curves.easeInOut, [
  _Keyframe(0),
  _Keyframe(0.15, dy: -4 / _refSize, rotationDeg: -6),
  _Keyframe(0.30, dy: -6 / _refSize, rotationDeg: 7),
  _Keyframe(0.45, dy: -4 / _refSize, rotationDeg: -6),
  _Keyframe(0.60, dy: -5 / _refSize, rotationDeg: 5),
  _Keyframe(0.75, dy: -2 / _refSize, rotationDeg: -3),
  _Keyframe(1),
]);

/// Anticipation crouch, launch, spin, land, settle.
const _correctJump = _MotionSpec(Duration(milliseconds: 900), Cubic(0.3, 0, 0.2, 1), [
  _Keyframe(0),
  _Keyframe(0.10, dy: 4 / _refSize, scaleX: 1.14, scaleY: 0.84, rotationDeg: -2),
  _Keyframe(0.30, dy: -58 / _refSize, scaleX: 0.9, scaleY: 1.16, rotationDeg: -9),
  _Keyframe(0.50, dy: -78 / _refSize, scaleX: 0.97, scaleY: 1.04, rotationDeg: 7),
  _Keyframe(0.70, dy: -46 / _refSize, scaleX: 0.92, scaleY: 1.14, rotationDeg: -4),
  _Keyframe(0.86, dy: 2 / _refSize, scaleX: 1.16, scaleY: 0.84, rotationDeg: 1),
  _Keyframe(0.94, dy: -6 / _refSize, scaleX: 0.97, scaleY: 1.05, rotationDeg: 0),
  _Keyframe(1),
]);

/// Flinch, stumble, droop, recover.
const _incorrectStumble = _MotionSpec(
  Duration(milliseconds: 780),
  Cubic(0.36, 0.07, 0.19, 0.97),
  [
    _Keyframe(0),
    _Keyframe(0.08, dy: 3 / _refSize, scaleX: 1.06, scaleY: 0.93, rotationDeg: -2),
    _Keyframe(0.22, dx: -13 / _refSize, dy: 2 / _refSize, rotationDeg: -8),
    _Keyframe(0.36, dx: 10 / _refSize, dy: 2 / _refSize, rotationDeg: 6),
    _Keyframe(0.50, dx: -7 / _refSize, dy: 4 / _refSize, rotationDeg: -4),
    _Keyframe(
      0.64,
      dx: 4 / _refSize,
      dy: 6 / _refSize,
      scaleX: 1.03,
      scaleY: 0.95,
      rotationDeg: 2,
    ),
    _Keyframe(
      0.80,
      dx: -2 / _refSize,
      dy: 7 / _refSize,
      scaleX: 1.02,
      scaleY: 0.96,
      rotationDeg: -1.5,
    ),
    _Keyframe(1),
  ],
);

/// A quick squish, like poking a plush toy -- tap-to-react. Not part of the
/// original 3D companion (it wasn't tappable at all), added because a 2D
/// sprite can react to a touch for nearly free.
const _boop = _MotionSpec(Duration(milliseconds: 320), Cubic(0.34, 1.56, 0.64, 1), [
  _Keyframe(0),
  _Keyframe(0.30, dy: 3 / _refSize, scaleX: 0.88, scaleY: 1.14),
  _Keyframe(0.60, scaleX: 1.07, scaleY: 0.93),
  _Keyframe(1),
]);

const _motionSpecs = {
  MascotMotion.hello: _hello,
  MascotMotion.correct: _correctJump,
  MascotMotion.incorrect: _incorrectStumble,
  MascotMotion.boop: _boop,
};

/// Samples [motion]'s pose at time fraction [t] (0..1) in isolation from
/// any widget -- exists mainly so the keyframe tables above have a way to
/// be unit-tested directly.
MascotPose sampleMascotMotion(MascotMotion motion, double t) =>
    _motionSpecs[motion]!.sample(t);

/// Lets a caller trigger a [MascotAnimatedImage]'s one-shot reactions
/// without holding a reference to its private State -- same shape as
/// TextEditingController.
class MascotAnimationController {
  _MascotAnimatedImageState? _state;

  void _attach(_MascotAnimatedImageState state) => _state = state;
  void _detach(_MascotAnimatedImageState state) {
    if (_state == state) _state = null;
  }

  /// Plays [motion] once, then falls back to the idle loop. A no-op if the
  /// widget isn't mounted (e.g. called right as the screen is being popped).
  Future<void> play(MascotMotion motion) async => _state?._play(motion);
}

/// A cross-fading, gently animated mascot portrait. Idles with a slow
/// breathing rise, plays a named one-shot [MascotMotion] on request (via
/// [MascotAnimationController]), and optionally boops on tap. Used by both
/// the lesson-screen companion (small, circular) and the wardrobe podium
/// (large, rounded-rect) -- see mascot_companion.dart / mascot_stage.dart.
class MascotAnimatedImage extends StatefulWidget {
  final String asset;
  final double size;
  final double? width;
  final bool circular;
  final double borderRadius;
  final bool tappable;
  final MascotAnimationController? controller;

  const MascotAnimatedImage({
    super.key,
    required this.asset,
    required this.size,
    this.width,
    this.circular = false,
    this.borderRadius = 0,
    this.tappable = false,
    this.controller,
  });

  @override
  State<MascotAnimatedImage> createState() => _MascotAnimatedImageState();
}

class _MascotAnimatedImageState extends State<MascotAnimatedImage>
    with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: _idleBreathe.duration,
  )..repeat(reverse: true);

  late final AnimationController _reaction = AnimationController(vsync: this);
  MascotMotion? _activeMotion;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(MascotAnimatedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _idle.dispose();
    _reaction.dispose();
    super.dispose();
  }

  Future<void> _play(MascotMotion motion) async {
    if (!mounted) return;
    _reaction.duration = _motionSpecs[motion]!.duration;
    setState(() => _activeMotion = motion);
    await _reaction.forward(from: 0);
    if (mounted && _activeMotion == motion) {
      setState(() => _activeMotion = null);
    }
  }

  void _handleTap() {
    if (!widget.tappable || _activeMotion != null) return;
    unawaited(_play(MascotMotion.boop));
  }

  @override
  Widget build(BuildContext context) {
    Widget image = AnimatedBuilder(
      animation: Listenable.merge([_idle, _reaction]),
      builder: (context, child) {
        final motion = _activeMotion;
        final pose = motion != null
            ? _motionSpecs[motion]!.sample(_reaction.value)
            : _idleBreathe.sample(_idle.value);
        return Transform.translate(
          offset: Offset(
            pose.translateFraction.dx * widget.size,
            pose.translateFraction.dy * widget.size,
          ),
          child: Transform.rotate(
            angle: pose.rotation,
            child: Transform.scale(
              scaleX: pose.scaleX,
              scaleY: pose.scaleY,
              child: child,
            ),
          ),
        );
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Image.asset(
          widget.asset,
          key: ValueKey(widget.asset),
          height: widget.size,
          fit: BoxFit.contain,
        ),
      ),
    );

    if (widget.circular) {
      image = ClipOval(child: image);
    } else if (widget.borderRadius > 0) {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: image,
      );
    }

    return SizedBox(
      width: widget.width ?? widget.size,
      height: widget.size,
      child: widget.tappable
          ? GestureDetector(onTap: _handleTap, child: image)
          : image,
    );
  }
}
