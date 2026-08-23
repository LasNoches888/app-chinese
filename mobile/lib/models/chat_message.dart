class NewWord {
  final String word;
  final String pinyin;
  final String translation;

  NewWord({
    required this.word,
    required this.pinyin,
    required this.translation,
  });

  factory NewWord.fromJson(Map<String, dynamic> json) {
    return NewWord(
      word: json['word'] as String,
      pinyin: json['pinyin'] as String,
      translation: json['translation'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'pinyin': pinyin,
    'translation': translation,
  };
}

class ChatMessage {
  final int? id;
  final bool fromUser;
  final String text;
  final String? pinyin;
  final String? grammarRecast;
  final List<NewWord> newWords;

  /// Set when the app removed something from the reply it could prove
  /// false — see TutorFactChecker. Holds a string key, not a sentence, so
  /// the screen can render it in the learner's language.
  final String? note;

  final DateTime? createdAt;

  ChatMessage({
    this.id,
    required this.fromUser,
    required this.text,
    this.pinyin,
    this.grammarRecast,
    this.newWords = const [],
    this.note,
    this.createdAt,
  });

  ChatMessage copyWith({
    String? text,
    String? pinyin,
    String? grammarRecast,
    bool clearGrammarRecast = false,
    List<NewWord>? newWords,
    String? note,
  }) => ChatMessage(
    id: id,
    fromUser: fromUser,
    text: text ?? this.text,
    pinyin: pinyin ?? this.pinyin,
    grammarRecast: clearGrammarRecast
        ? null
        : (grammarRecast ?? this.grammarRecast),
    newWords: newWords ?? this.newWords,
    note: note ?? this.note,
    createdAt: createdAt,
  );

  factory ChatMessage.fromReplyJson(Map<String, dynamic> json) {
    return ChatMessage(
      fromUser: false,
      text: json['reply_zh'] as String,
      pinyin: json['reply_pinyin'] as String?,
      grammarRecast: json['grammar_recast'] as String?,
      newWords: (json['new_words_used'] as List<dynamic>? ?? [])
          .map((e) => NewWord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    fromUser: json['from_user'] as bool,
    text: json['text'] as String,
    pinyin: json['pinyin'] as String?,
    grammarRecast: json['grammar_recast'] as String?,
    newWords: (json['new_words'] as List<dynamic>? ?? [])
        .map((e) => NewWord.fromJson(e as Map<String, dynamic>))
        .toList(),
    note: json['note'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'from_user': fromUser,
    'text': text,
    'pinyin': pinyin,
    'grammar_recast': grammarRecast,
    'new_words': newWords.map((w) => w.toJson()).toList(),
    'note': note,
  };
}
