class Deck {
  final String id;
  final String title;
  final String topic;
  final int hskLevel;
  final int wordCount;

  const Deck({
    required this.id,
    required this.title,
    required this.topic,
    required this.hskLevel,
    required this.wordCount,
  });

  factory Deck.fromMap(Map<String, Object?> map) => Deck(
    id: map['id'] as String,
    title: map['title'] as String,
    topic: map['topic'] as String,
    hskLevel: map['hsk_level'] as int,
    wordCount: map['word_count'] as int,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'topic': topic,
    'hsk_level': hskLevel,
    'word_count': wordCount,
  };
}

class DeckProgress {
  final Deck deck;
  final bool completed;
  final bool unlocked;

  /// How many of the deck's words have graduated past the SRS "learned"
  /// threshold — shown as a per-deck progress bar so a long deck list
  /// communicates where the learner actually is, not just which decks were
  /// opened at least once.
  final int learnedWords;

  const DeckProgress({
    required this.deck,
    required this.completed,
    required this.unlocked,
    this.learnedWords = 0,
  });

  double get fraction =>
      deck.wordCount == 0 ? 0 : (learnedWords / deck.wordCount).clamp(0.0, 1.0);
}
