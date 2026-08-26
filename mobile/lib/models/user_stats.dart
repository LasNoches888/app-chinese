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
  final int streakFreezes;
  final int dailyChallengesCompleted;
  final int raceWins;
  final int listeningCompleted;
  final int pronunciationCompleted;
  final String mascotCharacter;
  final int equippedOutfit;

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
    required this.streakFreezes,
    required this.dailyChallengesCompleted,
    required this.raceWins,
    required this.listeningCompleted,
    required this.pronunciationCompleted,
    this.mascotCharacter = 'panda',
    this.equippedOutfit = 0,
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
    streakFreezes: map['streak_freezes'] as int? ?? 0,
    dailyChallengesCompleted: map['daily_challenges_completed'] as int? ?? 0,
    raceWins: map['race_wins'] as int? ?? 0,
    listeningCompleted: map['listening_completed'] as int? ?? 0,
    pronunciationCompleted: map['pronunciation_completed'] as int? ?? 0,
    mascotCharacter: map['mascot_character'] as String? ?? 'panda',
    equippedOutfit: map['equipped_outfit'] as int? ?? 0,
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
    int? streakFreezes,
    int? dailyChallengesCompleted,
    int? raceWins,
    int? listeningCompleted,
    int? pronunciationCompleted,
    String? mascotCharacter,
    int? equippedOutfit,
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
      streakFreezes: streakFreezes ?? this.streakFreezes,
      dailyChallengesCompleted:
          dailyChallengesCompleted ?? this.dailyChallengesCompleted,
      raceWins: raceWins ?? this.raceWins,
      listeningCompleted: listeningCompleted ?? this.listeningCompleted,
      pronunciationCompleted:
          pronunciationCompleted ?? this.pronunciationCompleted,
      mascotCharacter: mascotCharacter ?? this.mascotCharacter,
      equippedOutfit: equippedOutfit ?? this.equippedOutfit,
    );
  }
}
