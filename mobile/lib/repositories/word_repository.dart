import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import '../models/deck.dart';
import '../models/word.dart';

/// Owns the words/decks tables: seeding from the bundled JSON assets on
/// first launch (so the app is fully usable offline right out of the box)
/// and all read queries used by the lesson/review screens.
class WordRepository {
  final Database db;

  WordRepository(this.db);

  /// Loads the bundled decks/words into the database, upserting rather than
  /// only running on an empty database.
  ///
  /// This runs on every launch on purpose: an app update that ships new
  /// vocabulary has to reach existing installs too, and a first-run-only
  /// seed would leave everyone who already had the app stuck on whatever
  /// word list shipped the day they installed it. Rows are replaced by
  /// primary key, so learning progress — which lives in review_history,
  /// keyed by word id — is untouched.
  Future<void> seedIfNeeded() async {
    final decksJson =
        jsonDecode(await rootBundle.loadString('assets/seed/decks.json'))
            as List<dynamic>;
    final wordsJson =
        jsonDecode(await rootBundle.loadString('assets/seed/words.json'))
            as List<dynamic>;

    // Skip the write entirely when the bundled content is already fully
    // loaded, so the common case (no new content in this launch) doesn't
    // pay for a few hundred redundant upserts.
    final existingWords =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM words'),
        ) ??
        0;
    final existingDecks =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM decks'),
        ) ??
        0;
    if (existingWords >= wordsJson.length &&
        existingDecks >= decksJson.length) {
      return;
    }

    final batch = db.batch();
    for (final d in decksJson) {
      final map = d as Map<String, dynamic>;
      batch.insert('decks', {
        'id': map['id'],
        'title': map['title'],
        'topic': map['topic'],
        'hsk_level': map['hsk_level'],
        'word_count': map['word_count'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final w in wordsJson) {
      final map = w as Map<String, dynamic>;
      batch.insert('words', {
        'id': map['id'],
        'hanzi': map['hanzi'],
        'pinyin': map['pinyin'],
        'translation_ru': map['translation_ru'],
        'example_sentence': map['example_sentence'],
        'example_translation': map['example_translation'],
        'hsk_level': map['hsk_level'],
        'topic': map['topic'],
        'deck_id': map['deck_id'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Deck>> getDecks() async {
    final rows = await db.query('decks', orderBy: 'hsk_level, title');
    return rows.map(Deck.fromMap).toList();
  }

  Future<Deck?> getDeck(String deckId) async {
    final rows = await db.query('decks', where: 'id = ?', whereArgs: [deckId]);
    if (rows.isEmpty) return null;
    return Deck.fromMap(rows.first);
  }

  Future<List<Word>> getWordsForDeck(String deckId) async {
    final rows = await db.query(
      'words',
      where: 'deck_id = ?',
      whereArgs: [deckId],
    );
    return rows.map(Word.fromMap).toList();
  }

  Future<Word?> getWord(String wordId) async {
    final rows = await db.query('words', where: 'id = ?', whereArgs: [wordId]);
    if (rows.isEmpty) return null;
    return Word.fromMap(rows.first);
  }

  Future<List<Word>> getWordsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.query(
      'words',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    return rows.map(Word.fromMap).toList();
  }

  Future<List<Word>> getAllWords() async {
    final rows = await db.query('words');
    return rows.map(Word.fromMap).toList();
  }

  Future<int> countAllWords() async {
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM words'),
        ) ??
        0;
  }

  /// Random distractor words from anywhere in the word bank (excluding
  /// [excludeWordId]), used to build multiple-choice options.
  Future<List<Word>> randomDistractors(
    String excludeWordId, {
    required int count,
  }) async {
    final all = await getAllWords();
    all.removeWhere((w) => w.id == excludeWordId);
    all.shuffle(Random());
    return all.take(count).toList();
  }
}
