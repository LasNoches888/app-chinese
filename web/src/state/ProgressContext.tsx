import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import type { AppState, Direction } from '../types';
import { WORDS } from '../data/words';
import { computeUnlockedAchievements } from '../lib/achievements';
import { freshProgress, isDue, reviewWord } from '../lib/srs';
import { computeLevel, computeStreak, loadState, saveState, todayKey, totalXp } from '../lib/storage';

const HEART_REGEN_MINUTES = 30;
const MAX_HEARTS = 5;

interface ProgressContextValue {
  state: AppState;
  streakDays: number;
  xpToday: number;
  xpTotal: number;
  level: number;
  dueWordIds: string[];
  learnedWordIds: string[];
  unlockedAchievements: string[];
  minutesToNextHeart: number | null;
  addXp: (amount: number) => void;
  loseHeart: () => void;
  hasHearts: boolean;
  restoreHeartsFully: () => void;
  reviewWordProgress: (wordId: string, quality: number) => void;
  completeLesson: (lessonId: string, perfect: boolean) => void;
  setDirection: (d: Direction) => void;
  setDailyGoalXp: (xp: number) => void;
  setTheme: (t: 'light' | 'dark') => void;
}

const ProgressContext = createContext<ProgressContextValue | null>(null);

function applyHeartRegen(state: AppState): AppState {
  if (state.hearts >= MAX_HEARTS) return state;
  const last = new Date(state.heartsUpdatedAt).getTime();
  const elapsedMinutes = (Date.now() - last) / 60_000;
  const regained = Math.floor(elapsedMinutes / HEART_REGEN_MINUTES);
  if (regained <= 0) return state;
  const newHearts = Math.min(MAX_HEARTS, state.hearts + regained);
  const consumedMs = regained * HEART_REGEN_MINUTES * 60_000;
  return { ...state, hearts: newHearts, heartsUpdatedAt: new Date(last + consumedMs).toISOString() };
}

export function ProgressProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<AppState>(() => applyHeartRegen(loadState()));

  useEffect(() => {
    saveState(state);
  }, [state]);

  useEffect(() => {
    const id = setInterval(() => setState((s) => applyHeartRegen(s)), 60_000);
    return () => clearInterval(id);
  }, []);

  useEffect(() => {
    document.documentElement.classList.toggle('dark', state.theme === 'dark');
  }, [state.theme]);

  const addXp = useCallback((amount: number) => {
    setState((s) => {
      const key = todayKey();
      return { ...s, xpByDate: { ...s.xpByDate, [key]: (s.xpByDate[key] ?? 0) + amount } };
    });
  }, []);

  const loseHeart = useCallback(() => {
    setState((s) => ({
      ...s,
      hearts: Math.max(0, s.hearts - 1),
      heartsUpdatedAt: s.hearts >= MAX_HEARTS ? new Date().toISOString() : s.heartsUpdatedAt,
    }));
  }, []);

  const restoreHeartsFully = useCallback(() => {
    setState((s) => ({ ...s, hearts: MAX_HEARTS, heartsUpdatedAt: new Date().toISOString() }));
  }, []);

  const reviewWordProgress = useCallback((wordId: string, quality: number) => {
    setState((s) => {
      const current = s.wordProgress[wordId] ?? freshProgress(wordId);
      const updated = reviewWord(current, quality);
      return {
        ...s,
        wordProgress: { ...s.wordProgress, [wordId]: updated },
        totalReviews: s.totalReviews + 1,
      };
    });
  }, []);

  const completeLesson = useCallback((lessonId: string, perfect: boolean) => {
    setState((s) => ({
      ...s,
      completedLessons: s.completedLessons.includes(lessonId)
        ? s.completedLessons
        : [...s.completedLessons, lessonId],
      perfectLessonsCount: perfect ? s.perfectLessonsCount + 1 : s.perfectLessonsCount,
    }));
  }, []);

  const setDirection = useCallback((d: Direction) => setState((s) => ({ ...s, direction: d })), []);
  const setDailyGoalXp = useCallback((xp: number) => setState((s) => ({ ...s, dailyGoalXp: xp })), []);
  const setTheme = useCallback((t: 'light' | 'dark') => setState((s) => ({ ...s, theme: t })), []);

  const streakDays = useMemo(() => computeStreak(state.xpByDate), [state.xpByDate]);
  const xpTotal = useMemo(() => totalXp(state.xpByDate), [state.xpByDate]);
  const xpToday = state.xpByDate[todayKey()] ?? 0;
  const level = computeLevel(xpTotal);

  const dueWordIds = useMemo(
    () => WORDS.map((w) => w.id).filter((id) => {
      const p = state.wordProgress[id];
      return p ? isDue(p) : false;
    }),
    [state.wordProgress],
  );

  const learnedWordIds = useMemo(
    () =>
      Object.values(state.wordProgress)
        .filter((p) => p.repetitions >= 2)
        .map((p) => p.wordId),
    [state.wordProgress],
  );

  const unlockedAchievements = useMemo(
    () =>
      computeUnlockedAchievements({
        totalReviews: state.totalReviews,
        streakDays,
        learnedWords: learnedWordIds.length,
        totalWords: WORDS.length,
        hadPerfectLesson: state.perfectLessonsCount > 0,
      }),
    [state.totalReviews, streakDays, learnedWordIds.length, state.perfectLessonsCount],
  );

  const minutesToNextHeart = useMemo(() => {
    if (state.hearts >= MAX_HEARTS) return null;
    const last = new Date(state.heartsUpdatedAt).getTime();
    const elapsed = (Date.now() - last) / 60_000;
    return Math.max(0, Math.ceil(HEART_REGEN_MINUTES - elapsed));
  }, [state.hearts, state.heartsUpdatedAt]);

  const value: ProgressContextValue = {
    state,
    streakDays,
    xpToday,
    xpTotal,
    level,
    dueWordIds,
    learnedWordIds,
    unlockedAchievements,
    minutesToNextHeart,
    addXp,
    loseHeart,
    hasHearts: state.hearts > 0,
    restoreHeartsFully,
    reviewWordProgress,
    completeLesson,
    setDirection,
    setDailyGoalXp,
    setTheme,
  };

  return <ProgressContext.Provider value={value}>{children}</ProgressContext.Provider>;
}

export function useProgress(): ProgressContextValue {
  const ctx = useContext(ProgressContext);
  if (!ctx) throw new Error('useProgress must be used within ProgressProvider');
  return ctx;
}
