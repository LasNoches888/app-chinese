import { useState } from 'react';
import type { ChoiceQuestion } from '../../types';
import { ToneText } from '../ToneText';

export function ChoiceExercise({
  question,
  onAnswer,
  hidePrompt = false,
}: {
  question: ChoiceQuestion;
  onAnswer: (correct: boolean) => void;
  hidePrompt?: boolean;
}) {
  const [selected, setSelected] = useState<string | null>(null);
  const isPinyinOptions = question.type === 'match-pinyin';

  function select(option: string) {
    if (selected) return;
    setSelected(option);
    const correct = option === question.correctOption;
    setTimeout(() => onAnswer(correct), 550);
  }

  function colorFor(option: string) {
    if (!selected) return '';
    if (option === question.correctOption) return 'border-green-500 bg-green-50 dark:bg-green-900/30';
    if (option === selected) return 'border-red-500 bg-red-50 dark:bg-red-900/30';
    return 'opacity-60';
  }

  return (
    <div className="flex flex-col gap-6">
      {!hidePrompt && <div className="text-center text-4xl font-bold">{question.prompt}</div>}
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        {question.options.map((option) => (
          <button
            key={option}
            onClick={() => select(option)}
            className={`rounded-xl border-2 border-gray-200 px-4 py-4 text-lg font-medium transition dark:border-gray-700 ${colorFor(option)}`}
          >
            {isPinyinOptions ? <ToneText pinyin={option} /> : option}
          </button>
        ))}
      </div>
    </div>
  );
}
