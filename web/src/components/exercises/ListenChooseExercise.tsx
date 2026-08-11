import { useEffect } from 'react';
import type { ChoiceQuestion } from '../../types';
import { speakChinese } from '../../lib/tts';
import { ChoiceExercise } from './ChoiceExercise';

export function ListenChooseExercise({
  question,
  onAnswer,
}: {
  question: ChoiceQuestion;
  onAnswer: (correct: boolean) => void;
}) {
  useEffect(() => {
    speakChinese(question.prompt);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [question.id]);

  return (
    <div className="flex flex-col items-center gap-6">
      <button
        onClick={() => speakChinese(question.prompt)}
        className="flex h-20 w-20 items-center justify-center rounded-full bg-sky-500 text-3xl text-white shadow-lg transition hover:bg-sky-600"
        aria-label="Проиграть звук"
      >
        🔊
      </button>
      <div className="w-full">
        <ChoiceExercise question={question} onAnswer={onAnswer} hidePrompt />
      </div>
    </div>
  );
}
