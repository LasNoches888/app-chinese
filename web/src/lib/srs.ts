import type { WordProgress } from '../types';

/**
 * Simplified SM-2, mirroring the backend's algorithm (see
 * backend/app/srs.py) so the "loop back into review" behavior matches
 * the rest of the product. quality is 0-5; below 3 counts as a miss.
 */
const MIN_EASE_FACTOR = 1.3;

export function freshProgress(wordId: string): WordProgress {
  return {
    wordId,
    repetitions: 0,
    easeFactor: 2.5,
    intervalDays: 0,
    dueDate: new Date().toISOString(),
    mistakes: 0,
  };
}

export function reviewWord(progress: WordProgress, quality: number, now = new Date()): WordProgress {
  const next: WordProgress = { ...progress };

  if (quality < 3) {
    next.repetitions = 0;
    next.intervalDays = 1;
    next.mistakes += 1;
  } else {
    if (next.repetitions === 0) next.intervalDays = 1;
    else if (next.repetitions === 1) next.intervalDays = 6;
    else next.intervalDays = Math.round(next.intervalDays * next.easeFactor);
    next.repetitions += 1;
  }

  const newEf = next.easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  next.easeFactor = Math.max(MIN_EASE_FACTOR, newEf);

  const due = new Date(now);
  due.setDate(due.getDate() + next.intervalDays);
  next.dueDate = due.toISOString();

  return next;
}

export function isDue(progress: WordProgress, now = new Date()): boolean {
  return new Date(progress.dueDate) <= now;
}
