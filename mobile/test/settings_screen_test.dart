import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/screens/settings_screen.dart';
import 'package:app_chinese/services/local_llm_service.dart';

/// Regression coverage for the Settings screen rendering at all. It shipped
/// broken twice — opening it showed only the background with none of the
/// controls — because nothing exercised it outside a real device, so the
/// failure only ever surfaced as "settings don't open".
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() {
    // Stand in for "we already looked for cached weights and found none",
    // so the screen renders the download panel instead of kicking off a
    // real llamadart cache probe (which would leave a spinner on screen
    // that pumpAndSettle can never settle).
    LocalLlmService.status.value = LocalModelStatus.absent;
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    late AppSettings settings;
    late AppRepositories repos;

    // Tall viewport so the whole settings list is laid out at once —
    // ListView only builds what fits, and scrolling to each section just to
    // assert it exists would obscure what these tests are actually for.
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('renders every settings section, not just the background', (
    tester,
  ) async {
    await pumpSettings(tester);

    expect(find.text('Uchi'), findsOneWidget);
    expect(find.text('Внешний вид'), findsOneWidget);
    expect(find.text('Цели и напоминания'), findsOneWidget);
    expect(find.text('Источник ответов чата'), findsOneWidget);
    expect(find.text('Данные'), findsOneWidget);
  });

  testWidgets('renders the interactive controls', (tester) async {
    await pumpSettings(tester);

    // Language + theme pickers.
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    // Both chat-mode cards.
    expect(find.text('Профессор'), findsOneWidget);
    expect(find.text('Друг поблизости'), findsOneWidget);

    // Destructive actions at the bottom of the list.
    expect(find.text('Сбросить прогресс'), findsOneWidget);
  });

  testWidgets('switching to the local model swaps in its setup panel', (
    tester,
  ) async {
    await pumpSettings(tester);

    // Server mode is the default, so its URL field shows first.
    expect(find.text('Адрес сервера чата'), findsOneWidget);

    await tester.tap(find.text('Друг поблизости'));
    await tester.pumpAndSettle();

    expect(find.text('Адрес сервера чата'), findsNothing);
    expect(find.text('Токен HuggingFace (не обязательно)'), findsOneWidget);
  });
}
