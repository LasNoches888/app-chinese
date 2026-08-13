import 'package:app_chinese/services/hearts_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HeartsService.applyRegen', () {
    test('does nothing before a full interval has elapsed', () {
      final updatedAt = DateTime(2026, 1, 1, 0, 0);
      final (hearts, newUpdatedAt) = HeartsService.applyRegen(
        hearts: 3,
        updatedAt: updatedAt,
        now: updatedAt.add(const Duration(hours: 1)),
      );
      expect(hearts, 3);
      expect(newUpdatedAt, updatedAt);
    });

    test('regenerates exactly one heart per full interval elapsed', () {
      final updatedAt = DateTime(2026, 1, 1, 0, 0);
      final (hearts, newUpdatedAt) = HeartsService.applyRegen(
        hearts: 2,
        updatedAt: updatedAt,
        now: updatedAt.add(HeartsService.regenInterval),
      );
      expect(hearts, 3);
      expect(newUpdatedAt, updatedAt.add(HeartsService.regenInterval));
    });

    test('caps regeneration at the max even after a long time away', () {
      final updatedAt = DateTime(2026, 1, 1, 0, 0);
      final (hearts, _) = HeartsService.applyRegen(
        hearts: 1,
        updatedAt: updatedAt,
        now: updatedAt.add(const Duration(days: 30)),
      );
      expect(hearts, HeartsService.maxHearts);
    });

    test('is a no-op once already at max hearts', () {
      final updatedAt = DateTime(2026, 1, 1, 0, 0);
      final (hearts, newUpdatedAt) = HeartsService.applyRegen(
        hearts: HeartsService.maxHearts,
        updatedAt: updatedAt,
        now: updatedAt.add(const Duration(hours: 100)),
      );
      expect(hearts, HeartsService.maxHearts);
      expect(newUpdatedAt, updatedAt);
    });

    test('leftover partial progress toward the next heart is preserved', () {
      final updatedAt = DateTime(2026, 1, 1, 0, 0);
      final oneAndAHalfIntervals = HeartsService.regenInterval + (HeartsService.regenInterval ~/ 2);
      final (hearts, newUpdatedAt) = HeartsService.applyRegen(
        hearts: 2,
        updatedAt: updatedAt,
        now: updatedAt.add(oneAndAHalfIntervals),
      );
      expect(hearts, 3);
      expect(newUpdatedAt, updatedAt.add(HeartsService.regenInterval));
    });
  });
}
