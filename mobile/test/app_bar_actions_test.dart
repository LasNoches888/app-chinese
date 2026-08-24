import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/components/app_bar_actions.dart';
import 'package:app_chinese/main.dart';

/// The chat and settings buttons are meant to be reachable from anywhere.
/// They used to be pasted into each app bar separately, which is how chat
/// ended up on one screen while the gear was on five — so this walks the
/// bottom navigation and checks every tab carries both.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  testWidgets('every main tab offers chat and settings', (tester) async {
    // Phone-width: HomeShell switches to a desktop NavigationRail past
    // 700 logical px, and this test is specifically about the bottom
    // NavigationBar's tabs.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    late AppSettings settings;
    late AppRepositories repos;

    // Real disk I/O has to happen outside the fake-async zone — see the
    // note in widget_test.dart.
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

    final tabCount = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .length;
    expect(tabCount, greaterThanOrEqualTo(5));

    for (var i = 0; i < tabCount; i++) {
      await tester.tap(find.byType(NavigationDestination).at(i));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byType(AppBarActions),
        findsOneWidget,
        reason: 'tab $i has no chat/settings actions',
      );
      expect(
        find.byIcon(Icons.chat_bubble_outline),
        findsOneWidget,
        reason: 'tab $i has no chat button',
      );
      expect(
        find.byIcon(Icons.settings),
        findsOneWidget,
        reason: 'tab $i has no settings button',
      );
    }
  });
}
