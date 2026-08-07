import 'package:flutter_test/flutter_test.dart';

import 'package:app_chinese/main.dart';

void main() {
  testWidgets('App shows bottom navigation with three tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const AppChinese());
    await tester.pump();

    expect(find.text('Flashcards'), findsWidgets);
    expect(find.text('Chat'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
