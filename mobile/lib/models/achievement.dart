class AchievementDef {
  final String code;
  final String icon;
  final String titleKey;
  final String descriptionKey;

  const AchievementDef({
    required this.code,
    required this.icon,
    required this.titleKey,
    required this.descriptionKey,
  });
}

/// The 8 achievements required by spec: streak milestones, word-count
/// milestones, a perfect (no-mistake) lesson, and finishing all of HSK1.
/// Titles/descriptions are looked up in app_strings.dart by key so they
/// stay localizable rather than hardcoded here.
const List<AchievementDef> kAchievementDefs = [
  AchievementDef(
    code: 'streak_3',
    icon: '🔥',
    titleKey: 'achStreak3',
    descriptionKey: 'achStreak3Desc',
  ),
  AchievementDef(
    code: 'streak_7',
    icon: '🔥',
    titleKey: 'achStreak7',
    descriptionKey: 'achStreak7Desc',
  ),
  AchievementDef(
    code: 'streak_30',
    icon: '🔥',
    titleKey: 'achStreak30',
    descriptionKey: 'achStreak30Desc',
  ),
  AchievementDef(
    code: 'words_50',
    icon: '📖',
    titleKey: 'achWords50',
    descriptionKey: 'achWords50Desc',
  ),
  AchievementDef(
    code: 'words_100',
    icon: '📖',
    titleKey: 'achWords100',
    descriptionKey: 'achWords100Desc',
  ),
  AchievementDef(
    code: 'words_300',
    icon: '📚',
    titleKey: 'achWords300',
    descriptionKey: 'achWords300Desc',
  ),
  AchievementDef(
    code: 'perfect_lesson',
    icon: '⭐',
    titleKey: 'achPerfectLesson',
    descriptionKey: 'achPerfectLessonDesc',
  ),
  AchievementDef(
    code: 'hsk1_complete',
    icon: '🏆',
    titleKey: 'achHsk1',
    descriptionKey: 'achHsk1Desc',
  ),
];

class UnlockedAchievement {
  final String code;
  final DateTime unlockedAt;

  const UnlockedAchievement({required this.code, required this.unlockedAt});
}
