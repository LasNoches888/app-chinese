import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads Chinese text aloud through the device's text-to-speech engine.
///
/// Everything here fails soft: a device with no Mandarin voice installed
/// (or a test environment with no platform channels at all) leaves
/// [isAvailable] false and turns every call into a no-op, so callers can
/// wire up speak buttons without null checks or try/catch at each site.
class SpeechService {
  static const _language = 'zh-CN';

  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;
  static bool _available = false;

  /// The text currently being spoken, so a button can show a playing state
  /// and callers can tell which of several words is sounding.
  static final ValueNotifier<String?> speaking = ValueNotifier<String?>(null);

  /// False until [ensureInitialized] has confirmed a Mandarin voice exists.
  static bool get isAvailable => _available;

  /// Probes for a Mandarin voice and wires up completion handlers. Safe to
  /// call repeatedly and safe to call where TTS doesn't exist — it just
  /// leaves [isAvailable] false.
  static Future<bool> ensureInitialized() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      final supported = await _tts.isLanguageAvailable(_language);
      if (supported != true) return _available = false;

      await _tts.setLanguage(_language);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() => speaking.value = null);
      _tts.setCancelHandler(() => speaking.value = null);
      _tts.setErrorHandler((_) => speaking.value = null);
      return _available = true;
    } catch (_) {
      // No TTS engine, or no platform channel (unit tests) — treat exactly
      // like "device can't speak Chinese" rather than breaking the caller.
      return _available = false;
    }
  }

  /// Speaks [text] in Mandarin, replacing anything already playing.
  ///
  /// [rate] is the platform rate where 0.5 is the engine's normal pace;
  /// learners generally need slower than that to catch tones.
  static Future<void> speak(String text, {double rate = 0.45}) async {
    if (text.trim().isEmpty) return;
    if (!await ensureInitialized()) return;
    try {
      // Tapping a second word should switch to it, not queue behind the
      // first — stop before speaking rather than relying on queue mode.
      await _tts.stop();
      await _tts.setSpeechRate(rate);
      speaking.value = text;
      await _tts.speak(text);
    } catch (_) {
      speaking.value = null;
    }
  }

  static Future<void> stop() async {
    if (!_available) return;
    try {
      await _tts.stop();
    } catch (_) {
      // Nothing to recover from — the UI state is reset either way.
    }
    speaking.value = null;
  }
}
