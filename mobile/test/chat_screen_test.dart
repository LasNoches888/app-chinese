import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/screens/chat_screen.dart';
import 'package:app_chinese/services/local_llm_service.dart';

/// Covers the persona picker: Friend is the one real, tappable choice
/// right now. Professor is pulled from the picker entirely — not shown
/// even as disabled — while Tutor still shows as a disabled "coming
/// soon" row, mid-move to running server-side. Opening chat with a saved
/// setting that points at either lands on the same friendly placeholder
/// instead of a chat, for anyone whose setting predates that change.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() {
    // Ready by default so a tap on Friend's row just switches the mode
    // instead of also kicking off a real network download
    // (LocalLlmService.ensureReady is only called for unknown/absent
    // status).
    LocalLlmService.status[LocalModelVariant.friend]!.value =
        LocalModelStatus.ready;
  });

  Future<AppSettings> pumpChat(
    WidgetTester tester, {
    ChatMode chatMode = ChatMode.localFriend,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late AppSettings settings;
    late AppRepositories repos;
    await tester.runAsync(() async {
      settings = AppSettings();
      await settings.load();
      await settings.setChatMode(chatMode);
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
        child: const MaterialApp(home: ChatScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return settings;
  }

  testWidgets(
    'a ready local persona shows the chat input with no blocked banner',
    (tester) async {
      await pumpChat(tester, chatMode: ChatMode.localFriend);

      expect(find.byType(TextField), findsOneWidget);
      // The "not ready" banner is driven by LocalLlmService.status, which
      // setUp preset to ready — it shouldn't render at all here.
      expect(find.textContaining('готов'), findsNothing);
    },
  );

  testWidgets(
    'a saved Professor setting still lands on the coming-soon screen',
    (tester) async {
      // Professor isn't reachable from the picker anymore, but a value
      // persisted before it was pulled must not crash or show an empty
      // chat.
      await pumpChat(tester, chatMode: ChatMode.server);

      expect(find.text('Профессор скоро откроет двери'), findsOneWidget);
      expect(find.text('Выбрать другого собеседника'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('Tutor shows a friendly coming-soon screen instead of chat', (
    tester,
  ) async {
    // Tutor is paused while it moves to run server-side — a saved
    // setting from before that (or the pre-migration 'local' value) must
    // land here rather than trying to load or download its weights.
    await pumpChat(tester, chatMode: ChatMode.localTutor);

    expect(find.text('Репетитор скоро будет здесь'), findsOneWidget);
    expect(find.text('Выбрать другого собеседника'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('tapping the badge opens the persona picker', (tester) async {
    await pumpChat(tester, chatMode: ChatMode.localFriend);

    await tester.tap(find.text('👋'));
    await tester.pumpAndSettle();

    expect(find.text('Выбрать собеседника'), findsOneWidget);
    expect(find.text('Профессор'), findsNothing);
    expect(find.text('Друг поблизости'), findsOneWidget);
    expect(find.text('Репетитор'), findsOneWidget);
  });

  testWidgets('Tutor shows as coming soon in the picker; Professor is absent', (
    tester,
  ) async {
    await pumpChat(tester, chatMode: ChatMode.localFriend);

    await tester.tap(find.text('👋'));
    await tester.pumpAndSettle();

    expect(find.text('Скоро'), findsOneWidget);
  });

  testWidgets(
    'an undownloaded persona shows a tap-to-start hint in the picker',
    (tester) async {
      LocalLlmService.status[LocalModelVariant.friend]!.value =
          LocalModelStatus.unknown;
      // Opened from a coming-soon mode (a stale Professor setting) rather
      // than Friend itself: entering chat on Friend would trigger
      // loadFromCacheIfPresent and flip its status before the picker
      // even opens, which is exactly the noise this test avoids by
      // reading the status untouched.
      await pumpChat(tester, chatMode: ChatMode.server);

      await tester.tap(find.text('Выбрать другого собеседника'));
      await tester.pumpAndSettle();

      expect(find.text('Нажмите, чтобы начать знакомство'), findsOneWidget);
    },
  );

  testWidgets('picking Friend from the coming-soon screen switches modes', (
    tester,
  ) async {
    final settings = await pumpChat(tester, chatMode: ChatMode.server);

    await tester.tap(find.text('Выбрать другого собеседника'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Друг поблизости'));
    await tester.pumpAndSettle();

    expect(settings.chatMode, ChatMode.localFriend);
    expect(find.text('Выбрать собеседника'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });
}
