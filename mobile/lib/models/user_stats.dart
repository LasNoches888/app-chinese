class UserStats {
  final int totalWords;
  final int learnedWords;
  final int weakWords;
  final int reviewsToday;
  final int streakDays;
  final double accuracyPercent;

  UserStats({
    required this.totalWords,
    required this.learnedWords,
    required this.weakWords,
    required this.reviewsToday,
    required this.streakDays,
    required this.accuracyPercent,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        totalWords: json['total_words'] as int,
        learnedWords: json['learned_words'] as int,
        weakWords: json['weak_words'] as int,
        reviewsToday: json['reviews_today'] as int,
        streakDays: json['streak_days'] as int,
        accuracyPercent: (json['accuracy_percent'] as num).toDouble(),
      );
}
