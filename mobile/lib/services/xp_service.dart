import 'dart:math' as math;

/// XP and level math, kept as pure functions so the rules are easy to
/// unit-test independently of the database/UI.
class XpService {
  static const int xpForCorrectAnswer = 10;
  static const int xpForIncorrectAttempt = 2;

  static int xpForAnswer(bool correct) =>
      correct ? xpForCorrectAnswer : xpForIncorrectAttempt;

  /// Level threshold: level N requires floor(100 * N^1.2) cumulative XP
  /// (level 1 starts at 0 XP). Returns the highest level fully reached.
  static int levelForXp(int totalXp) {
    var level = 1;
    while (totalXp >= _thresholdFor(level + 1)) {
      level += 1;
    }
    return level;
  }

  static int xpToNextLevel(int totalXp) {
    final level = levelForXp(totalXp);
    return _thresholdFor(level + 1) - totalXp;
  }

  /// Cumulative XP required to reach [level] (level 1 needs 0). Exposed for
  /// UI that shows progress *within* the current level (e.g. "560/1000 XP"
  /// toward the next one), which needs both ends of that level's span.
  static int thresholdForLevel(int level) => _thresholdFor(level);

  static int _thresholdFor(int level) {
    if (level <= 1) return 0;
    return (100 * math.pow(level.toDouble(), 1.2)).floor();
  }
}
