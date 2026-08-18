import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../services/speech_service.dart';

/// Taps to read [text] aloud in Mandarin, showing a filled speaker icon
/// while it plays.
///
/// Renders nothing when the device has no Mandarin voice — an inert button
/// that silently does nothing when tapped reads as a bug, so it's better to
/// leave the space empty than to promise audio that can't happen.
class SpeakButton extends StatefulWidget {
  final String text;
  final double size;
  final Color? color;

  const SpeakButton({
    super.key,
    required this.text,
    this.size = 22,
    this.color,
  });

  @override
  State<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<SpeakButton> {
  late Future<bool> _available;

  @override
  void initState() {
    super.initState();
    _available = SpeechService.ensureInitialized();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _available,
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        final settings = context.watch<AppSettings>();
        return ValueListenableBuilder<String?>(
          valueListenable: SpeechService.speaking,
          builder: (context, speaking, _) {
            final isSpeaking = speaking == widget.text;
            return IconButton(
              iconSize: widget.size,
              visualDensity: VisualDensity.compact,
              tooltip: settings.t('listen'),
              icon: Icon(
                isSpeaking ? Icons.volume_up : Icons.volume_up_outlined,
                color: widget.color ?? Theme.of(context).colorScheme.primary,
              ),
              onPressed: isSpeaking
                  ? SpeechService.stop
                  : () => SpeechService.speak(
                      widget.text,
                      rate: settings.speechSpeed.rate,
                    ),
            );
          },
        );
      },
    );
  }
}
