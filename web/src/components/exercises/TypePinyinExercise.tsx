import { useState } from 'react';
import type { TypePinyinQuestion } from '../../types';
import { stripTones } from '../../lib/tone';

export function TypePinyinExercise({
  question,
  onAnswer,
}: {
  question: TypePinyinQuestion;
  onAnswer: (correct: boolean) => void;
}) {
  const [value, setValue] = useState('');
  const [checked, setChecked] = useState(false);
  const [correct, setCorrect] = useState(false);

  function check() {
    const isCorrect = stripTones(value) === stripTones(question.correctPinyin);
    setCorrect(isCorrect);
    setChecked(true);
    setTimeout(() => onAnswer(isCorrect), 1000);
  }

  return (
    <div className="flex flex-col items-center gap-6">
      <div className="text-center text-5xl font-bold">{question.hanzi}</div>
      <input
        autoFocus
        disabled={checked}
        value={value}
        onChange={(e) => setValue(e.target.value)}
        onKeyDown={(e) => e.key === 'Enter' && !checked && value.trim() && check()}
        placeholder="введите пиньинь, напр. ni hao"
        className="w-64 rounded-xl border-2 border-gray-300 px-4 py-3 text-center text-lg focus:border-sky-500 focus:outline-none dark:border-gray-600 dark:bg-gray-800"
      />
      {checked && (
        <div className={`text-sm ${correct ? 'text-green-600' : 'text-red-500'}`}>
          Правильно: <span className="font-semibold">{question.correctPinyin}</span>
        </div>
      )}
      <button
        disabled={!value.trim() || checked}
        onClick={check}
        className="rounded-full bg-green-500 px-8 py-3 font-bold text-white disabled:opacity-40"
      >
        Проверить
      </button>
    </div>
  );
}
