import 'package:sqflite/sqflite.dart';

import '../db/dictionary_database.dart';
import '../models/dict_entry.dart';

/// Searches the shipped reference dictionary.
///
/// Which column to search is decided by the script the query is written
/// in, because that is unambiguous and free: nobody types Cyrillic
/// looking for pinyin.
///
/// Ranking is the whole game here. 124k entries match a query like "вода"
/// loosely, and sorting by how exactly they match answers with obscure
/// literary characters whose single gloss happens to be that one word.
/// So match quality and usage frequency are combined into one score,
/// where one tier of match quality is worth about one order of magnitude
/// of frequency — enough that 水 beats 涠, and an exact gloss still beats
/// a passing mention.
class DictionaryRepository {
  final Future<Database> Function() _open;

  DictionaryRepository({Future<Database> Function()? open})
    : _open = open ?? DictionaryDatabase.open;

  static final _han = RegExp(r'[㐀-䶿一-鿿]');
  static final _cyrillic = RegExp(r'[Ѐ-ӿ]');
  static final _digits = RegExp(r'[0-9]');

  /// One match tier is worth this much frequency (frequency is Zipf ×100,
  /// so 120 is a little over one order of magnitude of usage).
  static const _tierWeight = 120;

  /// Cross-reference entries ("see 吃[chi1]") give up half a tier: they
  /// share a headword and a frequency with the entry that holds the
  /// actual meaning, and should never outrank it.
  static const _refPenalty = 60;

  Future<List<DictEntry>> search(String query, {int limit = 60}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final db = await _open();

    if (_han.hasMatch(q)) return _byHanzi(db, q, limit);
    if (_cyrillic.hasMatch(q)) return _byRussian(db, q.toLowerCase(), limit);

    final pinyin = await _byPinyin(db, _plainPinyin(q), limit);
    // A Latin query that isn't pinyin is almost certainly English, and
    // the English glosses are right there.
    return pinyin.isNotEmpty ? pinyin : _byEnglish(db, q.toLowerCase(), limit);
  }

