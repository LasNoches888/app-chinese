class DialogueLine {
  final String speaker;
  final String hanzi;
  final String pinyin;
  final String translationRu;

  const DialogueLine({
    required this.speaker,
    required this.hanzi,
    required this.pinyin,
    required this.translationRu,
  });

  factory DialogueLine.fromJson(Map<String, dynamic> json) => DialogueLine(
    speaker: json['speaker'] as String,
    hanzi: json['hanzi'] as String,
    pinyin: json['pinyin'] as String,
    translationRu: json['translation_ru'] as String,
  );
}

/// A short curated two-speaker exchange for the listening exercise —
/// hand-written rather than generated, so it's guaranteed to read naturally
/// and stay fully offline (no LLM call needed just to practice listening).
class Dialogue {
  final String id;
  final String topic;
  final List<DialogueLine> lines;
  final String question;
  final List<String> options;
  final int correctIndex;

  const Dialogue({
    required this.id,
    required this.topic,
    required this.lines,
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  factory Dialogue.fromJson(Map<String, dynamic> json) => Dialogue(
    id: json['id'] as String,
    topic: json['topic'] as String,
    lines: (json['lines'] as List<dynamic>)
        .map((e) => DialogueLine.fromJson(e as Map<String, dynamic>))
        .toList(),
    question: json['question'] as String,
    options: (json['options'] as List<dynamic>).cast<String>(),
    correctIndex: json['correct_index'] as int,
  );

  String get fullText => lines.map((l) => l.hanzi).join(' ');
}
