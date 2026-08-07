class NewWord {
  final String word;
  final String pinyin;
  final String translation;

  NewWord({required this.word, required this.pinyin, required this.translation});

  factory NewWord.fromJson(Map<String, dynamic> json) {
    return NewWord(
      word: json['word'] as String,
      pinyin: json['pinyin'] as String,
      translation: json['translation'] as String,
    );
  }
}

class ChatMessage {
  final bool fromUser;
  final String text;
  final String? pinyin;
  final String? grammarRecast;
  final List<NewWord> newWords;

  ChatMessage({
    required this.fromUser,
    required this.text,
    this.pinyin,
    this.grammarRecast,
    this.newWords = const [],
  });

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
}
