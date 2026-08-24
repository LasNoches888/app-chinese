import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/components/update_section.dart';

/// The actual update check hits AppUpdateService.checkForUpdate() with no
/// seam from here, so tapping "Проверить обновления" is left untested —
/// that would be a real network call to GitHub from a widget test. That
/// logic is covered with a mocked HTTP client in
/// test/services/app_update_service_test.dart; this only covers what the
/// section shows before anyone taps anything.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    Future<String> Function()? versionLabel,
  }) async {
    final settings = AppSettings();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          home: Scaffold(body: UpdateSection(versionLabel: versionLabel)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the current version once it loads', (tester) async {
    await pump(tester, versionLabel: () async => '0.1.0 (42)');

    expect(find.textContaining('0.1.0 (42)'), findsOneWidget);
  });

  testWidgets('offers a check button before anything is checked', (
    tester,
  ) async {
    await pump(tester, versionLabel: () async => '0.1.0 (42)');

    expect(find.text('Проверить обновления'), findsOneWidget);
    expect(find.text('Скачать и установить'), findsNothing);
  });

  testWidgets(
    'a version lookup that fails just omits the line, rather than crashing',
    (tester) async {
      await pump(tester, versionLabel: () async => throw Exception('nope'));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Текущая версия'), findsNothing);
      // The rest of the section still works.
      expect(find.text('Проверить обновления'), findsOneWidget);
    },
  );
}
