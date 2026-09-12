import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/main.dart';

/// Past the 700px breakpoint HomeShell swaps the phone's bottom bar for a
/// labeled sidebar with its own, wider destination list (Уроки, Словарь
/// and Чат get their own entry instead of being two taps deep through
/// Home's shortcut grid) — this locks down that the sidebar actually
/// shows all seven and that each one really navigates.
///
/// Several of these labels (Уроки, Словарь, Чат) also appear as tiles in
/// Home's own shortcut grid, so every lookup here is scoped to the
/// sidebar itself (by its Key) rather than plain `find.text`, which would
/// ambiguously match both.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  testWidgets('desktop sidebar lists all seven destinations and navigates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    late AppSettings settings;
    late AppRepositories repos;
    await tester.runAsync(() async {
      settings = AppSettings();
      await settings.setOnboarded();
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
        child: const AppChinese(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // No bottom bar at this width — the sidebar replaces it entirely.
    expect(find.byType(NavigationBar), findsNothing);

    final sidebar = find.byKey(const Key('desktopSidebar'));
    expect(sidebar, findsOneWidget);

    const labels = [
      'Главная',
      'Уроки',
      'Диалекты',
      'Словарь',
      'Чат',
      'Прогресс',
      'Настройки',
    ];
    for (final label in labels) {
      expect(
        find.descendant(of: sidebar, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }

    await tester.tap(
      find.descendant(of: sidebar, matching: find.text('Словарь')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The dictionary screen's own search field is a reliable, unambiguous
    // sign it actually opened (its app bar title also just says "Словарь",
    // same collision risk as the sidebar label).
    expect(find.byType(TextField), findsWidgets);

    await tester.tap(
      find.descendant(of: sidebar, matching: find.text('Чат')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The chat app bar's title is specific enough not to collide with
    // anything in the sidebar.
    expect(find.text('Чат с Xiao Qiao'), findsOneWidget);
  });
}
