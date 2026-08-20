import 'package:app_chinese/services/daily_content_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ids = List.generate(50, (i) => 'w$i');

  group('DailyContentService.dailyChallengeWordIds', () {
    test('returns 5 distinct ids from the pool', () {
      final picks = DailyContentService.dailyChallengeWordIds(
        ids,
        now: DateTime(2026, 1, 10),
      );
      expect(picks.length, 5);
      expect(picks.toSet().length, 5);
      for (final id in picks) {
        expect(ids, contains(id));
      }
    });

    test('is the same for the same day regardless of time of day', () {
      final a = DailyContentService.dailyChallengeWordIds(
        ids,
        now: DateTime(2026, 1, 10, 3),
      );
      final b = DailyContentService.dailyChallengeWordIds(
        ids,
        now: DateTime(2026, 1, 10, 21),
      );
      expect(a, b);
    });

    test('changes on a different day', () {
      final a = DailyContentService.dailyChallengeWordIds(
        ids,
        now: DateTime(2026, 1, 10),
      );
      final b = DailyContentService.dailyChallengeWordIds(
        ids,
        now: DateTime(2026, 1, 11),
      );
      expect(a, isNot(b));
    });

    test('an empty pool yields an empty list', () {
      expect(
        DailyContentService.dailyChallengeWordIds(
          [],
          now: DateTime(2026, 1, 10),
        ),
        isEmpty,
      );
    });
  });

  group('DailyContentService.wordOfTheDayId', () {
    test('picks a word from the pool', () {
      final id = DailyContentService.wordOfTheDayId(
        ids,
        now: DateTime(2026, 1, 10),
      );
      expect(ids, contains(id));
    });

    test('is stable across calls on the same day', () {
      final a = DailyContentService.wordOfTheDayId(
        ids,
        now: DateTime(2026, 1, 10, 3),
      );
      final b = DailyContentService.wordOfTheDayId(
        ids,
        now: DateTime(2026, 1, 10, 21),
      );
      expect(a, b);
    });

    test('an empty pool yields an empty string', () {
      expect(
        DailyContentService.wordOfTheDayId([], now: DateTime(2026, 1, 10)),
        '',
      );
    });
  });
}
