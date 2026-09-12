import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/screens/home_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  testWidgets('shows the today card and shortcut grid', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late AppSettings settings;
    late AppRepositories repos;
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
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Сегодня'), findsOneWidget);
    // The card's call to action points at the first unfinished deck, so
    // the learner never has to work out where they left off.
    expect(find.textContaining('Продолжить'), findsWidgets);
    // The shortcut grid replaces what used to be five separate bottom-nav
    // tabs for everything that isn't Home/Plans/Progress/Settings.
    expect(find.text('Уроки'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.text('Практика'), findsOneWidget);
    expect(find.text('Словарь'), findsOneWidget);
    expect(find.text('Чат'), findsOneWidget);
    expect(find.text('Гардероб'), findsOneWidget);
  });
}
