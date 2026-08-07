class VocabCard {
  final String id;
  final String userId;
  final String word;
  final String pinyin;
  final String translation;
  final int repetitions;
  final double easeFactor;
  final int intervalDays;
  final DateTime dueDate;
  final bool weak;

  VocabCard({
    required this.id,
    required this.userId,
    required this.word,
    required this.pinyin,
    required this.translation,
    required this.repetitions,
    required this.easeFactor,
    required this.intervalDays,
    required this.dueDate,
    required this.weak,
  });

  factory VocabCard.fromJson(Map<String, dynamic> json) {
    return VocabCard(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      word: json['word'] as String,
      pinyin: json['pinyin'] as String,
      translation: json['translation'] as String,
      repetitions: json['repetitions'] as int,
      easeFactor: (json['ease_factor'] as num).toDouble(),
      intervalDays: json['interval_days'] as int,
      dueDate: DateTime.parse(json['due_date'] as String),
      weak: json['weak'] as bool,
    );
  }
}
