import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the bundled learning content itself.
///
/// Reading and listening material had drifted into using perfectly common
/// characters the word bank never actually taught (要, 早上, 吧, 别 …), so
/// passages asked the learner to read things the app had never introduced.
/// That's invisible in code review and invisible at runtime — it only
/// shows up as "why don't I understand this". These read the seed JSON
/// straight off disk so a future content edit can't reintroduce it.
void main() {
  late List<Map<String, dynamic>> words;
  late List<Map<String, dynamic>> decks;
  late List<Map<String, dynamic>> passages;
  late List<Map<String, dynamic>> dialogues;
  late Map<String, dynamic> strokeData;

  List<Map<String, dynamic>> readList(String path) =>
      (jsonDecode(File(path).readAsStringSync()) as List<dynamic>)
          .cast<Map<String, dynamic>>();

  setUpAll(() {
    words = readList('assets/seed/words.json');
    decks = readList('assets/seed/decks.json');
    passages = readList('assets/seed/reading_passages.json');
    dialogues = readList('assets/seed/dialogues.json');
    strokeData =
        jsonDecode(File('assets/seed/stroke_data.json').readAsStringSync())
            as Map<String, dynamic>;
  });

  Set<String> taughtCharacters() {
    final chars = <String>{};
    for (final w in words) {
      chars.addAll((w['hanzi'] as String).split(''));
    }
    return chars;
  }

  bool isHan(String c) {
    final code = c.runes.first;
    return code >= 0x4e00 && code <= 0x9fff;
  }

  Set<String> untaught(String text, Set<String> taught) =>
      text.split('').where((c) => isHan(c) && !taught.contains(c)).toSet();

  test('every reading passage only uses characters the app teaches', () {
    final taught = taughtCharacters();
    final offenders = <String, String>{};
    for (final p in passages) {
      final bad = untaught(p['text'] as String, taught);
      if (bad.isNotEmpty) offenders[p['id'] as String] = bad.join();
    }
    expect(offenders, isEmpty, reason: 'untaught characters in passages');
  });

  test('every dialogue only uses characters the app teaches', () {
    final taught = taughtCharacters();
    final offenders = <String, String>{};
    for (final d in dialogues) {
      final text = (d['lines'] as List<dynamic>)
          .map((l) => (l as Map<String, dynamic>)['hanzi'] as String)
          .join();
      final bad = untaught(text, taught);
      if (bad.isNotEmpty) offenders[d['id'] as String] = bad.join();
    }
    expect(offenders, isEmpty, reason: 'untaught characters in dialogues');
  });

  test('every example sentence only uses characters the app teaches', () {
    // The example sits on the word detail screen with a translation but
    // no gloss for anything else in it, so a character no deck covers is
    // one the learner meets with nothing to go on. Passages and dialogues
    // were already held to this; examples were the gap.
    final taught = taughtCharacters();
    final offenders = <String, String>{};
    for (final w in words) {
      final example = w['example_sentence'] as String?;
      if (example == null) continue;
      final bad = untaught(example, taught);
      if (bad.isNotEmpty) offenders[w['id'] as String] = bad.join();
    }
    expect(offenders, isEmpty, reason: 'untaught characters in examples');
  });

  test('every taught character has stroke-order data to write it', () {
    final missing = taughtCharacters().difference(strokeData.keys.toSet());
    expect(missing, isEmpty);
  });

  test('word and deck ids are unique', () {
    final wordIds = words.map((w) => w['id'] as String).toList();
    expect(wordIds.toSet().length, wordIds.length);
    final deckIds = decks.map((d) => d['id'] as String).toList();
    expect(deckIds.toSet().length, deckIds.length);
  });

  test('no two words teach the same characters', () {
    final hanzi = words.map((w) => w['hanzi'] as String).toList();
    expect(hanzi.toSet().length, hanzi.length);
  });

  test('each deck word_count matches how many words it actually has', () {
    for (final d in decks) {
      final actual = words.where((w) => w['deck_id'] == d['id']).length;
      expect(actual, d['word_count'], reason: 'deck ${d['id']}');
    }
  });

  test('every word belongs to a real deck and matches its level', () {
    final deckById = {for (final d in decks) d['id'] as String: d};
    for (final w in words) {
      final deck = deckById[w['deck_id']];
      expect(deck, isNotNull, reason: 'word ${w['id']} has no deck');
      expect(w['hsk_level'], deck!['hsk_level'], reason: 'word ${w['id']}');
      expect(w['topic'], deck['topic'], reason: 'word ${w['id']}');
    }
  });

  test("each word's example sentence actually contains that word", () {
    for (final w in words) {
      final ex = w['example_sentence'] as String?;
      if (ex == null || ex.isEmpty) continue;
      expect(
        ex.contains(w['hanzi'] as String),
        isTrue,
        reason: w['id'] as String,
      );
    }
  });

  test('every deck has both a reading passage and a dialogue', () {
    final readingTopics = passages.map((p) => p['topic']).toSet();
    final dialogueTopics = dialogues.map((d) => d['topic']).toSet();
    for (final d in decks) {
      expect(readingTopics, contains(d['topic']), reason: 'reading ${d['id']}');
      expect(
        dialogueTopics,
        contains(d['topic']),
        reason: 'dialogue ${d['id']}',
      );
    }
  });

  test('comprehension questions have a valid correct answer', () {
    for (final item in [...passages, ...dialogues]) {
      final options = (item['options'] as List<dynamic>);
      final idx = item['correct_index'] as int;
      expect(options.length, greaterThanOrEqualTo(2), reason: '${item['id']}');
      expect(
        idx,
        inInclusiveRange(0, options.length - 1),
        reason: '${item['id']}',
      );
      expect(
        options.toSet().length,
        options.length,
        reason: 'duplicate options in ${item['id']}',
      );
    }
  });
}
