import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/repositories/stats_repository.dart';

/// setMascotCharacter/setEquippedOutfit used to read the whole row, change
/// one field, and write the whole row back -- see the doc comment on
/// setMascotCharacter for why that's a trap: any other in-flight write
/// started from an older snapshot and landing later would silently put the
/// mascot back to whatever it was. These pin down the fix (a targeted
/// UPDATE touching only the intended columns) by checking it doesn't
/// disturb unrelated fields either way round.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late StatsRepository stats;

  setUp(() async {
    final repos = await AppRepositories.initialize(
      overridePath: inMemoryDatabasePath,
    );
    stats = repos.stats;
    // inMemoryDatabasePath's connection isn't actually fresh per call --
    // sqflite's default singleInstance:true hands back the same open
    // in-memory database for every openDatabase() on that literal path
    // within this test process, so a previous test's writes are still
    // sitting in the row otherwise. Start every test from a known-clean
    // slate explicitly rather than depending on that isolation.
    await stats.resetAllProgress();
  });

  test('switching character does not disturb XP earned earlier', () async {
    await stats.addXpAndRecordActivity(30);
    await stats.setMascotCharacter('pug');

    final result = await stats.getStats();
    expect(result.mascotCharacter, 'pug');
    expect(result.totalXp, 30);
  });

  test('earning XP after a character switch does not revert it', () async {
    await stats.setMascotCharacter('owl');
    await stats.addXpAndRecordActivity(10);

    final result = await stats.getStats();
    expect(result.mascotCharacter, 'owl');
    expect(result.totalXp, 10);
  });

  test('picking a character resets the equipped outfit to auto (-1)', () async {
    await stats.setEquippedOutfit(3);
    await stats.setMascotCharacter('pug');

    final result = await stats.getStats();
    expect(result.equippedOutfit, -1);
  });

  test('equipping an outfit does not touch the character', () async {
    await stats.setMascotCharacter('owl');
    await stats.setEquippedOutfit(0);

    final result = await stats.getStats();
    expect(result.mascotCharacter, 'owl');
    expect(result.equippedOutfit, 0);
  });
}
