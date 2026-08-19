import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/screens/dictionary_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  Future<void> pumpDictionary(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late AppSettings settings;
    late AppRepositories repos;
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
        child: const MaterialApp(home: DictionaryScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('lists words and finds one by its hanzi', (tester) async {
    await pumpDictionary(tester);
    expect(find.byType(ListTile), findsWidgets);

    await tester.enterText(find.byType(TextField), '你好');
    await tester.pump();

    expect(find.text('привет'), findsOneWidget);
  });

  testWidgets('finds a word by its Russian translation', (tester) async {
    await pumpDictionary(tester);

    await tester.enterText(find.byType(TextField), 'спасибо');
    await tester.pump();

    expect(find.text('谢谢'), findsOneWidget);
  });

  testWidgets('matches toneless pinyin typed without spaces', (tester) async {
    await pumpDictionary(tester);

    // Stored pinyin is "nǐ hǎo" — nobody types tone marks on a phone
    // keyboard, so plain "nihao" has to match.
    await tester.enterText(find.byType(TextField), 'nihao');
    await tester.pump();

    expect(find.text('你好'), findsOneWidget);
  });

  testWidgets('shows an empty state when nothing matches', (tester) async {
    await pumpDictionary(tester);

    await tester.enterText(find.byType(TextField), 'zzzzzz');
    await tester.pump();

    expect(find.text('Ничего не нашлось'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });
}