  /// The entry for an exact headword, used when opening a word's details.
  Future<DictEntry?> lookupExact(String hanzi) async {
    final db = await _open();
    final rows = await db.query(
      'entries',
      where: 'simp = ? OR trad = ?',
      whereArgs: [hanzi, hanzi],
      orderBy: 'is_ref, freq DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : DictEntry.fromMap(rows.first);
  }

  /// Authoritative pinyin for a batch of exact headwords.
  ///
  /// One query for the whole batch: the caller is transcribing a sentence
  /// and needs every candidate substring at once, and a round trip per
  /// candidate would be dozens of queries for one chat reply.
  ///
  /// Where a headword has several readings, the most common non-reference
  /// one wins — the same rule [lookupExact] uses.
  Future<Map<String, String>> pinyinFor(Iterable<String> words) async {
    final wanted = words.toSet().toList();
    if (wanted.isEmpty) return const {};
    final db = await _open();
    final placeholders = List.filled(wanted.length, '?').join(',');
    final rows = await db.rawQuery(
      '''
      SELECT simp, trad, pinyin FROM entries
      WHERE simp IN ($placeholders) OR trad IN ($placeholders)
      ORDER BY is_ref, freq DESC, weight, id
    ''',
      [...wanted, ...wanted],
    );

    final result = <String, String>{};
    for (final row in rows) {
      // Rows arrive best-first, so the first reading seen for a headword
      // is the one to keep.
      result.putIfAbsent(row['simp'] as String, () => row['pinyin'] as String);
      result.putIfAbsent(row['trad'] as String, () => row['pinyin'] as String);
    }
    return result;
  }

  Future<List<DictEntry>> _byHanzi(Database db, String q, int limit) => _run(
    db,
    '''
        SELECT * FROM entries
        WHERE simp LIKE ?1 || '%' OR trad LIKE ?1 || '%'
        ORDER BY
          (CASE WHEN simp = ?1 OR trad = ?1 THEN 0 ELSE 1 END) * $_tierWeight
            - freq + is_ref * $_refPenalty,
          weight, id
        LIMIT ?2
      ''',
    [q, limit],
  );

  Future<List<DictEntry>> _byPinyin(Database db, String q, int limit) => _run(
    db,
    '''
        SELECT * FROM entries
        WHERE pinyin_plain LIKE ?1 || '%'
        ORDER BY
          (CASE WHEN pinyin_plain = ?1 THEN 0 ELSE 1 END) * $_tierWeight
            - freq + is_ref * $_refPenalty,
          weight, id
        LIMIT ?2
      ''',
    [q, limit],
  );

  /// Russian queries match on a stem, because Russian is inflected and
  /// nobody looks a word up in the exact form the gloss happens to use —
  /// "воду" has to find "вода", and the machine translation writes 水 as
  /// "воды" rather than "вода" anyway.
  ///
  /// Glosses are stored "; "-joined, so one that *starts* a segment is a
  /// primary meaning and outranks one buried mid-phrase. A stem-only hit
  /// ranks a tier lower, because a stem is blunt enough to catch
  /// unrelated words — "гор" finds "гореть" as readily as "гора".
  Future<List<DictEntry>> _byRussian(Database db, String q, int limit) {
    final stem = _stem(q);
    return _run(
      db,
      '''
        SELECT * FROM entries
        WHERE ru LIKE '%' || ?1 || '%' OR ru LIKE '%' || ?2 || '%'
        ORDER BY
          (CASE
            WHEN ru = ?3 THEN 0
            WHEN ru LIKE ?3 || '%' OR ru LIKE '%; ' || ?3 || '%' THEN 1
            WHEN ru LIKE '%' || ?3 || '%'
              OR ru LIKE ?1 || '%' OR ru LIKE '%; ' || ?1 || '%' THEN 2
            ELSE 3
          END) * $_tierWeight - freq + is_ref * $_refPenalty,
          weight, id
        LIMIT ?4
      ''',
      [stem, _capitalise(stem), q, limit],
    );
  }

  Future<List<DictEntry>> _byEnglish(Database db, String q, int limit) => _run(
    db,
    '''
        SELECT * FROM entries
        WHERE en LIKE '%' || ?1 || '%'
        ORDER BY
          (CASE
            WHEN en = ?1 THEN 0
            WHEN en LIKE ?1 || '%' OR en LIKE '%; ' || ?1 || '%' THEN 1
            ELSE 2
          END) * $_tierWeight - freq + is_ref * $_refPenalty,
          weight, id
        LIMIT ?2
      ''',
    [q, limit],
  );

  Future<List<DictEntry>> _run(
    Database db,
    String sql,
    List<Object?> args,
  ) async {
    final rows = await db.rawQuery(sql, args);
    return rows.map(DictEntry.fromMap).toList();
  }

  /// Chops off a Russian ending. Blunt truncation rather than a real
  /// stemmer: it only has to survive a `LIKE`, over-matching costs
  /// nothing (frequency sorts the extras below), and under-matching would
  /// lose the entry entirely.
  static String _stem(String q) {
    if (q.length >= 6) return q.substring(0, q.length - 2);
    if (q.length >= 4) return q.substring(0, q.length - 1);
    return q;
  }

  /// Proper nouns keep their capital in storage, so a lowercase query has
  /// to try both.
  static String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Tone marks and tone digits both come off, and separators with them,
  /// so "nǐ hǎo", "ni3hao3" and "nihao" are one query.
  static String _plainPinyin(String input) {
    const marks = {
      'ā': 'a',
      'á': 'a',
      'ǎ': 'a',
      'à': 'a',
      'ē': 'e',
      'é': 'e',
      'ě': 'e',
      'è': 'e',
      'ī': 'i',
      'í': 'i',
      'ǐ': 'i',
      'ì': 'i',
      'ō': 'o',
      'ó': 'o',
      'ǒ': 'o',
      'ò': 'o',
      'ū': 'u',
      'ú': 'u',
      'ǔ': 'u',
      'ù': 'u',
      'ǖ': 'v',
      'ǘ': 'v',
      'ǚ': 'v',
      'ǜ': 'v',
      'ü': 'v',
    };
    final buffer = StringBuffer();
    for (final ch in input.toLowerCase().split('')) {
      if (ch.trim().isEmpty || "'’-".contains(ch)) continue;
      if (_digits.hasMatch(ch)) continue;
      buffer.write(marks[ch] ?? ch);
    }
    return buffer.toString();
  }
}
