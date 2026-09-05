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
/// Every outfit card here needs a level high enough to actually unlock it
/// (StarBadge at 3, BubbleTea at 7, ...) -- the wardrobe used to show every
/// outfit as unlocked regardless of level while the new 2D art was being
/// tried out, which is exactly what let a pick silently revert once you
/// left: MascotService.effectiveOutfit (what the home screen and this
/// screen's own podium both call) has always enforced the real gate, so an
/// equip the wardrobe let through past it just got rejected the moment
/// anything re-read it. Now that the wardrobe enforces the same gate, a
/// fresh (XP: 0) profile could no longer equip most outfits at all -- so
/// the fixture below levels the profile up first, the same way a player
/// would have to.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  Future<void> pumpWardrobe(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
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
      // Comfortably past level 20 (Pilot, the highest-gated panda outfit)
      // so every card in the grid is actually tappable.
      await repos.stats.addXpAndRecordActivity(5000);
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
