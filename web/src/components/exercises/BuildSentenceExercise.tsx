import { useState } from 'react';
import type { BuildSentenceQuestion } from '../../types';

export function BuildSentenceExercise({
  question,
  onAnswer,
}: {
  question: BuildSentenceQuestion;
  onAnswer: (correct: boolean) => void;
}) {
  const [selected, setSelected] = useState<string[]>([]);
  const [remaining, setRemaining] = useState<string[]>(question.tiles);
  const [checked, setChecked] = useState(false);
  const [correct, setCorrect] = useState(false);

  function pick(index: number) {
    if (checked) return;
    const tile = remaining[index];
    setSelected((s) => [...s, tile]);
    setRemaining((r) => r.filter((_, i) => i !== index));
  }

  function unpick(index: number) {
    if (checked) return;
    const tile = selected[index];
    setRemaining((r) => [...r, tile]);
    setSelected((s) => s.filter((_, i) => i !== index));
  }

  function check() {
    const isCorrect = selected.join('|') === question.correctOrder.join('|');
    setCorrect(isCorrect);
    setChecked(true);
    setTimeout(() => onAnswer(isCorrect), 900);
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="text-center text-lg text-gray-600 dark:text-gray-300">{question.promptTranslation}</div>
      <div
        className={`flex min-h-16 flex-wrap gap-2 rounded-xl border-2 border-dashed p-3 ${
          checked ? (correct ? 'border-green-500' : 'border-red-500') : 'border-gray-300 dark:border-gray-600'
        }`}
      >
        {selected.map((tile, i) => (
          <button
            key={i}
            onClick={() => unpick(i)}
            className="rounded-lg bg-sky-100 px-3 py-2 text-xl font-medium text-sky-800 dark:bg-sky-900/40 dark:text-sky-200"
          >
            {tile}
          </button>
        ))}
      </div>
      <div className="flex flex-wrap justify-center gap-2">
        {remaining.map((tile, i) => (
          <button
            key={i}
            onClick={() => pick(i)}
            className="rounded-lg border-2 border-gray-200 px-3 py-2 text-xl font-medium dark:border-gray-700"
          >
            {tile}
          </button>
        ))}
      </div>
      <button
        disabled={remaining.length > 0 || checked}
        onClick={check}
        className="mx-auto rounded-full bg-green-500 px-8 py-3 font-bold text-white disabled:opacity-40"
      >
        Проверить
      </button>
    </div>
  );
}
