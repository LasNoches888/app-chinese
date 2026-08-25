import 'package:speech_to_text/speech_to_text.dart';

import 'pinyin.dart';

/// How close the learner's attempt was, best first.
enum PronunciationGrade {
  /// The recognizer resolved the audio to exactly the target word.
  correct,

  /// A different character with identical pinyin, tones included — 他/她
  /// are both "tā". The recognizer picked the wrong one from context, but
  /// the learner's mouth did the right thing, so this is a pass.
  homophone,

  /// The target word is in there, surrounded by other words — usually a
  /// hesitation or the recognizer catching a longer phrase.
  closeExtraWords,

  /// Right syllables, wrong tones. The one failure this can diagnose
  /// precisely, and the one learners most need to hear about.
  toneMiss,

  /// Something else entirely.
  wrongWord,

  /// Nothing usable: silence, non-Chinese, or too noisy.
  notHeard,
}

class PronunciationResult {
  final PronunciationGrade grade;

  /// What the recognizer heard, cleaned of punctuation.
  final String heard;

  /// Pinyin of [heard], when it's a word the app knows. Empty otherwise —
  /// the recognizer can return anything, and guessing a reading for an
  /// unknown string would be worse than saying nothing.
  final String heardPinyin;

  /// Per-character comparison against the target, aligned by position.
  /// Empty when the lengths differ enough that aligning would mislead.
  final List<CharComparison> comparison;

  const PronunciationResult({
    required this.grade,
    required this.heard,
    this.heardPinyin = '',
    this.comparison = const [],
  });

  /// Whether the learner's pronunciation was good enough to move on. A
  /// homophone counts: they said the right sounds.
  bool get isPass =>
      grade == PronunciationGrade.correct ||
      grade == PronunciationGrade.homophone;

  bool get isExact => grade == PronunciationGrade.correct;

  /// The characters that came out differently, for a "watch this syllable"
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

/// Listens to the learner's attempt at a word and grades it against the
/// target.
///
/// This reads the on-device recognizer's output rather than analysing the
/// audio signal, so it can't measure "right character, slightly flat
/// tone". What it *can* do is exploit the fact that Mandarin tones are
/// lexical: say 妈 with the wrong tone and the recognizer hears 马, a
/// different real character. Comparing the pinyin of what was heard
/// against the target's turns that into an actual tone diagnosis instead
/// of a bare "wrong".
class PronunciationService {
  static final SpeechToText _speech = SpeechToText();
  static bool _initialized = false;
  static bool _available = false;

  static bool get isListening => _speech.isListening;

  /// Probes for a working speech recognizer. Safe to call repeatedly and
  /// safe to call where none exists (no mic permission, no recognizer
  /// installed, or a test environment with no platform channels) — it
  /// just leaves it unavailable.
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

  /// Starts listening. [onResult] receives every transcription the
  /// recognizer offers — `alternates` is ordered best-first and often
  /// holds the right word in second place, which is why the grader looks
  /// at all of them rather than only the headline guess.
  static Future<void> listen({
    required void Function(List<String> alternates, bool isFinal) onResult,
    String localeId = 'zh-CN',
  }) async {
    if (!await ensureInitialized()) return;
    await _speech.listen(
      onResult: (result) => onResult(
        result.alternates.map((a) => a.recognizedWords).toList(),
        result.finalResult,
      ),
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
        cancelOnError: true,
        // These are single words, not dictation. Waiting two seconds of
        // silence before finalizing made every attempt feel sluggish;
        // one second is still comfortably past the gap inside a
        // two-syllable word.
        pauseFor: const Duration(seconds: 1),
        listenFor: const Duration(seconds: 6),
      ),
    );
  }

  static Future<void> stop() => _speech.stop();

  /// Strips the whitespace and punctuation recognizers sprinkle in, so
  /// comparisons are against the characters alone.
  static String clean(String text) =>
      text.replaceAll(RegExp(r"[\s,.!?，。！？、'‘’]"), '');

