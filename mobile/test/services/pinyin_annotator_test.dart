import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/models/chat_message.dart';
import 'package:app_chinese/repositories/dictionary_repository.dart';
import 'package:app_chinese/services/pinyin_annotator.dart';

/// The tutor model writes characters well and transcribes them by guess,
/// so the app transcribes them itself. These cover the cases that make
/// that worth doing: readings that only the surrounding word settles, and
/// the difference between a hand-checked reading and a dictionary one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database dict;
  late AppRepositories repos;
  late PinyinAnnotator annotator;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    repos = await AppRepositories.initialize(
      overridePath: inMemoryDatabasePath,
    );

    // A slice of the shipped dictionary, carrying the shapes that matter:
    // polyphones (长, 行), a word whose reading differs from its parts,
    // and a particle CC-CEDICT lists twice.
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
      String pinyin, {
      int freq = 400,
      int isRef = 0,
      String? trad,
    }) => dict.insert('entries', {
      'id': nextId++,
      'simp': simp,
      'trad': trad ?? simp,
      'pinyin': pinyin,
      'pinyin_plain': '',
      'ru': '',
      'en': '',
      'freq': freq,
      'weight': simp.length,
      'is_ref': isRef,
    });

    await add('我', 'wo3', freq: 700);
    await add('喜欢', 'xi3 huan5');
    await add('这', 'zhe4', freq: 600);
    await add('首', 'shou3');
    await add('歌', 'ge1');
    await add('他', 'ta1', freq: 650);
    await add('长', 'chang2', freq: 500);
    await add('长大', 'zhang3 da4');
    await add('大', 'da4', freq: 600);
    await add('了', 'le5', freq: 700);
    await add('很', 'hen3', freq: 600);
    await add('银行', 'yin2 hang2', trad: '銀行');
    await add('行', 'xing2', freq: 550);
    await add('银', 'yin2');
    await add('哪儿', 'na3 r5');
    await add('吧', 'ba1');
    await add('吧', 'ba5');
    await add('回家', 'hui2 jia1');
    // Only listed as a cross-reference, so it must lose to the real one.
    await add('歌', 'ge1', isRef: 1);

    annotator = PinyinAnnotator(
      DictionaryRepository(open: () async => dict),
      repos.words,
    );
  });

  setUp(PinyinAnnotator.resetCacheForTest);

  tearDownAll(() async => dict.close());

  group('segmentation decides the reading', () {
    test('a two-character word overrides its characters', () async {
      // 长 alone is cháng; inside 长大 it is zhǎng. Character-by-character
      // transcription gets this wrong, which is the whole reason the
      // segmenter exists.
      expect(await annotator.transcribe('他长大了'), 'tā zhǎng dà le');
    });

    test('the same character reads differently on its own', () async {
      expect(await annotator.transcribe('很长'), 'hěn cháng');
    });

    test('银行 is a bank, not a silver row', () async {
      expect(await annotator.transcribe('银行'), 'yín háng');
    });
  });

  group('output shape', () {
    test('Chinese punctuation becomes readable Latin punctuation', () async {
      // Syllables stay spaced rather than joined into words, matching how
      // pinyin is written everywhere else in the app.
      expect(await annotator.transcribe('我喜欢这首歌。'), 'wǒ xǐ huan zhè shǒu gē.');
    });

    test('a comma keeps a space after it, not before', () async {
      expect(
        await annotator.transcribe('他长大了，很长'),
        'tā zhǎng dà le, hěn cháng',
      );
    });

    test('erhua is one syllable', () async {
      expect(await annotator.transcribe('哪儿'), 'nǎr');
    });

    test('non-Chinese text is left alone', () async {
      expect(await annotator.transcribe('Привет!'), 'Привет!');
    });

    test('an unknown character is passed through, not guessed', () async {
      // Better an obviously untranscribed character than a plausible
      // wrong syllable the learner would trust.
      expect(await annotator.transcribe('我囧'), 'wǒ 囧');
    });
  });

  group('sources of truth', () {
    test("the course's hand-checked reading beats the dictionary", () async {
      // CC-CEDICT lists 吧 as both bā and the neutral ba; the course says
      // which one ends a sentence.
      expect(await annotator.transcribe('回家吧'), 'huí jiā ba');
    });

    test('a cross-reference entry never supplies the reading', () async {
      expect(await annotator.transcribe('歌'), 'gē');
    });
  });

  group('correcting a reply', () {
    test('the model pinyin is replaced, the characters are kept', () async {
      final corrected = await annotator.correct(
        ChatMessage(
          fromUser: false,
          text: '他长大了',
          pinyin: 'ta1 chang2 da4 le',
          newWords: [
            NewWord(word: '银行', pinyin: 'yin2 xing2', translation: 'банк'),
          ],
        ),
      );

      expect(corrected.text, '他长大了');
      expect(corrected.pinyin, 'tā zhǎng dà le');
      expect(corrected.newWords.single.pinyin, 'yín háng');
      expect(corrected.newWords.single.translation, 'банк');
    });

    test('a reply with no Chinese is returned untouched', () async {
      final message = ChatMessage(fromUser: false, text: 'Молодец!');
      expect(identical(await annotator.correct(message), message), isTrue);
    });
  });
}
