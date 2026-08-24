import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/main.dart';
import 'package:app_chinese/screens/placement_test_screen.dart';

/// The app previously dropped every new install straight into the lesson
/// list with no explanation and no path to the placement test (which
/// existed but was three taps deep in Practice, undiscoverable). Covers
/// that a fresh profile actually sees onboarding, that finishing it is
/// remembered, and that "check my level" really opens the placement test
/// rather than just closing the welcome screen.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  Future<AppSettings> pumpApp(WidgetTester tester) async {
    // Phone-width: HomeShell swaps the bottom NavigationBar these tests
    // look for with a desktop NavigationRail past 700 logical px.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    late AppSettings settings;
    late AppRepositories repos;
    await tester.runAsync(() async {
      settings = AppSettings();
      await settings.load();
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
    await tester.pump(const Duration(milliseconds: 400));
    return settings;
  }

  testWidgets('a fresh profile sees onboarding, not the lesson list', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Uchi'), findsOneWidget);
    expect(find.text('Проверить свой уровень'), findsOneWidget);
    // The five-tab shell (and therefore the lesson list) must not be
    // reachable yet.
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('skipping records onboarded and reaches the lesson list', (
    tester,
  ) async {
    final settings = await pumpApp(tester);

    await tester.tap(find.text('Начать с нуля'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(settings.onboarded, isTrue);
  });

  testWidgets('"check my level" opens the placement test', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Проверить свой уровень'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(PlacementTestScreen), findsOneWidget);
  });
}
