import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/main.dart';

void main() {
  testWidgets('App shows bottom navigation with three tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: AppSettings(),
        child: const AppChinese(),
      ),
    );
    await tester.pump();

    expect(find.text('Карточки'), findsWidgets);
    expect(find.text('Чат'), findsWidgets);
    expect(find.text('Настройки'), findsWidgets);
  });
}
