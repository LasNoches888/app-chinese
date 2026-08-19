import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/models/deck.dart';
import 'package:app_chinese/screens/lessons_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  group('DeckProgress.fraction', () {
    Deck deck(int wordCount) => Deck(
      id: 'd',
      title: 'D',
      topic: 't',
      hskLevel: 1,
      wordCount: wordCount,
    );

    test('is zero for an untouched deck', () {
      final dp = DeckProgress(deck: deck(10), completed: false, unlocked: true);
      expect(dp.fraction, 0);
    });

    test('reflects how many of the deck-s words are learned', () {
      final dp = DeckProgress(
        deck: deck(10),
        completed: false,
        unlocked: true,
        learnedWords: 4,
      );
      expect(dp.fraction, closeTo(0.4, 0.001));
    });

    test('never exceeds a full bar', () {
      final dp = DeckProgress(
        deck: deck(10),
        completed: true,
        unlocked: true,
        learnedWords: 12,
      );
      expect(dp.fraction, 1);
    });

    test('does not divide by zero on an empty deck', () {
      final dp = DeckProgress(
        deck: deck(0),
        completed: false,
        unlocked: true,
        learnedWords: 3,
      );
      expect(dp.fraction, 0);
    });
  });

  testWidgets('shows the today card, HSK headings and deck progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late AppSettings settings;
    late AppRepositories repos;
    await tester.runAsync(() async {
      settings = AppSettings();
      repos = await AppRepositories.initialize();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          Provider<AppRepositories>.value(value: repos),
        ],
        child: const MaterialApp(home: LessonsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Сегодня'), findsOneWidget);
    // The header's call to action points at the first unfinished deck, so
    // the learner never has to work out where they left off.
    expect(find.textContaining('Продолжить'), findsWidgets);
    // Decks are grouped under level headings rather than listed flat.
    expect(find.text('HSK 1'), findsOneWidget);
    expect(find.textContaining('слов выучено'), findsWidgets);
  });
}
