class UserStats {
  final int totalXp;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActivityDate;
  final int heartsCurrent;
  final int heartsMax;
  final DateTime heartsUpdatedAt;
  final int dailyGoalXp;
  final int xpToday;
  final String? xpTodayDate;
  final int perfectLessonsCount;

  const UserStats({
    required this.totalXp,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastActivityDate,
    required this.heartsCurrent,
    required this.heartsMax,
    required this.heartsUpdatedAt,
    required this.dailyGoalXp,
    required this.xpToday,
    required this.xpTodayDate,
    required this.perfectLessonsCount,
  });

  factory UserStats.fromMap(Map<String, Object?> map) => UserStats(
    totalXp: map['total_xp'] as int,
    currentStreak: map['current_streak'] as int,
    longestStreak: map['longest_streak'] as int,
    lastActivityDate: map['last_activity_date'] == null
        ? null
        : DateTime.parse(map['last_activity_date'] as String),
    heartsCurrent: map['hearts_current'] as int,
    heartsMax: map['hearts_max'] as int,
    heartsUpdatedAt: DateTime.fromMillisecondsSinceEpoch(
      map['hearts_updated_at'] as int,
    ),
    dailyGoalXp: map['daily_goal_xp'] as int,
    xpToday: map['xp_today'] as int,
    xpTodayDate: map['xp_today_date'] as String?,
    perfectLessonsCount: map['perfect_lessons_count'] as int,
  );

  UserStats copyWith({
    int? totalXp,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActivityDate,
    int? heartsCurrent,
    int? heartsMax,
    DateTime? heartsUpdatedAt,
    int? dailyGoalXp,
    int? xpToday,
    String? xpTodayDate,
    int? perfectLessonsCount,
  }) {
    return UserStats(
      totalXp: totalXp ?? this.totalXp,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      heartsCurrent: heartsCurrent ?? this.heartsCurrent,
      heartsMax: heartsMax ?? this.heartsMax,
      heartsUpdatedAt: heartsUpdatedAt ?? this.heartsUpdatedAt,
      dailyGoalXp: dailyGoalXp ?? this.dailyGoalXp,
      xpToday: xpToday ?? this.xpToday,
      xpTodayDate: xpTodayDate ?? this.xpTodayDate,
      perfectLessonsCount: perfectLessonsCount ?? this.perfectLessonsCount,
    );
  }
}
