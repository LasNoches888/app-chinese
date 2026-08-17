enum ExerciseType {
  flip,
  chooseTranslation,
  chooseHanzi,
  buildSentence,
  typePinyin,
  writeHanzi
}

class ExerciseQuestion {
  final String id;
  final String wordId;
  final ExerciseType type;

  // flip / choice
  final String? hanzi;
  final String? pinyin;
  final String? translation;

  // choice-specific
  final List<String>? options;
  final String? correctOption;

  // sentence-build
  final List<String>? tiles;
  final List<String>? correctOrder;
  final String? sentenceTranslation;

  // pinyin typing
  final String? correctPinyin;

  const ExerciseQuestion({
    required this.id,
    required this.wordId,
    required this.type,
    this.hanzi,
    this.pinyin,
    this.translation,
    this.options,
    this.correctOption,
    this.tiles,
    this.correctOrder,
    this.sentenceTranslation,
    this.correctPinyin,
  });
}
