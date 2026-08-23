import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/models/chat_message.dart';
import 'package:app_chinese/repositories/dictionary_repository.dart';
import 'package:app_chinese/services/tutor_fact_checker.dart';

/// The 1.5B tutor occasionally states something untrue about Chinese — in
/// testing it called 但是 "важная часть русского языка". These pin down
/// the line the checker draws: it removes claims the dictionary can
/// disprove, and leaves everything else, including legitimate comparisons
/// between the two languages.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late TutorFactChecker checker;

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
    var nextId = 0;
    Future<void> add(String simp, String pinyin) => db.insert('entries', {
      'id': nextId++,
      'simp': simp,
      'trad': simp,
      'pinyin': pinyin,
      'pinyin_plain': '',
      'ru': '',
      'en': '',
      'freq': 500,
      'weight': simp.length,
      'is_ref': 0,
    });
    await add('但是', 'dan4 shi4');
    await add('因为', 'yin1 wei4');
    await add('在', 'zai4');

    checker = TutorFactChecker(DictionaryRepository(open: () async => db));
  });

  tearDownAll(() async => db.close());

  ChatMessage reply(String text, {List<NewWord> words = const []}) =>
      ChatMessage(fromUser: false, text: text, newWords: words);

  group('language misattribution', () {
    test('a Chinese word handed to Russian is removed', () async {
      final result = await checker.check(
        reply('但是 — важная часть русского языка.'),
      );
      expect(result.wasEdited, isTrue);
      expect(result.message.text, isEmpty);
      expect(result.message.note, TutorFactChecker.replyUnreliable);
    });

    test('only the false sentence goes, the rest stays', () async {
      final result = await checker.check(
        reply('因为 значит «потому что». 但是 — это русское слово.'),
      );
      expect(result.message.text, '因为 значит «потому что».');
      expect(result.message.note, TutorFactChecker.partRemoved);
    });

    test('comparing the two languages is left alone', () async {
      // Naming Chinese is what separates a comparison from a confusion,
      // and comparisons are exactly what a tutor should be making.
      const sentence = 'В китайском 但是 — союз, как «но» в русском языке.';
      final result = await checker.check(reply(sentence));
      expect(result.wasEdited, isFalse);
      expect(result.message.text, sentence);
    });

    test('Russian prose with no Chinese in it is left alone', () async {
      const sentence = 'В русском языке нет тонов, и это упрощает дело.';
      expect((await checker.check(reply(sentence))).wasEdited, isFalse);
    });

    test('an ordinary Chinese reply passes untouched', () async {
      final message = reply('但是我不知道。');
      final result = await checker.check(message);
      expect(result.wasEdited, isFalse);
      expect(identical(result.message, message), isTrue);
    });
  });

  group('invented vocabulary', () {
    test('a word the dictionary has never heard of is dropped', () async {
      // Vocabulary is presented as things to go and memorise, so an
      // invented compound costs the learner real effort.
      final result = await checker.check(
        reply(
          '但是',
          words: [
            NewWord(word: '但是', pinyin: 'dàn shì', translation: 'но'),
            NewWord(word: '囧忐', pinyin: 'jiǒng tǎn', translation: 'выдумка'),
          ],
        ),
      );
      expect(result.message.newWords.single.word, '但是');
      expect(result.wasEdited, isTrue);
    });

    test('a vocabulary entry that is not Chinese at all is dropped', () async {
      final result = await checker.check(
        reply(
          '在',
          words: [NewWord(word: 'privet', pinyin: '', translation: 'привет')],
        ),
      );
      expect(result.message.newWords, isEmpty);
    });

    test('a gloss that misattributes the word is dropped', () async {
      final result = await checker.check(
        reply(
          '但是',
          words: [
            NewWord(
              word: '但是',
              pinyin: 'dàn shì',
              translation: 'слово из русского языка',
            ),
          ],
        ),
      );
      expect(result.message.newWords, isEmpty);
    });

    test('real vocabulary survives', () async {
      final words = [
        NewWord(word: '因为', pinyin: 'yīn wèi', translation: 'потому что'),
      ];
      final result = await checker.check(reply('因为', words: words));
      expect(result.wasEdited, isFalse);
      expect(result.message.newWords, hasLength(1));
    });
  });

  group('grammar recast', () {
    test('a recast that misattributes is dropped, not shown', () async {
      final result = await checker.check(
        ChatMessage(
          fromUser: false,
          text: '因为',
          grammarRecast: '但是 — это слово русского языка.',
        ),
      );
      expect(result.message.grammarRecast, isNull);
      expect(result.wasEdited, isTrue);
    });

    test('a normal recast is kept', () async {
      final result = await checker.check(
        ChatMessage(fromUser: false, text: '因为', grammarRecast: '因为我不知道。'),
      );
      expect(result.message.grammarRecast, '因为我不知道。');
      expect(result.wasEdited, isFalse);
    });
  });
}
