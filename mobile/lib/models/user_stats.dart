class UserStats {
  final int totalWords;
  final int learnedWords;
  final int weakWords;
  final int reviewsToday;
  final int streakDays;
  final double accuracyPercent;
  final int xpTotal;
  final int xpToday;
  final int level;
  final int dailyGoalXp;
  final List<String> achievements;

  UserStats({
    required this.totalWords,
    required this.learnedWords,
    required this.weakWords,
    required this.reviewsToday,
    required this.streakDays,
    required this.accuracyPercent,
    required this.xpTotal,
    required this.xpToday,
    required this.level,
    required this.dailyGoalXp,
    required this.achievements,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        totalWords: json['total_words'] as int,
        learnedWords: json['learned_words'] as int,
        weakWords: json['weak_words'] as int,
        reviewsToday: json['reviews_today'] as int,
        streakDays: json['streak_days'] as int,
        accuracyPercent: (json['accuracy_percent'] as num).toDouble(),
        xpTotal: json['xp_total'] as int,
        xpToday: json['xp_today'] as int,
        level: json['level'] as int,
        dailyGoalXp: json['daily_goal_xp'] as int,
        achievements: (json['achievements'] as List<dynamic>).map((e) => e as String).toList(),
      );
}
