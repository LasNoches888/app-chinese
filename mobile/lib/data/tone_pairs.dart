/// One tone variant of a syllable — e.g. "ma" said with tone 1 is 妈 (mother).
class ToneWord {
  final String hanzi;
  final String pinyin;
  final int tone;
  final String translationRu;

  const ToneWord({
    required this.hanzi,
    required this.pinyin,
    required this.tone,
    required this.translationRu,
  });
}

/// A curated minimal-pair set — same base syllable, different tones. Hand-
/// picked rather than pulled from the vocab bank: the point of a tone drill
/// is maximum phonetic contrast on one syllable, and the app's 75-word
/// bank doesn't have enough same-syllable pairs to build that reliably.
class TonePairSet {
  final String baseSyllable;
  final List<ToneWord> words;

  const TonePairSet({required this.baseSyllable, required this.words});
}

const kTonePairSets = <TonePairSet>[
  TonePairSet(
    baseSyllable: 'ma',
    words: [
      ToneWord(hanzi: '妈', pinyin: 'mā', tone: 1, translationRu: 'мама'),
      ToneWord(hanzi: '麻', pinyin: 'má', tone: 2, translationRu: 'конопля'),
      ToneWord(hanzi: '马', pinyin: 'mǎ', tone: 3, translationRu: 'лошадь'),
      ToneWord(hanzi: '骂', pinyin: 'mà', tone: 4, translationRu: 'ругать'),
    ],
  ),
  TonePairSet(
    baseSyllable: 'ba',
    words: [
      ToneWord(hanzi: '八', pinyin: 'bā', tone: 1, translationRu: 'восемь'),
      ToneWord(hanzi: '拔', pinyin: 'bá', tone: 2, translationRu: 'выдёргивать'),
      ToneWord(
        hanzi: '把',
        pinyin: 'bǎ',
        tone: 3,
        translationRu: 'частица (взять)',
      ),
      ToneWord(hanzi: '爸', pinyin: 'bà', tone: 4, translationRu: 'папа'),
    ],
  ),
  TonePairSet(
    baseSyllable: 'shu',
    words: [
      ToneWord(hanzi: '书', pinyin: 'shū', tone: 1, translationRu: 'книга'),
      ToneWord(hanzi: '熟', pinyin: 'shú', tone: 2, translationRu: 'спелый'),
      ToneWord(hanzi: '鼠', pinyin: 'shǔ', tone: 3, translationRu: 'мышь'),
      ToneWord(hanzi: '树', pinyin: 'shù', tone: 4, translationRu: 'дерево'),
    ],
  ),
  TonePairSet(
    baseSyllable: 'mai',
    words: [
      ToneWord(hanzi: '买', pinyin: 'mǎi', tone: 3, translationRu: 'покупать'),
      ToneWord(hanzi: '卖', pinyin: 'mài', tone: 4, translationRu: 'продавать'),
    ],
  ),
  TonePairSet(
    baseSyllable: 'tang',
    words: [
      ToneWord(hanzi: '汤', pinyin: 'tāng', tone: 1, translationRu: 'суп'),
      ToneWord(hanzi: '糖', pinyin: 'táng', tone: 2, translationRu: 'сахар'),
      ToneWord(hanzi: '躺', pinyin: 'tǎng', tone: 3, translationRu: 'лежать'),
      ToneWord(hanzi: '烫', pinyin: 'tàng', tone: 4, translationRu: 'горячий'),
    ],
  ),
  TonePairSet(
    baseSyllable: 'wen',
    words: [
      ToneWord(hanzi: '温', pinyin: 'wēn', tone: 1, translationRu: 'тёплый'),
      ToneWord(
        hanzi: '文',
        pinyin: 'wén',
        tone: 2,
        translationRu: 'письменность',
      ),
      ToneWord(hanzi: '吻', pinyin: 'wěn', tone: 3, translationRu: 'целовать'),
      ToneWord(hanzi: '问', pinyin: 'wèn', tone: 4, translationRu: 'спрашивать'),
    ],
  ),
  TonePairSet(
    baseSyllable: 'qi',
    words: [
      ToneWord(hanzi: '七', pinyin: 'qī', tone: 1, translationRu: 'семь'),
      ToneWord(
        hanzi: '骑',
        pinyin: 'qí',
        tone: 2,
        translationRu: 'ехать верхом',
      ),
      ToneWord(hanzi: '起', pinyin: 'qǐ', tone: 3, translationRu: 'вставать'),
      ToneWord(
        hanzi: '气',
        pinyin: 'qì',
        tone: 4,
        translationRu: 'воздух/злиться',
      ),
    ],
  ),
  TonePairSet(
    baseSyllable: 'yao',
    words: [
      ToneWord(hanzi: '腰', pinyin: 'yāo', tone: 1, translationRu: 'поясница'),
      ToneWord(hanzi: '摇', pinyin: 'yáo', tone: 2, translationRu: 'трясти'),
      ToneWord(hanzi: '咬', pinyin: 'yǎo', tone: 3, translationRu: 'кусать'),
      ToneWord(hanzi: '药', pinyin: 'yào', tone: 4, translationRu: 'лекарство'),
    ],
  ),
];
