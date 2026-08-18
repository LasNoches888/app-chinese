import 'package:app_chinese/services/srs_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  group('SrsService.review', () {
    test('first successful review sets interval to 1 day', () {
      final result = SrsService.review(
        prevRepetitions: 0,
        prevEaseFactor: SrsService.defaultEaseFactor,
        prevIntervalDays: 0,
        quality: 5,
        now: now,
      );
      expect(result.repetitions, 1);
      expect(result.intervalDays, 1);
      expect(result.nextReviewAt, now.add(const Duration(days: 1)));
    });

    test('second successful review jumps interval to 6 days', () {
      final result = SrsService.review(
        prevRepetitions: 1,
        prevEaseFactor: SrsService.defaultEaseFactor,
        prevIntervalDays: 1,
        quality: 5,
        now: now,
      );
      expect(result.repetitions, 2);
      expect(result.intervalDays, 6);
    });

    test('third+ successful review multiplies interval by ease factor', () {
      final result = SrsService.review(
        prevRepetitions: 2,
        prevEaseFactor: 2.5,
        prevIntervalDays: 6,
        quality: 5,
        now: now,
      );
      expect(result.repetitions, 3);
      expect(result.intervalDays, 15); // round(6 * 2.5)
    });

    test('failed review resets repetitions and interval to 1 day', () {
      final result = SrsService.review(
        prevRepetitions: 4,
        prevEaseFactor: 2.6,
        prevIntervalDays: 20,
        quality: 1,
        now: now,
      );
      expect(result.repetitions, 0);
      expect(result.intervalDays, 1);
    });

    test('ease factor never drops below the documented floor', () {
      final result = SrsService.review(
        prevRepetitions: 0,
        prevEaseFactor: SrsService.minEaseFactor,
        prevIntervalDays: 0,
        quality: 0,
        now: now,
      );
      expect(result.easeFactor, greaterThanOrEqualTo(SrsService.minEaseFactor));
    });

    test(
      'a good-but-not-perfect answer (quality 3) still grows the ease factor slightly',
      () {
        final result = SrsService.review(
          prevRepetitions: 2,
          prevEaseFactor: 2.5,
          prevIntervalDays: 6,
          quality: 5,
          now: now,
        );
        final resultLower = SrsService.review(
          prevRepetitions: 2,
          prevEaseFactor: 2.5,
          prevIntervalDays: 6,
          quality: 3,
          now: now,
        );
        expect(resultLower.easeFactor, lessThan(result.easeFactor));
      },
    );
  });

  group('SrsService.isLearned', () {
    test('is false before two successful repetitions', () {
      expect(SrsService.isLearned(0), isFalse);
      expect(SrsService.isLearned(1), isFalse);
    });

    test('is true from two repetitions onward', () {
      expect(SrsService.isLearned(2), isTrue);
      expect(SrsService.isLearned(5), isTrue);
    });
  });
}
