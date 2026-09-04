import 'dart:async';

import 'package:flutter/material.dart';

import '../services/mascot_service.dart';
import 'mascot_animated_image.dart';

/// Lets a screen trigger the mascot's mid-lesson reactions without holding
/// a reference to the widget's private State -- same shape as
/// TextEditingController.
class MascotCompanionController {
  _MascotCompanionState? _state;

  void _attach(_MascotCompanionState state) => _state = state;
  void _detach(_MascotCompanionState state) {
    if (_state == state) _state = null;
  }

  /// Plays [cue]'s one-shot motion, shows [message] in a speech bubble for
  /// a few seconds, then settles back to idle. A no-op if the widget isn't
  /// mounted (e.g. called right as the screen is being popped).
  void react(MascotCue cue, String message) => _state?._react(cue, message);
}

const _cueMotions = {
  MascotCue.hello: MascotMotion.hello,
  MascotCue.correct: MascotMotion.correct,
  MascotCue.incorrect: MascotMotion.incorrect,
};

/// A small, persistent 2D companion for the lesson screen -- kept mounted
/// for the whole screen rather than recreated per reaction, so a message
/// bubble can be shown/hidden without losing animation state.
class MascotCompanion extends StatefulWidget {
  final MascotCharacter character;
  final MascotCompanionController controller;
  final double size;

  const MascotCompanion({
    super.key,
    required this.character,
    required this.controller,
    this.size = 116,
  });

  @override
  State<MascotCompanion> createState() => _MascotCompanionState();
}

class _MascotCompanionState extends State<MascotCompanion> {
  final _imageController = MascotAnimationController();
  String? _message;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _messageTimer?.cancel();
    super.dispose();
  }

  void _react(MascotCue cue, String message) {
    if (!mounted) return;
    _messageTimer?.cancel();
    setState(() => _message = message);
    _messageTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _message = null);
    });
    unawaited(_imageController.play(_cueMotions[cue]!));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = _message;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // The bubble's slot is always occupied (a SizedBox.shrink() rather
        // than being absent from the list) so its position never shifts.
        if (message == null)
          const SizedBox.shrink()
        else
          Container(
            constraints: const BoxConstraints(maxWidth: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: scheme.onSurface),
            ),
          ),
        MascotAnimatedImage(
          asset: MascotService.outfitsFor(widget.character).first.asset,
          size: widget.size,
          circular: true,
          tappable: true,
          controller: _imageController,
        ),
      ],
    );
  }
}
