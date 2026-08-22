import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/repositories/dictionary_repository.dart';

/// The reference dictionary is 124k entries, so nearly every query matches
/// something. What decides whether it is usable is the ranking, and these
/// pin down the rules that make it work: usage frequency dominates, an
/// exact gloss beats a passing mention, cross-reference stubs never
/// outrank the entry holding the meaning, and Russian is matched by stem
/// because nobody types the dictionary form.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late DictionaryRepository repo;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY, simp TEXT, trad TEXT, pinyin TEXT,
        pinyin_plain TEXT, ru TEXT, en TEXT, freq INTEGER, weight INTEGER,
        is_ref INTEGER
      )
    ''');

    // A miniature of the real data, including the shapes that broke the
    // first version of the ranking: an obscure single-gloss character
    // competing with the common word, and a "see X" stub sharing a
    // headword with the entry that means something.
    Future<void> add(
      int id,
      String simp,
      String trad,
      String pinyin,
      String plain,
      String ru,
      String en,
      int freq, {
      int isRef = 0,
    }) => db.insert('entries', {
      'id': id,
      'simp': simp,
      'trad': trad,
      'pinyin': pinyin,
      'pinyin_plain': plain,
      'ru': ru,
      'en': en,
      'freq': freq,
      'weight': simp.length,
      'is_ref': isRef,
    });

    await add(1, '水', '水', 'shui3', 'shui', 'вода; воды', 'water', 530);
    await add(2, '涠', '涠', 'wei2', 'wei', 'вода', 'still water', 0);
    await add(3, '汤', '湯', 'tang1', 'tang', 'суп; кипящая вода', 'soup', 440);
    await add(4, '吃', '吃', 'chi1', 'chi', 'есть; питаться', 'to eat', 565);
    await add(
      5,
      '吃',
      '吃',
      'chi1',
      'chi',
      'вариант написания 吃[chi1]',
      'variant of 吃[chi1]',
      565,
      isRef: 1,
    );
    await add(6, '你好', '你好', 'ni3 hao3', 'nihao', 'привет', 'hello', 469);
    await add(7, '你', '你', 'ni3', 'ni', 'ты; вы', 'you (informal)', 640);
    // Same frequency as 山 on purpose: the tier has to be what separates
    // them, not a lucky gap in usage.
    await add(8, '燃', '燃', 'ran2', 'ran', 'гореть', 'to burn', 499);
    await add(9, '山', '山', 'shan1', 'shan', 'гора; холм', 'mountain', 499);

    repo = DictionaryRepository(open: () async => db);
  });

  tearDownAll(() async => db.close());

  Future<List<String>> hanziFor(String query) async =>
      (await repo.search(query)).map((e) => e.simplified).toList();

  group('ranking', () {
    test('the common word beats the obscure exact match', () async {
      // 涠's whole gloss is "вода" and 水's is not, but 水 is the word
      // anyone searching for water means.
      expect((await hanziFor('вода')).first, '水');
    });

    test('a passing mention ranks below a primary meaning', () async {
      final results = await hanziFor('вода');
      expect(results.indexOf('水'), lessThan(results.indexOf('汤')));
    });

    test('a cross-reference stub never outranks the real entry', () async {
      // Both are 吃 with the same frequency; only one says what it means.
      final entries = await repo.search('chi');
      expect(entries.first.russian, 'есть; питаться');
    });

    test(
      'an exact pinyin match beats a longer word starting with it',
      () async {
        expect((await hanziFor('ni')).first, '你');
      },
    );
  });

  group('Russian stemming', () {
    test('an inflected query still finds the word', () async {
      expect(await hanziFor('воду'), contains('水'));
    });

    test('a stem-only hit ranks below a whole-word hit', () async {
      // "гор" catches "гореть" as readily as "гора", so a stem match is
      // worth a tier less. Frequency can still overturn that — it is a
      // weighting, not a filter — which is why the two here are equally
      // common.
      final results = await hanziFor('гора');
      expect(results.indexOf('山'), lessThan(results.indexOf('燃')));
    });
  });

  group('query routing', () {
    test('hanzi matches headwords, not glosses', () async {
      expect(await hanziFor('你'), containsAllInOrder(['你', '你好']));
    });

    test('pinyin is matched with tones and separators stripped', () async {
      expect(await hanziFor('nǐ hǎo'), contains('你好'));
      expect(await hanziFor('ni3hao3'), contains('你好'));
    });

    test('a Latin query that is not pinyin falls back to English', () async {
      expect((await hanziFor('mountain')).first, '山');
    });

    test('an empty query returns nothing rather than everything', () async {
      expect(await repo.search('   '), isEmpty);
    });

    test('lookupExact prefers the entry that carries a meaning', () async {
      final entry = await repo.lookupExact('吃');
      expect(entry?.russian, 'есть; питаться');
    });

    test('lookupExact finds traditional forms too', () async {
      expect((await repo.lookupExact('湯'))?.simplified, '汤');
    });
  });
}
