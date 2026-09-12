import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/app_repositories.dart';
import 'package:app_chinese/data/study_plans.dart';
import 'package:app_chinese/screens/plans_screen.dart';

/// Plans split into two tracks — everyday topics vs. clearing a whole HSK
/// level — so this locks down that both sections actually render and that
/// each bundled plan lands under the section its `track` says it should.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  testWidgets('shows both track sections with their plans', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
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
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          Provider<AppRepositories>.value(value: repos),
        ],
        child: const MaterialApp(home: PlansScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('По темам'), findsOneWidget);
    expect(find.text('HSK-экзамен'), findsOneWidget);

    // One plan from each track, so the split isn't just an empty header.
    final topicPlan = kStudyPlans.firstWhere((p) => p.track == PlanTrack.topic);
    final hskPlan = kStudyPlans.firstWhere((p) => p.track == PlanTrack.hsk);
    expect(find.text(topicPlan.titleRu), findsWidgets);
    expect(find.text(hskPlan.titleRu), findsWidgets);
  });
}
