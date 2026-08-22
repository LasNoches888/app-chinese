import 'package:speech_to_text/speech_to_text.dart';

/// Listens to the learner's own attempt at a word and reports back what
/// the on-device speech recognizer heard.
///
/// This is a proxy for pronunciation quality, not a lab-grade phonetic
/// analysis: Android's/iOS's speech recognizer resolves ambiguous audio to
/// the single most likely real word using its language model, the same
/// way it would for any dictation. For an isolated one- or two-syllable
/// word that mostly means "did this resolve to the target character" —
/// close-but-wrong-tone attempts sometimes still get recognized correctly
/// if the recognizer's language model favors that word anyway, and correct
/// attempts can misfire on unclear audio. It's a useful "does this sound
/// roughly right" check, not a tone-accuracy score.
class PronunciationService {
  static final SpeechToText _speech = SpeechToText();
  static bool _initialized = false;
  static bool _available = false;

  static bool get isListening => _speech.isListening;

  /// Probes for a working speech recognizer. Safe to call repeatedly and
  /// safe to call where none exists (no mic permission, no recognizer
  /// installed, or a test environment with no platform channels) — it
  /// just leaves [isAvailable] false.
  static Future<bool> ensureInitialized() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      _available = await _speech
          .initialize(onError: (_) {}, onStatus: (_) {})
          // Some environments (no recognizer installed, no platform
          // channel at all in tests) never resolve initialize()'s
          // completer rather than rejecting it — without a timeout the
          // screen would sit on a loading spinner forever instead of
          // falling back to the unavailable state.
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  /// Starts listening, calling [onResult] with the recognizer's best guess
  /// each time it updates (both partial and final results — [isFinal]
  /// tells them apart). No-ops if no recognizer is available.
  static Future<void> listen({
    required void Function(String recognizedText, bool isFinal) onResult,
    String localeId = 'zh-CN',
  }) async {
    if (!await ensureInitialized()) return;
    await _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 2),
        listenFor: const Duration(seconds: 8),
      ),
    );
  }

  static Future<void> stop() => _speech.stop();

  /// Loose match: strips whitespace/punctuation the recognizer sometimes
  /// adds and checks whether the target word appears in what was heard —
  /// a short answer read back as part of a longer recognized phrase
  /// ("这是你好" for "你好") should still count.
  static bool matches(String recognizedText, String targetHanzi) {
    final cleaned = recognizedText.replaceAll(RegExp(r'[\s,.!?，。！？、]'), '');
    return cleaned.contains(targetHanzi);
  }
}
