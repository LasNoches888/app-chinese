class DeckSummary {
  final String id;
  final String name;
  final int wordCount;

  DeckSummary({required this.id, required this.name, required this.wordCount});

  factory DeckSummary.fromJson(Map<String, dynamic> json) => DeckSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        wordCount: json['word_count'] as int,
      );
}
