import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/screens/mascot_wardrobe_screen.dart';
import 'package:app_chinese/services/mascot_service.dart';

/// The wardrobe's outfit grid.
///
/// Tapping an outfit did nothing on device — no crash, no change, the tick
/// stayed put. Reading the code doesn't explain it: every card is passed
/// `unlocked: true`, onTap is wired, `equipped_outfit` is written and read
/// back, and the level gate that used to revert a pick was already lifted.
/// This pins down whether the screen's own logic is at fault.
///
/// The screen also builds the 3D stage, which can't initialize without a
/// platform — Flutter substitutes an error widget for just that subtree
/// and keeps the rest, so the grid is still testable as long as the
/// resulting errors are drained rather than failing the test.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  /// Swallow anything raised by the 3D stage; a real failure in the grid
  /// still shows up as a failed expectation.
  void drain3DErrors(WidgetTester tester) {
    var caught = tester.takeException();
    while (caught != null) {
      caught = tester.takeException();
    }
  }

  Future<void> pumpWardrobe(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.library == 'thermion_flutter') return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

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
        child: const MaterialApp(home: MascotWardrobeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    drain3DErrors(tester);
  }

  Finder cardFor(int index) => find.byKey(ValueKey('outfit-$index'));

  /// The equipped card is the one showing the tick.
  Finder tickIn(int index) =>
      find.descendant(of: cardFor(index), matching: find.byIcon(Icons.check_circle));

  Future<void> tapOutfit(WidgetTester tester, int index) async {
    await tester.ensureVisible(cardFor(index));
    await tester.pump();
    await tester.tap(cardFor(index));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    drain3DErrors(tester);
  }

  testWidgets('every panda outfit renders a card', (tester) async {
    await pumpWardrobe(tester);
    for (final outfit in MascotService.pandaOutfits) {
      expect(cardFor(outfit.index), findsOneWidget,
          reason: 'outfit ${outfit.index} should have a card');
    }
    expect(find.byIcon(Icons.check_circle), findsOneWidget,
        reason: 'exactly one outfit reads as equipped');
  });

  testWidgets('tapping an outfit moves the equipped tick to it', (
    tester,
  ) async {
    await pumpWardrobe(tester);

    const target = 1; // the one reported as unusable on device
    expect(tickIn(target), findsNothing, reason: 'not equipped to begin with');

    await tapOutfit(tester, target);

    expect(tickIn(target), findsOneWidget,
        reason: 'tapping outfit $target should equip it');
    expect(find.byIcon(Icons.check_circle), findsOneWidget,
        reason: 'and nothing else should stay equipped');
  });

  testWidgets('the pick is written to the database, not just the UI', (
    tester,
  ) async {
    await pumpWardrobe(tester);
    const target = 3;
    await tapOutfit(tester, target);

    late int stored;
    await tester.runAsync(() async {
      final repos = await AppRepositories.initialize(
        overridePath: inMemoryDatabasePath,
      );
      stored = (await repos.stats.getStats()).equippedOutfit;
    });
    expect(stored, target, reason: 'the equip should have been persisted');
  });
}
