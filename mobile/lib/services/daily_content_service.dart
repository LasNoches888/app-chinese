import 'dart:math';

/// Deterministic "same for everyone, changes once a day" picks from the
/// word bank — pure functions of the id list and the date, so the daily
/// challenge and word of the day need no server and stay stable if a
/// screen happens to rebuild twice on the same day.
class DailyContentService {
  static const dailyChallengeSize = 5;

  static List<String> dailyChallengeWordIds(
    List<String> allWordIds, {
    DateTime? now,
  }) {
    if (allWordIds.isEmpty) return [];
    final shuffled = List<String>.from(allWordIds)
      ..sort()
      ..shuffle(Random(_daySeed(now)));
    return shuffled.take(dailyChallengeSize).toList();
  }

  /// A different seed offset than the daily challenge's so the two don't
  /// always pick from the same shuffle order.
  static String wordOfTheDayId(List<String> allWordIds, {DateTime? now}) {
    if (allWordIds.isEmpty) return '';
    final sorted = List<String>.from(allWordIds)..sort();
    final rnd = Random(_daySeed(now) ^ 0x5bd1e995);
    return sorted[rnd.nextInt(sorted.length)];
  }

  static int _daySeed(DateTime? now) {
    final d = now ?? DateTime.now();
    return d.year * 10000 + d.month * 100 + d.day;
  }
}
