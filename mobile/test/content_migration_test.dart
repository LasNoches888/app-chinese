import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/db/app_database.dart';
import 'package:app_chinese/repositories/srs_repository.dart';
import 'package:app_chinese/repositories/word_repository.dart';
import 'package:app_chinese/services/srs_service.dart';

/// Seeding used to run only against an empty database, so an app update
/// that shipped new vocabulary would never reach anyone who already had
/// the app installed — they'd stay on whatever word list existed the day
/// they first launched it. These cover the upsert path that replaced it,
/// including the part that matters most: it must not wipe progress.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A private in-memory database, not the shared on-disk one every other
  // test file gets from AppDatabase.open(). These tests clear tables to
  // simulate older installs, and `flutter test` runs files concurrently —
  // against the shared database that wiped content out from under
  // unrelated tests mid-run (which only showed up on CI, where the
  // scheduling differs from a local run).
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    db = await AppDatabase.open(overridePath: inMemoryDatabasePath);
  });

  setUp(() async {
    await db.delete('words');
    await db.delete('decks');
    await db.delete('review_history');
  });

  test('seeds the full bundled vocabulary into an empty database', () async {
    final words = WordRepository(db);

    await words.seedIfNeeded();

    // Well past the 75-word starter set the app originally shipped with.
    expect(await words.countAllWords(), greaterThan(200));
    expect((await words.getDecks()).length, greaterThan(15));
  });

  test('a partially-seeded install picks up newly bundled words', () async {
    final words = WordRepository(db);

    // Simulate an older install: a handful of the words the app used to
    // ship, and nothing newer.
    await db.insert('decks', {
      'id': 'greetings',
      'title': 'Приветствия',
      'topic': 'greetings',
      'hsk_level': 1,
      'word_count': 2,
    });
    await db.insert('words', {
      'id': 'nihao',
      'hanzi': '你好',
      'pinyin': 'nǐ hǎo',
      'translation_ru': 'привет',
      'hsk_level': 1,
      'topic': 'greetings',
      'deck_id': 'greetings',
    });
    expect(await words.countAllWords(), 1);

    await words.seedIfNeeded();

    expect(await words.countAllWords(), greaterThan(200));
  });

  test('re-seeding leaves existing review history intact', () async {
    final words = WordRepository(db);
    final srs = SrsRepository(db);

    await words.seedIfNeeded();
    await srs.recordReview(
      wordId: 'nihao',
      wasCorrect: true,
      exerciseType: 'flip',
    );
    await srs.recordReview(
      wordId: 'nihao',
      wasCorrect: true,
      exerciseType: 'flip',
    );
    expect(
      SrsService.isLearned((await srs.getState('nihao')).repetitions),
      isTrue,
    );

    // Drop a deck row so the content check sees the install as stale and
    // runs the upsert again, the way an update shipping new words would.
    await db.delete('decks', where: 'id = ?', whereArgs: ['greetings']);
    await words.seedIfNeeded();

    expect(
      SrsService.isLearned((await srs.getState('nihao')).repetitions),
      isTrue,
    );
  });
}
