import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/data/study_plans.dart';
import 'package:app_chinese/screens/plan_detail_screen.dart';

/// A plan page that opens on a checklist reads like homework. It is meant
/// to lead with what the plan buys and prove it with real sentences, so
/// these check that all three parts actually reach the screen.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  tearDown(() {
    // The tall surface below is per-test state on the shared view.
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> openPlan(WidgetTester tester, String planId) async {
    // A phone-sized viewport builds only the top of the list, and these
    // assertions are about the page as a whole — so give it room rather
    // than scrolling to each element in turn.
    tester.view
      ..physicalSize = const Size(1000, 3200)
      ..devicePixelRatio = 1.0;
    SharedPreferences.setMockInitialValues({});
    late AppSettings settings;
    late AppRepositories repos;
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
        child: MaterialApp(home: PlanDetailScreen(planId: planId)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a plan leads with what it buys, not with its steps', (
    tester,
  ) async {
    final plan = kStudyPlans.first;
    await openPlan(tester, plan.id);

    expect(find.text(plan.outcomesRu.first), findsOneWidget);
    expect(find.text(plan.samples.first.hanzi), findsOneWidget);
    expect(find.text(plan.samples.first.ru), findsOneWidget);

    // Outcomes sit above the steps, which is the whole point of the
    // ordering.
    final outcomeY = tester.getCenter(find.text(plan.outcomesRu.first)).dy;
    final stepY = tester.getCenter(find.text(plan.steps.first.titleRu)).dy;
    expect(outcomeY, lessThan(stepY));
  });

  testWidgets('each unfinished step explains what it covers', (tester) async {
    final plan = kStudyPlans.first;
    await openPlan(tester, plan.id);

    // Nothing is done on a fresh profile, so every step shows its detail.
    expect(find.text(plan.steps.first.detailRu), findsOneWidget);
  });

  testWidgets('the pace estimate is shown before starting', (tester) async {
    final plan = kStudyPlans.first;
    await openPlan(tester, plan.id);

    expect(find.text(plan.paceRu), findsOneWidget);
  });
}
