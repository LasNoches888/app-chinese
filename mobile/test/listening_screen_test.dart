import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/screens/listening_list_screen.dart';
import 'package:app_chinese/screens/listening_screen.dart';

/// The listening exercise used to reveal each line — hanzi, pinyin and the
/// Russian translation — as it played, so every comprehension question
/// could be answered by reading rather than listening. These lock in that
/// the transcript stays hidden until the learner commits to an answer.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    late AppSettings settings;
    late AppRepositories repos;

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

  /// Playback chains a real-feeling delay per line via Future.delayed;
  /// fake_async resolves those as virtual time advances, but only if we
  /// pump far enough to cover the whole dialogue — otherwise a timer is
  /// still pending at teardown and the framework flags it as a leak.
  Future<void> letPlaybackFinish(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 5));
    }
  }

  testWidgets('the transcript is hidden until the learner answers', (
    tester,
  ) async {
    await pumpScreen(tester, const ListeningScreen());
    await letPlaybackFinish(tester);

    expect(
      find.text('Текст скрыт — сначала попробуй понять на слух'),
      findsOneWidget,
    );

    // Answering reveals it, so a wrong guess still becomes a chance to
    // see what was actually said.
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Текст скрыт — сначала попробуй понять на слух'),
      findsNothing,
    );
  });

  testWidgets('peeking is available but separate from answering', (
    tester,
  ) async {
    await pumpScreen(tester, const ListeningScreen());
    await letPlaybackFinish(tester);

    await tester.tap(find.text('Показать текст'));
    await tester.pump();

    expect(
      find.text('Текст скрыт — сначала попробуй понять на слух'),
      findsNothing,
    );
    // Still unanswered, so the "next dialogue" button hasn't appeared.
    expect(find.text('Следующий диалог'), findsNothing);
  });

  testWidgets('the picker offers a random option plus real dialogues', (
    tester,
  ) async {
    await pumpScreen(tester, const ListeningListScreen());

    expect(find.text('Случайный диалог'), findsOneWidget);
    expect(find.byType(ListTile), findsWidgets);
  });
}
