import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/screens/settings_screen.dart';

/// Regression coverage for the Settings screen rendering at all. It shipped
/// broken twice — opening it showed only the background with none of the
/// controls — because nothing exercised it outside a real device, so the
/// failure only ever surfaced as "settings don't open". Chat-persona
/// picking moved out of Settings and into the chat screen itself (see
/// chat_screen_test.dart) — this file only covers what's still here:
/// appearance, speech, goals, and data.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    late AppSettings settings;
    late AppRepositories repos;

    tester.view.physicalSize = const Size(1080, 3400);
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
    expect(find.text('Обновления'), findsOneWidget);
    expect(find.text('Данные'), findsOneWidget);
  });

  testWidgets('the updates section is present and offers a check button', (
    tester,
  ) async {
    // The version line itself needs a real platform channel
    // (PackageInfo.fromPlatform() has no fallback under `flutter
    // test`) — that's covered with an injected loader in
    // update_section_test.dart instead. This only confirms the
    // section actually made it into the settings list.
    await pumpSettings(tester);

    expect(find.text('Проверить обновления'), findsOneWidget);
  });

  testWidgets('renders the interactive controls', (tester) async {
    await pumpSettings(tester);

    // Language + theme pickers.
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    // Destructive actions at the bottom of the list.
    expect(find.text('Сбросить прогресс'), findsOneWidget);
  });
}
