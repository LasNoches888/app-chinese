import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_chinese/components/mascot_companion.dart';
import 'package:app_chinese/services/mascot_service.dart';

void main() {
  Future<void> pumpCompanion(
    WidgetTester tester,
    MascotCompanionController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MascotCompanion(
          character: MascotCharacter.panda,
          controller: controller,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('react() shows the message bubble and hides it after 4s', (
    tester,
  ) async {
    final controller = MascotCompanionController();
    await pumpCompanion(tester, controller);

    expect(find.text('Hi!'), findsNothing);

    controller.react(MascotCue.hello, 'Hi!');
    await tester.pump();
    expect(find.text('Hi!'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Hi!'), findsNothing);
  });
}
