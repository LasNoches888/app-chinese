export type TopicId =
  | 'greetings'
  | 'numbers'
  | 'people'
  | 'family'
  | 'food'
  | 'time'
  | 'colors'
  | 'movement';

export interface Word {
  id: string;
  hanzi: string;
  /** Space-separated syllables with tone marks, e.g. "xué shēng" */
  pinyin: string;
  translation: string;
  topic: TopicId;
  hsk: 1 | 2;
}

export interface ExampleSentence {
  id: string;
  wordIds: string[];
  hanzi: string;
  pinyin: string;
  translation: string;
}

export interface Lesson {
  id: string;
  topic: TopicId;
  title: string;
  wordIds: string[];
}

export type ExerciseType =
  | 'choose-translation'
  | 'choose-hanzi'
  | 'match-pinyin'
  | 'listen-choose'
  | 'build-sentence'
  | 'type-pinyin'
  | 'listen-tone';

export interface BaseQuestion {
  id: string;
  type: ExerciseType;
  wordId: string;
}

export interface ChoiceQuestion extends BaseQuestion {
  type: 'choose-translation' | 'choose-hanzi' | 'match-pinyin' | 'listen-choose';
  prompt: string;
  options: string[];
  correctOption: string;
}

export interface BuildSentenceQuestion extends BaseQuestion {
  type: 'build-sentence';
  sentenceId: string;
  promptTranslation: string;
  tiles: string[];
  correctOrder: string[];
}

export interface TypePinyinQuestion extends BaseQuestion {
  type: 'type-pinyin';
  hanzi: string;
  correctPinyin: string;
}

export interface ListenToneQuestion extends BaseQuestion {
  type: 'listen-tone';
  spokenText: string;
  correctTone: number;
  options: number[];
}

export type Question =
  | ChoiceQuestion
  | BuildSentenceQuestion
  | TypePinyinQuestion
  | ListenToneQuestion;

export type Direction = 'zh-ru' | 'ru-zh';

export interface WordProgress {
  wordId: string;
  repetitions: number;
  easeFactor: number;
  intervalDays: number;
  dueDate: string;
  mistakes: number;
}

export interface AppState {
  xpByDate: Record<string, number>;
  hearts: number;
  heartsUpdatedAt: string;
  dailyGoalXp: number;
  direction: Direction;
  theme: 'light' | 'dark';
  wordProgress: Record<string, WordProgress>;
  completedLessons: string[];
  totalReviews: number;
  perfectLessonsCount: number;
}
