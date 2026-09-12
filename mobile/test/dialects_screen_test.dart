import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/data/dialects.dart';
import 'package:app_chinese/screens/dialects_map_screen.dart';

/// The dialects tab's core path: the legend lists every dialect, tapping
/// one opens its detail page, and "Изучить диалект" leads into a lesson
/// that's actually reachable — the same "leads with what it buys" shape
/// the study-plan screens already follow.
void main() {
  Future<void> pumpMap(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1000, 3000)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.setOnboarded();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: const MaterialApp(home: DialectsMapScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('legend lists every dialect', (tester) async {
    await pumpMap(tester);

    for (final d in kDialects) {
      expect(find.text(d.nameRu), findsOneWidget, reason: d.id);
    }
  });

  testWidgets(
    'a dialect leads into flashcards backed by its own example',
    (tester) async {
      await pumpMap(tester);

      await tester.tap(find.text('Мандарин'));
      await tester.pumpAndSettle();

      // Detail screen: description and first example are both real content.
      final mandarin = kDialects.firstWhere((d) => d.id == 'mandarin');
      expect(find.text(mandarin.descriptionRu), findsOneWidget);
      expect(find.text(mandarin.examples.first.hanzi), findsWidgets);

      await tester.tap(find.text('Изучить диалект'));
      await tester.pumpAndSettle();

      expect(find.text('Примеры и фразы'), findsOneWidget);
      await tester.tap(find.text('Примеры и фразы'));
      await tester.pumpAndSettle();

      // First flashcard shows the dialect's first example, not a stub.
      expect(find.text(mandarin.examples.first.hanzi), findsOneWidget);
      expect(find.text(mandarin.examples.first.ru), findsOneWidget);
    },
  );
}
