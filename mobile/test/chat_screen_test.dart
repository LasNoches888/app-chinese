import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/screens/chat_screen.dart';
import 'package:app_chinese/services/local_llm_service.dart';

/// Covers the persona picker that replaced Settings' old chat-source
/// cards: Professor shows as a disabled "coming soon" row (and its own
/// friendly placeholder screen when selected), while Friend/Tutor are
/// real, tappable choices.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() {
    // Both ready by default so a tap on either row in the picker just
    // switches the mode instead of also kicking off a real network
    // download (LocalLlmService.ensureReady is only called for
    // unknown/absent status).
    LocalLlmService.status[LocalModelVariant.friend]!.value =
        LocalModelStatus.ready;
    LocalLlmService.status[LocalModelVariant.tutor]!.value =
        LocalModelStatus.ready;
  });

  Future<AppSettings> pumpChat(
    WidgetTester tester, {
    ChatMode chatMode = ChatMode.localTutor,
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
      await pumpChat(tester, chatMode: ChatMode.localTutor);

      expect(find.byType(TextField), findsOneWidget);
      // The "not ready" banner is driven by LocalLlmService.status, which
      // setUp preset to ready — it shouldn't render at all here.
      expect(find.textContaining('готов'), findsNothing);
    },
  );

  testWidgets('Professor shows a friendly coming-soon screen instead of chat', (
    tester,
  ) async {
    await pumpChat(tester, chatMode: ChatMode.server);

    expect(find.text('Профессор скоро откроет двери'), findsOneWidget);
    expect(find.text('Выбрать другого собеседника'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('tapping the badge opens the persona picker', (tester) async {
    await pumpChat(tester, chatMode: ChatMode.localTutor);

    await tester.tap(find.text('📖'));
    await tester.pumpAndSettle();

    expect(find.text('Выбрать собеседника'), findsOneWidget);
    expect(find.text('Профессор'), findsOneWidget);
    expect(find.text('Друг поблизости'), findsOneWidget);
    expect(find.text('Репетитор'), findsOneWidget);
  });

  testWidgets(
    'an undownloaded persona shows a tap-to-start hint in the picker',
    (tester) async {
      LocalLlmService.status[LocalModelVariant.friend]!.value =
          LocalModelStatus.unknown;
      await pumpChat(tester, chatMode: ChatMode.localTutor);

      await tester.tap(find.text('📖'));
      await tester.pumpAndSettle();

      expect(find.text('Нажмите, чтобы начать знакомство'), findsOneWidget);
    },
  );

  testWidgets('picking Friend switches the chat mode and closes the sheet', (
    tester,
  ) async {
    final settings = await pumpChat(tester, chatMode: ChatMode.localTutor);

    await tester.tap(find.text('📖'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Друг поблизости'));
    await tester.pumpAndSettle();

    expect(settings.chatMode, ChatMode.localFriend);
    expect(find.text('Выбрать собеседника'), findsNothing);
  });
}
