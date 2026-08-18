class Word {
  final String id;
  final String hanzi;
  final String pinyin;
  final String translationRu;
  final String? exampleSentence;
  final String? exampleTranslation;
  final int hskLevel;
  final String topic;
  final String deckId;

  const Word({
    required this.id,
    required this.hanzi,
    required this.pinyin,
    required this.translationRu,
    this.exampleSentence,
    this.exampleTranslation,
    required this.hskLevel,
    required this.topic,
    required this.deckId,
  });

  factory Word.fromMap(Map<String, Object?> map) => Word(
    id: map['id'] as String,
    hanzi: map['hanzi'] as String,
    pinyin: map['pinyin'] as String,
    translationRu: map['translation_ru'] as String,
    exampleSentence: map['example_sentence'] as String?,
    exampleTranslation: map['example_translation'] as String?,
    hskLevel: map['hsk_level'] as int,
    topic: map['topic'] as String,
    deckId: map['deck_id'] as String,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'hanzi': hanzi,
    'pinyin': pinyin,
    'translation_ru': translationRu,
    'example_sentence': exampleSentence,
    'example_translation': exampleTranslation,
    'hsk_level': hskLevel,
    'topic': topic,
    'deck_id': deckId,
  };
}
