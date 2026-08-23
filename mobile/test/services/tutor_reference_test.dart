import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/models/word.dart';
import 'package:app_chinese/repositories/dictionary_repository.dart';
import 'package:app_chinese/services/pinyin_annotator.dart';
import 'package:app_chinese/services/tutor_reference.dart';

/// The reference is what replaces the model's memory. If it misses the
/// word the learner asked about, the model falls back on inventing an
/// answer — so these cover what has to end up in it, and the budget that
/// keeps it inside a 4096-token context.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database dict;
  late AppRepositories repos;
  late DictionaryRepository dictionary;
  late PinyinAnnotator annotator;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    repos = await AppRepositories.initialize(
      overridePath: inMemoryDatabasePath,
    );

    dict = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await dict.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY, simp TEXT, trad TEXT, pinyin TEXT,
        pinyin_plain TEXT, ru TEXT, en TEXT, freq INTEGER, weight INTEGER,
        is_ref INTEGER
      )
    ''');
    var nextId = 0;
    Future<void> add(
      String simp,
      String pinyin,
      String ru, {
      int freq = 500,
      String en = '',
    }) => dict.insert('entries', {
      'id': nextId++,
      'simp': simp,
      'trad': simp,
      'pinyin': pinyin,
      'pinyin_plain': pinyin.replaceAll(RegExp(r'[0-9\s]'), ''),
      'ru': ru,
      'en': en,
      'freq': freq,
      'weight': simp.length,
      'is_ref': 0,
    });

    await add('但是', 'dan4 shi4', 'но; однако; тем не менее; впрочем');
    await add('银行', 'yin2 hang2', 'банк');
    await add('我', 'wo3', 'я', freq: 700);
    await add('猫', 'mao1', 'кошка; кот');
    await add('狗', 'gou3', 'собака');
    await add('囧', 'jiong3', '', en: 'embarrassed');

    dictionary = DictionaryRepository(open: () async => dict);
    annotator = PinyinAnnotator(dictionary, repos.words);
  });

  setUp(PinyinAnnotator.resetCacheForTest);

  tearDownAll(() async => dict.close());

  Future<String> build(String message, {List<Word> weak = const []}) =>
      TutorReference.build(
        learnerMessage: message,
        weakWords: weak,
        dictionary: dictionary,
        annotator: annotator,
      );

  Word word(String hanzi, String pinyin, String ru) => Word(
    id: hanzi,
    hanzi: hanzi,
    pinyin: pinyin,
    translationRu: ru,
    hskLevel: 1,
    topic: 'test',
    deckId: 'test',
  );

  group('what the learner wrote', () {
    test('every word of a Chinese message is looked up', () async {
      final reference = await build('我不懂但是');
      expect(reference, contains('但是 — dàn shì'));
      expect(reference, contains('我 — wǒ — я'));
    });

    test('the reading comes from the word, not the character', () async {
      // 银行 is yínháng; the model guessing yínxíng is exactly what the
      // reference is here to prevent.
      expect(await build('银行在哪里'), contains('银行 — yín háng — банк'));
    });

    test('a long gloss list is trimmed', () async {
      // Common words carry a paragraph of meanings, and the whole point
      // of a budget is that it survives contact with them.
      final reference = await build('但是');
      expect(reference, contains('но; однако; тем не менее'));
      expect(reference, isNot(contains('впрочем')));
    });

    test('English stands in when there is no Russian', () async {
      expect(await build('囧'), contains('embarrassed'));
    });
  });

  group('what the learner asked in Russian', () {
    test('a Russian question finds the word it is about', () async {
      // The beginner case: no Chinese in the message at all, which is
      // when an empty reference would hurt most.
      expect(await build('как будет кошка'), contains('猫'));
    });

    test('filler words are not looked up', () async {
      // "как", "это", "сказать" would each cost a scan of 124k rows and
      // return noise.
      expect(await build('как это сказать'), isEmpty);
    });

    test('Russian is ignored once the message has Chinese in it', () async {
      // The characters are the specific question; the surrounding Russian
      // is just how it was asked.
      final reference = await build('что значит 但是 и кошка');
      expect(reference, contains('但是'));
      expect(reference, isNot(contains('猫')));
    });
  });

  group('revision words', () {
    test("weak words carry the course's own reading and translation", () async {
      final reference = await build(
        'привет',
        weak: [word('谢谢', 'xiè xie', 'спасибо')],
      );
      expect(reference, contains('谢谢 — xiè xie — спасибо'));
    });

    test('what the learner wrote outranks the revision list', () async {
      final reference = await build(
        '但是',
        weak: [for (var i = 0; i < 30; i++) word('狗', 'gǒu', 'собака')],
      );
      expect(reference, contains('但是'));
    });
  });

  group('budget', () {
    test('the reference never exceeds its entry cap', () async {
      final reference = await build(
        'привет',
        weak: [for (var i = 0; i < 40; i++) word('字$i', 'zì', 'знак $i')],
      );
      final entries = '\n'.allMatches(reference.trim()).length;
      expect(entries, lessThanOrEqualTo(TutorReference.maxEntries + 3));
    });

    test('nothing to say means no block at all', () async {
      // An empty heading would still spend tokens and still invite the
      // model to treat it as authoritative.
      expect(await build(''), isEmpty);
    });

    test(
      'the block tells the model what to do when a word is missing',
      () async {
        final reference = await build('但是');
        expect(reference, contains('не уверен'));
      },
    );
  });
}
