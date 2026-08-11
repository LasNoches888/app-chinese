import { useEffect, useState } from 'react';
import type { ListenToneQuestion } from '../../types';
import { speakChinese } from '../../lib/tts';

const TONE_LABEL: Record<number, string> = {
  1: '1-й тон ˉ',
  2: '2-й тон ˊ',
  3: '3-й тон ˇ',
  4: '4-й тон ˋ',
  5: 'нейтральный',
};

export function ListenToneExercise({
  question,
  onAnswer,
}: {
  question: ListenToneQuestion;
  onAnswer: (correct: boolean) => void;
}) {
  const [selected, setSelected] = useState<number | null>(null);

  useEffect(() => {
    speakChinese(question.spokenText);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [question.id]);

  function select(tone: number) {
    if (selected !== null) return;
    setSelected(tone);
    setTimeout(() => onAnswer(tone === question.correctTone), 550);
  }

  function colorFor(tone: number) {
    if (selected === null) return '';
    if (tone === question.correctTone) return 'border-green-500 bg-green-50 dark:bg-green-900/30';
    if (tone === selected) return 'border-red-500 bg-red-50 dark:bg-red-900/30';
    return 'opacity-60';
  }

  return (
    <div className="flex flex-col items-center gap-6">
      <button
        onClick={() => speakChinese(question.spokenText)}
        className="flex h-20 w-20 items-center justify-center rounded-full bg-sky-500 text-3xl text-white shadow-lg transition hover:bg-sky-600"
        aria-label="Проиграть звук"
      >
        🔊
      </button>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        {question.options.map((tone) => (
          <button
            key={tone}
            onClick={() => select(tone)}
            className={`rounded-xl border-2 border-gray-200 px-4 py-4 text-lg font-medium dark:border-gray-700 ${colorFor(tone)}`}
          >
            {TONE_LABEL[tone]}
          </button>
        ))}
      </div>
    </div>
  );
}
