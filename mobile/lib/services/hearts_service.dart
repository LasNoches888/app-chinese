import 'dart:math' as math;

/// Hearts regenerate on a wall-clock timer (one every [regenInterval]),
/// independent of app usage, and are fully restored instantly by
/// completing a review lesson (see ProgressRepository.restoreHeartsFully).
class HeartsService {
  static const int maxHearts = 5;
  static const Duration regenInterval = Duration(hours: 4);

  /// Applies elapsed-time regen. The returned `updatedAt` advances by
  /// exactly the consumed regen intervals (not reset to `now`), so partial
  /// progress toward the next heart isn't lost.
  static (int hearts, DateTime updatedAt) applyRegen({
    required int hearts,
    required DateTime updatedAt,
    DateTime? now,
  }) {
    if (hearts >= maxHearts) return (hearts, updatedAt);
    final effectiveNow = now ?? DateTime.now();
    final elapsedMs = effectiveNow.difference(updatedAt).inMilliseconds;
    final intervalMs = regenInterval.inMilliseconds;
    final regained = elapsedMs ~/ intervalMs;
    if (regained <= 0) return (hearts, updatedAt);
    final newHearts = math.min(maxHearts, hearts + regained);
    final consumed = Duration(milliseconds: intervalMs * regained);
    return (newHearts, updatedAt.add(consumed));
  }

  static Duration? timeToNextHeart({
    required int hearts,
    required DateTime updatedAt,
    DateTime? now,
  }) {
    if (hearts >= maxHearts) return null;
    final effectiveNow = now ?? DateTime.now();
    final elapsedMs = effectiveNow.difference(updatedAt).inMilliseconds;
    final intervalMs = regenInterval.inMilliseconds;
    final remainingMs = intervalMs - (elapsedMs % intervalMs);
    return Duration(milliseconds: remainingMs);
  }
}
