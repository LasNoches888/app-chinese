import type { Word } from '../types';

/**
 * Curated starter vocabulary across HSK1/2 topics. Structured so more
 * words/topics can be appended without touching any other module —
 * lessons.ts groups these by topic automatically.
 */
export const WORDS: Word[] = [
  // greetings
  { id: 'nihao', hanzi: '你好', pinyin: 'nǐ hǎo', translation: 'привет', topic: 'greetings', hsk: 1 },
  { id: 'xiexie', hanzi: '谢谢', pinyin: 'xiè xie', translation: 'спасибо', topic: 'greetings', hsk: 1 },
  { id: 'zaijian', hanzi: '再见', pinyin: 'zài jiàn', translation: 'до свидания', topic: 'greetings', hsk: 1 },
  { id: 'qing', hanzi: '请', pinyin: 'qǐng', translation: 'пожалуйста', topic: 'greetings', hsk: 1 },
  { id: 'duibuqi', hanzi: '对不起', pinyin: 'duì bu qǐ', translation: 'извините', topic: 'greetings', hsk: 1 },
  { id: 'meiguanxi', hanzi: '没关系', pinyin: 'méi guān xi', translation: 'ничего страшного', topic: 'greetings', hsk: 2 },
  { id: 'zaoshanghao', hanzi: '早上好', pinyin: 'zǎo shang hǎo', translation: 'доброе утро', topic: 'greetings', hsk: 1 },
  { id: 'wanshanghao', hanzi: '晚上好', pinyin: 'wǎn shang hǎo', translation: 'добрый вечер', topic: 'greetings', hsk: 1 },

  // numbers
  { id: 'yi', hanzi: '一', pinyin: 'yī', translation: 'один', topic: 'numbers', hsk: 1 },
  { id: 'er', hanzi: '二', pinyin: 'èr', translation: 'два', topic: 'numbers', hsk: 1 },
  { id: 'san', hanzi: '三', pinyin: 'sān', translation: 'три', topic: 'numbers', hsk: 1 },
  { id: 'si', hanzi: '四', pinyin: 'sì', translation: 'четыре', topic: 'numbers', hsk: 1 },
  { id: 'wu', hanzi: '五', pinyin: 'wǔ', translation: 'пять', topic: 'numbers', hsk: 1 },
  { id: 'liu', hanzi: '六', pinyin: 'liù', translation: 'шесть', topic: 'numbers', hsk: 1 },
  { id: 'qi', hanzi: '七', pinyin: 'qī', translation: 'семь', topic: 'numbers', hsk: 1 },
  { id: 'ba', hanzi: '八', pinyin: 'bā', translation: 'восемь', topic: 'numbers', hsk: 1 },
  { id: 'jiu', hanzi: '九', pinyin: 'jiǔ', translation: 'девять', topic: 'numbers', hsk: 1 },
  { id: 'shi', hanzi: '十', pinyin: 'shí', translation: 'десять', topic: 'numbers', hsk: 1 },

  // people / pronouns
  { id: 'wo', hanzi: '我', pinyin: 'wǒ', translation: 'я', topic: 'people', hsk: 1 },
  { id: 'ni', hanzi: '你', pinyin: 'nǐ', translation: 'ты', topic: 'people', hsk: 1 },
  { id: 'ta_m', hanzi: '他', pinyin: 'tā', translation: 'он', topic: 'people', hsk: 1 },
  { id: 'ta_f', hanzi: '她', pinyin: 'tā', translation: 'она', topic: 'people', hsk: 1 },
  { id: 'women', hanzi: '我们', pinyin: 'wǒ men', translation: 'мы', topic: 'people', hsk: 1 },
  { id: 'shi_verb', hanzi: '是', pinyin: 'shì', translation: 'быть / являться', topic: 'people', hsk: 1 },
  { id: 'bu', hanzi: '不', pinyin: 'bù', translation: 'не', topic: 'people', hsk: 1 },
  { id: 'hao', hanzi: '好', pinyin: 'hǎo', translation: 'хороший', topic: 'people', hsk: 1 },
  { id: 'ren', hanzi: '人', pinyin: 'rén', translation: 'человек', topic: 'people', hsk: 1 },
  { id: 'xuesheng', hanzi: '学生', pinyin: 'xué sheng', translation: 'студент', topic: 'people', hsk: 1 },
  { id: 'laoshi', hanzi: '老师', pinyin: 'lǎo shī', translation: 'учитель', topic: 'people', hsk: 1 },

  // family
  { id: 'baba', hanzi: '爸爸', pinyin: 'bà ba', translation: 'папа', topic: 'family', hsk: 1 },
  { id: 'mama', hanzi: '妈妈', pinyin: 'mā ma', translation: 'мама', topic: 'family', hsk: 1 },
  { id: 'gege', hanzi: '哥哥', pinyin: 'gē ge', translation: 'старший брат', topic: 'family', hsk: 1 },
  { id: 'jiejie', hanzi: '姐姐', pinyin: 'jiě jie', translation: 'старшая сестра', topic: 'family', hsk: 1 },
  { id: 'didi', hanzi: '弟弟', pinyin: 'dì di', translation: 'младший брат', topic: 'family', hsk: 2 },
  { id: 'meimei', hanzi: '妹妹', pinyin: 'mèi mei', translation: 'младшая сестра', topic: 'family', hsk: 2 },
  { id: 'erzi', hanzi: '儿子', pinyin: 'ér zi', translation: 'сын', topic: 'family', hsk: 2 },
  { id: 'nver', hanzi: '女儿', pinyin: 'nǚ ér', translation: 'дочь', topic: 'family', hsk: 2 },
  { id: 'jia', hanzi: '家', pinyin: 'jiā', translation: 'дом / семья', topic: 'family', hsk: 1 },
  { id: 'pengyou', hanzi: '朋友', pinyin: 'péng you', translation: 'друг', topic: 'family', hsk: 1 },

  // food
  { id: 'mifan', hanzi: '米饭', pinyin: 'mǐ fàn', translation: 'рис', topic: 'food', hsk: 1 },
  { id: 'miantiao', hanzi: '面条', pinyin: 'miàn tiáo', translation: 'лапша', topic: 'food', hsk: 2 },
  { id: 'shui', hanzi: '水', pinyin: 'shuǐ', translation: 'вода', topic: 'food', hsk: 1 },
  { id: 'cha', hanzi: '茶', pinyin: 'chá', translation: 'чай', topic: 'food', hsk: 1 },
  { id: 'kafei', hanzi: '咖啡', pinyin: 'kā fēi', translation: 'кофе', topic: 'food', hsk: 2 },
  { id: 'pingguo', hanzi: '苹果', pinyin: 'píng guǒ', translation: 'яблоко', topic: 'food', hsk: 1 },
  { id: 'jidan', hanzi: '鸡蛋', pinyin: 'jī dàn', translation: 'яйцо', topic: 'food', hsk: 2 },
  { id: 'niunai', hanzi: '牛奶', pinyin: 'niú nǎi', translation: 'молоко', topic: 'food', hsk: 2 },
  { id: 'haochi', hanzi: '好吃', pinyin: 'hǎo chī', translation: 'вкусный', topic: 'food', hsk: 2 },
  { id: 'chi', hanzi: '吃', pinyin: 'chī', translation: 'есть (кушать)', topic: 'food', hsk: 1 },
  { id: 'he', hanzi: '喝', pinyin: 'hē', translation: 'пить', topic: 'food', hsk: 1 },

  // time
  { id: 'jintian', hanzi: '今天', pinyin: 'jīn tiān', translation: 'сегодня', topic: 'time', hsk: 1 },
  { id: 'mingtian', hanzi: '明天', pinyin: 'míng tiān', translation: 'завтра', topic: 'time', hsk: 1 },
  { id: 'zuotian', hanzi: '昨天', pinyin: 'zuó tiān', translation: 'вчера', topic: 'time', hsk: 1 },
  { id: 'xianzai', hanzi: '现在', pinyin: 'xiàn zài', translation: 'сейчас', topic: 'time', hsk: 1 },
  { id: 'shijian', hanzi: '时间', pinyin: 'shí jiān', translation: 'время', topic: 'time', hsk: 2 },
  { id: 'xiaoshi', hanzi: '小时', pinyin: 'xiǎo shí', translation: 'час', topic: 'time', hsk: 2 },
  { id: 'fenzhong', hanzi: '分钟', pinyin: 'fēn zhōng', translation: 'минута', topic: 'time', hsk: 2 },
  { id: 'xingqi', hanzi: '星期', pinyin: 'xīng qī', translation: 'неделя', topic: 'time', hsk: 1 },
  { id: 'nian', hanzi: '年', pinyin: 'nián', translation: 'год', topic: 'time', hsk: 1 },
  { id: 'yue', hanzi: '月', pinyin: 'yuè', translation: 'месяц', topic: 'time', hsk: 1 },

  // colors
  { id: 'hongse', hanzi: '红色', pinyin: 'hóng sè', translation: 'красный', topic: 'colors', hsk: 2 },
  { id: 'huangse', hanzi: '黄色', pinyin: 'huáng sè', translation: 'жёлтый', topic: 'colors', hsk: 2 },
  { id: 'lanse', hanzi: '蓝色', pinyin: 'lán sè', translation: 'синий', topic: 'colors', hsk: 2 },
  { id: 'lvse', hanzi: '绿色', pinyin: 'lǜ sè', translation: 'зелёный', topic: 'colors', hsk: 2 },
  { id: 'heise', hanzi: '黑色', pinyin: 'hēi sè', translation: 'чёрный', topic: 'colors', hsk: 2 },
  { id: 'baise', hanzi: '白色', pinyin: 'bái sè', translation: 'белый', topic: 'colors', hsk: 2 },
  { id: 'yanse', hanzi: '颜色', pinyin: 'yán sè', translation: 'цвет', topic: 'colors', hsk: 2 },

  // movement verbs
  { id: 'qu', hanzi: '去', pinyin: 'qù', translation: 'идти / ехать (туда)', topic: 'movement', hsk: 1 },
  { id: 'lai', hanzi: '来', pinyin: 'lái', translation: 'приходить', topic: 'movement', hsk: 1 },
  { id: 'zou', hanzi: '走', pinyin: 'zǒu', translation: 'идти пешком', topic: 'movement', hsk: 2 },
  { id: 'pao', hanzi: '跑', pinyin: 'pǎo', translation: 'бежать', topic: 'movement', hsk: 2 },
  { id: 'huijia', hanzi: '回家', pinyin: 'huí jiā', translation: 'возвращаться домой', topic: 'movement', hsk: 2 },
  { id: 'shangban', hanzi: '上班', pinyin: 'shàng bān', translation: 'идти на работу', topic: 'movement', hsk: 2 },
  { id: 'zuo', hanzi: '坐', pinyin: 'zuò', translation: 'сидеть / ехать на', topic: 'movement', hsk: 1 },
  { id: 'fei', hanzi: '飞', pinyin: 'fēi', translation: 'летать', topic: 'movement', hsk: 2 },
];

export const WORDS_BY_ID: Record<string, Word> = Object.fromEntries(
  WORDS.map((w) => [w.id, w]),
);
