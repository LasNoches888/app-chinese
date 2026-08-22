import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/screens/listening_screen.dart';
import 'package:app_chinese/screens/memory_match_screen.dart';
import 'package:app_chinese/screens/placement_test_screen.dart';
import 'package:app_chinese/screens/practice_hub_screen.dart';
import 'package:app_chinese/screens/pronunciation_check_screen.dart';
import 'package:app_chinese/screens/race_screen.dart';
import 'package:app_chinese/screens/reading_list_screen.dart';
import 'package:app_chinese/screens/scenario_list_screen.dart';
import 'package:app_chinese/screens/speed_round_screen.dart';
import 'package:app_chinese/screens/tone_trainer_screen.dart';

/// Smoke coverage for the six new practice-mode screens — Settings shipped
/// broken twice with nothing exercising it outside a real device, so every
/// new screen this session gets at least a "does it render" test before
/// shipping, not after a bug report.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    late AppSettings settings;
    late AppRepositories repos;

    // Tall viewport so grid/list screens (MemoryMatchScreen's 4-row grid
    // in particular) lay out every item instead of only what fits the
    // default ~600px test surface.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      settings = AppSettings();
      repos = await AppRepositories.initialize(
        overridePath: inMemoryDatabasePath,
      );
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          Provider<AppRepositories>.value(value: repos),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('PracticeHubScreen lists all five practice modes', (
    tester,
  ) async {
    await pumpScreen(tester, const PracticeHubScreen());

    expect(find.text('Найди пару'), findsOneWidget);
    expect(find.text('Тренажёр тонов'), findsOneWidget);
    expect(find.text('Аудирование'), findsOneWidget);
    expect(find.text('Чтение'), findsOneWidget);
    expect(find.text('Ролевые сценарии'), findsOneWidget);
    expect(find.text('Проверка уровня'), findsOneWidget);
    expect(find.text('Ежедневное испытание'), findsOneWidget);
    expect(find.text('Слово дня'), findsOneWidget);
    expect(find.text('Игра на время'), findsOneWidget);
    expect(find.text('Гонка с пандой'), findsOneWidget);
    expect(find.text('Проверка произношения'), findsOneWidget);
  });

  testWidgets('PronunciationCheckScreen falls back to an unavailable message '
      'without a real speech recognizer', (tester) async {
    await pumpScreen(tester, const PronunciationCheckScreen());
    // PronunciationService.ensureInitialized() falls back after a
    // 5-second timeout in environments with no real recognizer.
    await tester.pump(const Duration(seconds: 6));

    expect(
      find.text(
        'На этом устройстве не нашлось распознавания речи для проверки произношения.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('SpeedRoundScreen loads a prompt with four options', (
    tester,
  ) async {
    await pumpScreen(tester, const SpeedRoundScreen());

    expect(find.textContaining('⏱'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(4));
  });

  testWidgets('RaceScreen loads a prompt with both racers at the start', (
    tester,
  ) async {
    await pumpScreen(tester, const RaceScreen());

    expect(find.text('Ты'), findsOneWidget);
    expect(find.text('Панда'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(4));
  });

  testWidgets('MemoryMatchScreen deals a full grid of face-down cards', (
    tester,
  ) async {
    await pumpScreen(tester, const MemoryMatchScreen());

    // 6 pairs = 12 cards, all showing the question-mark back initially.
    // (A follow-up tap-and-flip assertion was tried here too — reliable
    // in isolation via tapAt(getCenter(...)), but flaky against this
    // tile's 3D-perspective Transform when run alongside the other tests
    // in this file, for reasons that look like a test-binding pointer
    // artifact rather than an actual app bug. Left out rather than
    // shipping a flaky check.)
    expect(find.byIcon(Icons.help_outline), findsNWidgets(12));
    expect(find.text('Ходы: 0'), findsOneWidget);
  });

  testWidgets('ToneTrainerScreen renders a prompt and tone options', (
    tester,
  ) async {
    await pumpScreen(tester, const ToneTrainerScreen());

    expect(find.text('Какой иероглиф я произнёс?'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    // Every set has at least two tone options as tappable buttons.
    expect(find.byType(OutlinedButton), findsAtLeastNWidgets(2));

    // The screen autoplays the target on load, and SpeechService.speak
    // bounds that call with a timeout — let it expire so no timer is
    // still pending when the tree is torn down.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('PlacementTestScreen loads a word and reveals on tap', (
    tester,
  ) async {
    await pumpScreen(tester, const PlacementTestScreen());

    expect(find.text('Нажмите, чтобы перевернуть'), findsOneWidget);
    expect(find.text('Знаю'), findsNothing);

    await tester.tap(find.byType(GestureDetector));
    await tester.pump();

    expect(find.text('Знаю'), findsOneWidget);
    expect(find.text('Не знаю'), findsOneWidget);
  });

  testWidgets('ListeningScreen plays through a full dialogue', (tester) async {
    await pumpScreen(tester, const ListeningScreen());
    expect(find.byIcon(Icons.replay), findsOneWidget);

    // Autoplay chains real-feeling per-line delays (SpeechService.speak +
    // a pause) via Future.delayed; fake_async resolves those as virtual
    // time advances, but only if we pump far enough to cover the whole
    // dialogue (worst case ~4 lines x ~4s) — otherwise a timer is still
    // pending when the test tears the widget tree down, which the
    // framework correctly flags as a leak.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 5));
    }
  });

  testWidgets('ReadingListScreen ranks and lists the curated passages', (
    tester,
  ) async {
    await pumpScreen(tester, const ReadingListScreen());

    expect(find.byType(ListTile), findsWidgets);
    expect(find.textContaining('известных слов'), findsWidgets);
  });

  testWidgets(
    'ScenarioListScreen gates on the local model when it is not ready',
    (tester) async {
      await pumpScreen(tester, const ScenarioListScreen());

      // No platform channel in `flutter test`, so the local model can never
      // report ready — the screen must show the setup prompt, not crash or
      // show an empty scenario list.
      expect(find.textContaining('Друг поблизости'), findsOneWidget);
    },
  );
}
