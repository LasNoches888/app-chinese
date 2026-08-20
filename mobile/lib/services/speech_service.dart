import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
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
  static bool _autoInstallAttempted = false;

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
    if (!await ensureInitialized()) {
      // Rather than sending the learner to Settings to find a "download
      // voice" button, the first tap on any speak button just quietly
      // opens the system voice picker itself — once per app session, so
      // it doesn't keep yanking them out of the app on every retry.
      if (!_autoInstallAttempted) {
        _autoInstallAttempted = true;
        await openVoiceInstall();
      }
      return;
    }
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

  /// Opens Android's own "install voice data" flow for the TTS engine
  /// (normally Google's), which lands the learner directly on the Mandarin
  /// voice download rather than making them find System → Language & input
  /// → Text-to-speech themselves. Resets the cached availability probe so
  /// the next [ensureInitialized] call actually re-checks instead of
  /// replaying the "not available" result from before the voice existed.
  static Future<void> openVoiceInstall() async {
    _initialized = false;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      const intent = AndroidIntent(
        action: 'android.speech.tts.engine.ACTION_INSTALL_TTS_DATA',
      );
      await intent.launch();
    } catch (_) {
      // No activity can handle the intent (very old/custom ROM) — the
      // learner just stays without Chinese speech, same as today.
    }
  }

  static Future<void> stop() async {
    // Clear the "currently playing" state unconditionally, before the
    // availability check: bailing out early left it stale, so a speaker
    // button could stay stuck in its playing state with nothing to stop.
    speaking.value = null;
    if (!_available) return;
    try {
      await _tts.stop();
    } catch (_) {
      // Nothing to recover from — the UI state is already reset.
    }
  }
}

/// Cuts playback when the screen goes away.
///
/// TTS is a process-wide singleton, so audio started on one screen keeps
/// talking after the user navigates away unless something stops it —
/// leaving a dialogue reading itself aloud over whatever the learner
/// opened next. Every screen that can start speech mixes this in.
mixin StopSpeechOnDispose<T extends StatefulWidget> on State<T> {
  @override
  void dispose() {
    SpeechService.stop();
    super.dispose();
  }
}
