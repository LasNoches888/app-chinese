import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_chinese/components/hearts_row.dart';

/// A single pug portrait now stands in for the row of heart icons — the
/// asset changes with the count instead of icons filling/emptying. These
/// pin down the asset selection and the range it's clamped to, since the
/// art only exists for 0–5.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

  testWidgets('shows the pug matching the current heart count', (tester) async {
    await pump(tester, const HeartsRow(hearts: 3));

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/mascot/hearts/pug_3.png',
    );
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('zero hearts uses the dedicated empty asset, not a clamp', (
    tester,
  ) async {
    await pump(tester, const HeartsRow(hearts: 0));

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/mascot/hearts/pug_0.png',
    );
  });

  testWidgets('a count above the drawn range clamps to 5', (tester) async {
    // HeartsService caps at 5 in practice, but the widget shouldn't
    // reach for art that was never drawn if that ever slips.
    await pump(tester, const HeartsRow(hearts: 7));

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/mascot/hearts/pug_5.png',
    );
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('the large treatment shows the portrait with no count label', (
    tester,
  ) async {
    await pump(tester, const HeartsRow(hearts: 0, large: true));

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/mascot/hearts/pug_0.png',
    );
    expect(find.text('0'), findsNothing);
  });
}
