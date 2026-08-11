import type { Question } from '../types';
import { BuildSentenceExercise } from './exercises/BuildSentenceExercise';
import { ChoiceExercise } from './exercises/ChoiceExercise';
import { ListenChooseExercise } from './exercises/ListenChooseExercise';
import { ListenToneExercise } from './exercises/ListenToneExercise';
import { TypePinyinExercise } from './exercises/TypePinyinExercise';

export function QuestionRouter({
  question,
  onAnswer,
}: {
  question: Question;
  onAnswer: (correct: boolean) => void;
}) {
  switch (question.type) {
    case 'choose-translation':
    case 'choose-hanzi':
    case 'match-pinyin':
      return <ChoiceExercise question={question} onAnswer={onAnswer} />;
    case 'listen-choose':
      return <ListenChooseExercise question={question} onAnswer={onAnswer} />;
    case 'build-sentence':
      return <BuildSentenceExercise question={question} onAnswer={onAnswer} />;
    case 'type-pinyin':
      return <TypePinyinExercise question={question} onAnswer={onAnswer} />;
    case 'listen-tone':
      return <ListenToneExercise question={question} onAnswer={onAnswer} />;
    default:
      return null;
  }
}
