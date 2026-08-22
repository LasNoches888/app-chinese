import 'package:speech_to_text/speech_to_text.dart';

/// How close the learner's attempt was, and what specifically to fix.
enum PronunciationGrade {
  /// The recognizer resolved the audio to exactly the target word.
  correct,

  /// The target word is in there, but surrounded by other words — usually
  /// a hesitation ("эм 你好") or the recognizer picking up a longer phrase.
  closeExtraWords,

  /// The recognizer heard a same-length Chinese word that isn't the
  /// target — the classic "right syllables, wrong tone" outcome, since a
  /// wrong tone usually resolves to a different real character.
  wrongWord,

  /// Nothing usable came back: silence, non-Chinese, or too noisy.
  notHeard,
}

class PronunciationResult {
  final PronunciationGrade grade;

  /// What the recognizer actually heard, cleaned of punctuation.
  final String heard;

  /// Per-character comparison against the target, aligned by position —
  /// empty when the lengths differ enough that aligning would be
  /// misleading rather than helpful.
  final List<CharComparison> comparison;

  const PronunciationResult({
    required this.grade,
    required this.heard,
    this.comparison = const [],
  });

  bool get isCorrect => grade == PronunciationGrade.correct;

  /// The characters the learner got wrong, for a "watch this syllable"
  /// hint. Empty unless [comparison] was computed.
  List<CharComparison> get mistakes =>
      comparison.where((c) => !c.matches).toList();
}

class CharComparison {
  final String expected;
  final String heard;

  const CharComparison({required this.expected, required this.heard});

  bool get matches => expected == heard;
}

/// Listens to the learner's own attempt at a word and grades what the
/// on-device speech recognizer heard against the target.
///
/// This is a proxy for pronunciation quality, not a lab-grade phonetic
/// analysis: the recognizer resolves ambiguous audio to the single most
/// likely real word using its language model, the same way it would for
/// any dictation. What that buys us is still useful, though — Mandarin
/// tones are lexical, so a wrong tone usually lands on a *different real
/// character*, which is exactly what [PronunciationGrade.wrongWord] and
/// the per-character [CharComparison] surface. It cannot measure "right
/// character, slightly flat tone".
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

  /// Strips the whitespace and punctuation recognizers sprinkle in, so
  /// comparisons are against the characters alone.
  static String clean(String text) =>
      text.replaceAll(RegExp(r"[\s,.!?，。！？、'‘’]"), '');

  /// Grades one attempt at [targetHanzi].
  static PronunciationResult grade(String recognizedText, String targetHanzi) {
    final heard = clean(recognizedText);
    if (heard.isEmpty) {
      return const PronunciationResult(
        grade: PronunciationGrade.notHeard,
        heard: '',
      );
    }
    if (heard == targetHanzi) {
      return PronunciationResult(
        grade: PronunciationGrade.correct,
        heard: heard,
      );
    }
    if (heard.contains(targetHanzi)) {
      // The word is in there — count it as correct-with-noise rather than
      // failing someone who said the right thing with an "эм" attached.
      return PronunciationResult(
        grade: PronunciationGrade.closeExtraWords,
        heard: heard,
      );
    }
    if (heard.length == targetHanzi.length) {
      return PronunciationResult(
        grade: PronunciationGrade.wrongWord,
        heard: heard,
        comparison: [
          for (var i = 0; i < targetHanzi.length; i++)
            CharComparison(expected: targetHanzi[i], heard: heard[i]),
        ],
      );
    }
    return PronunciationResult(
      grade: PronunciationGrade.wrongWord,
      heard: heard,
    );
  }

  /// Loose match kept for callers that only need a yes/no.
  static bool matches(String recognizedText, String targetHanzi) =>
      clean(recognizedText).contains(targetHanzi);
}
