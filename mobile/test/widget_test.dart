import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/main.dart';

void main() {
  setUpAll(() {
    // The app talks to a real (local) SQLite database — for `flutter test`
    // (pure Dart VM, no platform channels) point sqflite at the FFI
    // backend. The no-isolate variant is required here: the isolate-backed
    // one spawns a background isolate that keeps the test process alive
    // forever after the test body finishes.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  testWidgets('App shows bottom navigation with five tabs', (
    WidgetTester tester,
  ) async {
    late AppSettings settings;
    late AppRepositories repos;

    // testWidgets runs its body inside a fake-async zone that controls
    // time/microtask scheduling for widget pumping — real disk I/O (like
    // opening the SQLite file) hangs inside that zone. runAsync briefly
    // steps outside it to let the real database open complete.
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
        child: const AppChinese(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Уроки'), findsWidgets);
    expect(find.text('Повторить'), findsWidgets);
    expect(find.text('Практика'), findsWidgets);
    expect(find.text('Прогресс'), findsWidgets);
    expect(find.text('Чат'), findsWidgets);
  });
}
