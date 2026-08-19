class ReadingPassage {
  final String id;
  final String topic;
  final String text;
  final String translationRu;
  final String question;
  final List<String> options;
  final int correctIndex;

  const ReadingPassage({
    required this.id,
    required this.topic,
    required this.text,
    required this.translationRu,
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  factory ReadingPassage.fromJson(Map<String, dynamic> json) => ReadingPassage(
    id: json['id'] as String,
    topic: json['topic'] as String,
    text: json['text'] as String,
    translationRu: json['translation_ru'] as String,
    question: json['question'] as String,
    options: (json['options'] as List<dynamic>).cast<String>(),
    correctIndex: json['correct_index'] as int,
  );
}
