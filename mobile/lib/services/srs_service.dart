/// Simplified SM-2 spaced repetition, mirroring backend/app/srs.py so the
/// algorithm stays consistent across the (optional) backend and the
/// offline-first mobile app. quality is 0-5; below 3 counts as a miss.
class SrsResult {
  final int repetitions;
  final double easeFactor;
  final int intervalDays;
  final DateTime nextReviewAt;

  const SrsResult({
    required this.repetitions,
    required this.easeFactor,
    required this.intervalDays,
    required this.nextReviewAt,
  });
}

class SrsService {
  static const double minEaseFactor = 1.3;
  static const double defaultEaseFactor = 2.5;

  /// [prevRepetitions]/[prevEaseFactor]/[prevIntervalDays] describe the
  /// word's state before this review (0/2.5/0 for a brand-new word).
  static SrsResult review({
    required int prevRepetitions,
    required double prevEaseFactor,
    required int prevIntervalDays,
    required int quality,
    DateTime? now,
  }) {
    assert(quality >= 0 && quality <= 5);
    final effectiveNow = now ?? DateTime.now();

    int repetitions;
    int intervalDays;
    if (quality < 3) {
      repetitions = 0;
      intervalDays = 1;
    } else {
      if (prevRepetitions == 0) {
        intervalDays = 1;
      } else if (prevRepetitions == 1) {
        intervalDays = 6;
      } else {
        intervalDays = (prevIntervalDays * prevEaseFactor).round();
      }
      repetitions = prevRepetitions + 1;
    }

    final newEf =
        prevEaseFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    final easeFactor = newEf < minEaseFactor ? minEaseFactor : newEf;

    return SrsResult(
      repetitions: repetitions,
      easeFactor: easeFactor,
      intervalDays: intervalDays,
      nextReviewAt: effectiveNow.add(Duration(days: intervalDays)),
    );
  }

  /// A word counts as "learned" once it has graduated past the first two
  /// successful reviews (matches the interval jumping to 6+ days).
  static bool isLearned(int repetitions) => repetitions >= 2;
}