  /// Grades one attempt.
  ///
  /// [alternates] is the recognizer's candidate list, best first.
  /// [pinyinByHanzi] maps known words to their pinyin so a homophone or a
  /// tone slip can be told apart from a genuinely wrong word; pass an
  /// empty map to fall back to character-only comparison.
  static PronunciationResult grade({
    required List<String> alternates,
    required String targetHanzi,
    required String targetPinyin,
    Map<String, String> pinyinByHanzi = const {},
  }) {
    final candidates = alternates
        .map(clean)
        .where((c) => c.isNotEmpty)
        .toList();
    if (candidates.isEmpty) {
      return const PronunciationResult(
        grade: PronunciationGrade.notHeard,
        heard: '',
      );
    }

    PronunciationResult? best;
    for (final heard in candidates) {
      final result = _gradeOne(
        heard: heard,
        targetHanzi: targetHanzi,
        targetPinyin: targetPinyin,
        pinyinByHanzi: pinyinByHanzi,
      );
      // Grades are declared best-first, so a lower index is a better
      // outcome — an alternate that nails it outranks the headline guess.
      if (best == null || result.grade.index < best.grade.index) {
        best = result;
      }
      if (best.grade == PronunciationGrade.correct) break;
    }
    return best!;
  }

  static PronunciationResult _gradeOne({
    required String heard,
    required String targetHanzi,
    required String targetPinyin,
    required Map<String, String> pinyinByHanzi,
  }) {
    if (heard == targetHanzi) {
      return PronunciationResult(
        grade: PronunciationGrade.correct,
        heard: heard,
        heardPinyin: targetPinyin,
      );
    }

    final heardPinyin = pinyinByHanzi[heard] ?? '';

    if (heardPinyin.isNotEmpty) {
      if (Pinyin.sameWithTones(heardPinyin, targetPinyin)) {
        // Identical sounds, different character — the learner said it
        // right and the recognizer just picked another spelling of it.
        return PronunciationResult(
          grade: PronunciationGrade.homophone,
          heard: heard,
          heardPinyin: heardPinyin,
        );
      }
      if (Pinyin.isToneOnlyDifference(heardPinyin, targetPinyin)) {
        return PronunciationResult(
          grade: PronunciationGrade.toneMiss,
          heard: heard,
          heardPinyin: heardPinyin,
          comparison: _align(heard, targetHanzi),
        );
      }
    }

    if (heard.contains(targetHanzi)) {
      return PronunciationResult(
        grade: PronunciationGrade.closeExtraWords,
        heard: heard,
        heardPinyin: heardPinyin,
      );
    }

    return PronunciationResult(
      grade: PronunciationGrade.wrongWord,
      heard: heard,
      heardPinyin: heardPinyin,
      comparison: _align(heard, targetHanzi),
    );
  }

  /// Character-by-character alignment, only when the lengths match —
  /// pairing up strings of different lengths would point at the wrong
  /// syllable, which is worse than pointing at none.
  static List<CharComparison> _align(String heard, String target) {
    if (heard.length != target.length) return const [];
    return [
      for (var i = 0; i < target.length; i++)
        CharComparison(expected: target[i], heard: heard[i]),
    ];
  }

  /// Grades that settle the verdict as soon as they show up in a partial
  /// transcript — no more audio is going to change "right sounds, wrong
  /// tone" back into "wrong word".
  static const _conclusiveGrades = {
    PronunciationGrade.correct,
    PronunciationGrade.homophone,
    PronunciationGrade.toneMiss,
  };

  /// Whether an in-progress (partial) transcription is already good
  /// enough to stop listening and grade — saves waiting out the trailing
  /// silence once the outcome is already clear.
  ///
  /// Only checking for an exact hanzi match here used to mean the app
  /// answered instantly when the learner got it right, but sat through
  /// the full pause for the one case that matters most: right syllables,
  /// wrong tone. Running the real grader against the partial fixes that —
  /// [PronunciationGrade.toneMiss] is just as conclusive as an exact
  /// match, so it gets the same early stop.
  ///
  /// [wrongWord] and [closeExtraWords] are deliberately excluded: an
  /// early partial reading as "something else" can still resolve into the
  /// target word as the recognizer keeps refining it, so those wait out
  /// the natural pause rather than risk cutting the learner off mid-word.
  static bool isConclusive({
    required List<String> alternates,
    required String targetHanzi,
    required String targetPinyin,
    Map<String, String> pinyinByHanzi = const {},
  }) {
    for (final heard in alternates.map(clean).where((c) => c.isNotEmpty)) {
      final result = _gradeOne(
        heard: heard,
        targetHanzi: targetHanzi,
        targetPinyin: targetPinyin,
        pinyinByHanzi: pinyinByHanzi,
      );
      if (_conclusiveGrades.contains(result.grade)) return true;
    }
    return false;
  }
}
