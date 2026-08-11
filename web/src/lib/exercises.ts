import type {
  BuildSentenceQuestion,
  ChoiceQuestion,
  Direction,
  ExerciseType,
  ListenToneQuestion,
  Question,
  TypePinyinQuestion,
  Word,
} from '../types';
import { SENTENCES } from '../data/sentences';
import { WORDS, WORDS_BY_ID } from '../data/words';
import { toneOfSyllable } from './tone';

function shuffle<T>(arr: T[]): T[] {
  const copy = [...arr];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function sample<T>(arr: T[], n: number): T[] {
  return shuffle(arr).slice(0, n);
}

function distractorTranslations(word: Word, pool: Word[], count: number): string[] {
  const others = pool.filter((w) => w.id !== word.id && w.translation !== word.translation);
  return sample(others, count).map((w) => w.translation);
}

function distractorHanzi(word: Word, pool: Word[], count: number): string[] {
  const others = pool.filter((w) => w.id !== word.id && w.hanzi !== word.hanzi);
  return sample(others, count).map((w) => w.hanzi);
}

function distractorPinyin(word: Word, pool: Word[], count: number): string[] {
  const others = pool.filter((w) => w.id !== word.id && w.pinyin !== word.pinyin);
  return sample(others, count).map((w) => w.pinyin);
}

function buildChoiceQuestion(
  id: string,
  type: ChoiceQuestion['type'],
  word: Word,
  prompt: string,
  correctOption: string,
  distractors: string[],
): ChoiceQuestion {
  const options = shuffle([correctOption, ...distractors]);
  return { id, type, wordId: word.id, prompt, options, correctOption };
}

export function buildLessonQuestions(
  wordIds: string[],
  direction: Direction,
  opts: { includeSentences?: boolean } = {},
): Question[] {
  const words = wordIds.map((id) => WORDS_BY_ID[id]).filter(Boolean);
  const pool = WORDS;
  const questions: Question[] = [];
  const types: ExerciseType[] = [
    'choose-translation',
    'choose-hanzi',
    'match-pinyin',
    'listen-choose',
    'type-pinyin',
    'listen-tone',
  ];

  words.forEach((word, i) => {
    const type = types[i % types.length];
    const qid = `${word.id}-${type}-${i}`;
    switch (type) {
      case 'choose-translation': {
        const prompt = direction === 'zh-ru' ? word.hanzi : word.translation;
        questions.push(
          buildChoiceQuestion(
            qid,
            'choose-translation',
            word,
            prompt,
            word.translation,
            distractorTranslations(word, pool, 3),
          ),
        );
        break;
      }
      case 'choose-hanzi': {
        questions.push(
          buildChoiceQuestion(
            qid,
            'choose-hanzi',
            word,
            word.translation,
            word.hanzi,
            distractorHanzi(word, pool, 3),
          ),
        );
        break;
      }
      case 'match-pinyin': {
        questions.push(
          buildChoiceQuestion(
            qid,
            'match-pinyin',
            word,
            word.hanzi,
            word.pinyin,
            distractorPinyin(word, pool, 3),
          ),
        );
        break;
      }
      case 'listen-choose': {
        const useTranslation = Math.random() < 0.5;
        const correct = useTranslation ? word.translation : word.hanzi;
        const distractors = useTranslation
          ? distractorTranslations(word, pool, 3)
          : distractorHanzi(word, pool, 3);
        questions.push(buildChoiceQuestion(qid, 'listen-choose', word, word.hanzi, correct, distractors));
        break;
      }
      case 'type-pinyin': {
        const q: TypePinyinQuestion = {
          id: qid,
          type: 'type-pinyin',
          wordId: word.id,
          hanzi: word.hanzi,
          correctPinyin: word.pinyin,
        };
        questions.push(q);
        break;
      }
      case 'listen-tone': {
        const syllables = word.pinyin.split(' ');
        const idx = Math.floor(Math.random() * syllables.length);
        const correctTone = toneOfSyllable(syllables[idx]);
        const q: ListenToneQuestion = {
          id: qid,
          type: 'listen-tone',
          wordId: word.id,
          spokenText: word.hanzi,
          correctTone,
          options: shuffle([1, 2, 3, 4, 5]),
        };
        questions.push(q);
        break;
      }
      default:
        break;
    }
  });

  if (opts.includeSentences !== false) {
    const relevant = SENTENCES.filter((s) => s.wordIds.some((id) => wordIds.includes(id)));
    const chosen = sample(relevant, Math.min(2, relevant.length));
    chosen.forEach((sentence, i) => {
      const tiles = shuffle(sentence.hanzi.split(' '));
      const q: BuildSentenceQuestion = {
        id: `sentence-${sentence.id}-${i}`,
        type: 'build-sentence',
        wordId: sentence.wordIds[0],
        sentenceId: sentence.id,
        promptTranslation: sentence.translation,
        tiles,
        correctOrder: sentence.hanzi.split(' '),
      };
      questions.push(q);
    });
  }

  return shuffle(questions);
}
