import type { Lesson, TopicId } from '../types';
import { WORDS } from './words';

const TOPIC_TITLES: Record<TopicId, string> = {
  greetings: 'Приветствия',
  numbers: 'Числа',
  people: 'Люди',
  family: 'Семья',
  food: 'Еда',
  time: 'Время',
  colors: 'Цвета',
  movement: 'Движение',
};

const TOPIC_ORDER: TopicId[] = [
  'greetings',
  'numbers',
  'people',
  'family',
  'food',
  'time',
  'colors',
  'movement',
];

function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
}

export const LESSONS: Lesson[] = TOPIC_ORDER.flatMap((topic) => {
  const wordIds = WORDS.filter((w) => w.topic === topic).map((w) => w.id);
  const groups = chunk(wordIds, 10);
  return groups.map((ids, i) => ({
    id: groups.length > 1 ? `${topic}-${i + 1}` : topic,
    topic,
    title: groups.length > 1 ? `${TOPIC_TITLES[topic]} ${i + 1}` : TOPIC_TITLES[topic],
    wordIds: ids,
  }));
});

export const TOPIC_TITLE = TOPIC_TITLES;
