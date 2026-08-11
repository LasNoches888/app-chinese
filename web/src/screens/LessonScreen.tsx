import { useEffect, useMemo, useState } from 'react';
import type { Word } from '../types';
import { WORDS_BY_ID } from '../data/words';
import { buildLessonQuestions } from '../lib/exercises';
import { useProgress } from '../state/ProgressContext';
import { ProgressBar } from '../components/ProgressBar';
import { HeartsRow } from '../components/HeartsRow';
import { QuestionRouter } from '../components/QuestionRouter';

export interface LessonResult {
  xpEarned: number;
  mistakes: Word[];
  perfect: boolean;
}

export function LessonScreen({
  wordIds,
  title,
  lessonId,
  onExit,
  onComplete,
}: {
  wordIds: string[];
  title: string;
  lessonId: string;
  onExit: () => void;
  onComplete: (result: LessonResult) => void;
}) {
  const { state, addXp, loseHeart, reviewWordProgress, completeLesson, hasHearts } = useProgress();
  const questions = useMemo(() => buildLessonQuestions(wordIds, state.direction), [wordIds, state.direction]);
  const [index, setIndex] = useState(0);
  const [xpEarned, setXpEarned] = useState(0);
  const [mistakeIds, setMistakeIds] = useState<Set<string>>(new Set());
  const [feedback, setFeedback] = useState<'correct' | 'incorrect' | null>(null);

  const current = questions[index];

  useEffect(() => {
    if (!hasHearts) onExit();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [hasHearts]);

  function handleAnswer(correct: boolean) {
    if (!current) return;
    reviewWordProgress(current.wordId, correct ? 5 : 1);

    const earned = correct ? 10 : 2;
    addXp(earned);
    const newXpEarned = xpEarned + earned;
    setXpEarned(newXpEarned);

    let newMistakeIds = mistakeIds;
    if (!correct) {
      loseHeart();
      newMistakeIds = new Set(mistakeIds).add(current.wordId);
      setMistakeIds(newMistakeIds);
    }
    setFeedback(correct ? 'correct' : 'incorrect');

    setTimeout(() => {
      setFeedback(null);
      if (index + 1 >= questions.length) {
        const perfect = newMistakeIds.size === 0;
        completeLesson(lessonId, perfect);
        onComplete({
          xpEarned: newXpEarned,
          mistakes: Array.from(newMistakeIds)
            .map((id) => WORDS_BY_ID[id])
            .filter((w): w is Word => Boolean(w)),
          perfect,
        });
      } else {
        setIndex((i) => i + 1);
      }
    }, 300);
  }

  if (!current) {
    return (
      <div className="flex min-h-screen items-center justify-center px-4 text-center text-gray-500">
        Нет слов для этого урока.
        <button onClick={onExit} className="ml-2 underline">
          Назад
        </button>
      </div>
    );
  }

  return (
    <div className="mx-auto flex min-h-screen max-w-lg flex-col px-4 py-6">
      <div className="mb-4 flex items-center gap-3">
        <button onClick={onExit} className="text-2xl text-gray-400 hover:text-gray-600" aria-label="Выйти">
          ×
        </button>
        <ProgressBar value={index / questions.length} className="flex-1" />
        <HeartsRow hearts={state.hearts} />
      </div>
      <div className="mb-2 text-center text-sm text-gray-500 dark:text-gray-400">{title}</div>
      <div
        className={[
          'flex flex-1 flex-col justify-center rounded-2xl p-4 transition-colors',
          feedback === 'correct' ? 'bg-green-50 dark:bg-green-950/30' : '',
          feedback === 'incorrect' ? 'animate-shake bg-red-50 dark:bg-red-950/30' : '',
        ].join(' ')}
      >
        <QuestionRouter key={current.id} question={current} onAnswer={handleAnswer} />
      </div>
    </div>
  );
}
