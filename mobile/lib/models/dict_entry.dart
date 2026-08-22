/// One CC-CEDICT entry, as shipped in the reference dictionary.
///
/// Deliberately not a [Word]: those are the app's taught vocabulary, with
/// decks, SRS state, examples and hand-checked Russian. These are 124k
/// reference entries whose Russian is machine-translated, and blurring
/// the two would let unreviewed text into lessons.
class DictEntry {
  final int id;
  final String simplified;
  final String traditional;

  /// Numbered pinyin as CC-CEDICT stores it ("ni3 hao3").
  final String pinyin;

  /// The Russian gloss. Machine-translated, so possibly wrong — which is
  /// exactly why [english] travels with it and is shown alongside.
  final String russian;
  final String english;

  const DictEntry({
    required this.id,
    required this.simplified,
    required this.traditional,
    required this.pinyin,
    required this.russian,
    required this.english,
  });

  /// True when simplified and traditional forms differ and both are worth
  /// showing.
  bool get hasDistinctTraditional => traditional != simplified;

  factory DictEntry.fromMap(Map<String, Object?> map) => DictEntry(
    id: map['id'] as int,
    simplified: map['simp'] as String,
    traditional: map['trad'] as String,
    pinyin: map['pinyin'] as String,
    russian: map['ru'] as String,
    english: map['en'] as String,
  );
}
