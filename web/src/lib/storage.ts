import type { AppState } from '../types';

const STORAGE_KEY = 'appchinese_web_state_v1';

export const DEFAULT_STATE: AppState = {
  xpByDate: {},
  hearts: 5,
  heartsUpdatedAt: new Date().toISOString(),
  dailyGoalXp: 10,
  direction: 'zh-ru',
  theme: 'light',
  wordProgress: {},
  completedLessons: [],
  totalReviews: 0,
  perfectLessonsCount: 0,
};

export function loadState(): AppState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { ...DEFAULT_STATE };
    const parsed = JSON.parse(raw) as Partial<AppState>;
    return { ...DEFAULT_STATE, ...parsed };
  } catch {
    return { ...DEFAULT_STATE };
  }
}

export function saveState(state: AppState): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

export function todayKey(date = new Date()): string {
  return date.toISOString().slice(0, 10);
}

export function computeStreak(xpByDate: Record<string, number>, today = new Date()): number {
  let streak = 0;
  const day = new Date(today);
  while (xpByDate[todayKey(day)] > 0) {
    streak += 1;
    day.setDate(day.getDate() - 1);
  }
  return streak;
}

export function computeLevel(totalXp: number): number {
  return Math.floor(totalXp / 100) + 1;
}

export function totalXp(xpByDate: Record<string, number>): number {
  return Object.values(xpByDate).reduce((sum, v) => sum + v, 0);
}
