export interface AchievementDef {
  id: string;
  icon: string;
  label: string;
}

export const ACHIEVEMENTS: AchievementDef[] = [
  { id: 'first_step', icon: '🚩', label: 'Первый шаг' },
  { id: 'streak_3', icon: '🔥', label: '3 дня подряд' },
  { id: 'streak_7', icon: '🔥', label: '7 дней подряд' },
  { id: 'streak_30', icon: '🔥', label: '30 дней подряд' },
  { id: 'words_10', icon: '📖', label: '10 слов выучено' },
  { id: 'words_50', icon: '📖', label: '50 слов выучено' },
  { id: 'words_all', icon: '🏆', label: 'Весь словарь выучен' },
  { id: 'perfect_lesson', icon: '⭐', label: 'Урок без ошибок' },
];

export function computeUnlockedAchievements(stats: {
  totalReviews: number;
  streakDays: number;
  learnedWords: number;
  totalWords: number;
  hadPerfectLesson: boolean;
}): string[] {
  const unlocked: string[] = [];
  if (stats.totalReviews >= 1) unlocked.push('first_step');
  if (stats.streakDays >= 3) unlocked.push('streak_3');
  if (stats.streakDays >= 7) unlocked.push('streak_7');
  if (stats.streakDays >= 30) unlocked.push('streak_30');
  if (stats.learnedWords >= 10) unlocked.push('words_10');
  if (stats.learnedWords >= 50) unlocked.push('words_50');
  if (stats.totalWords > 0 && stats.learnedWords >= stats.totalWords) unlocked.push('words_all');
  if (stats.hadPerfectLesson) unlocked.push('perfect_lesson');
  return unlocked;
}
