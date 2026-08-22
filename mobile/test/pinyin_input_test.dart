import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_chinese/api/app_settings.dart';
import 'package:app_chinese/components/exercise_widgets.dart';
import 'package:app_chinese/models/exercise_question.dart';

/// The pinyin answer used to be compared with spaces preserved, so the
/// stored "nǐ hǎo" only matched a typed "ni hao" — typing the word as one
/// run, which is what people actually do, was marked wrong. Stored pinyin
/// isn't even consistently spaced ("nǐ hǎo" but "kuàilè"), so the spacing
/// was never something the learner could reliably guess.
void main() {
  Future<void> pumpInput(
    WidgetTester tester, {
    required String correctPinyin,
    required void Function(bool) onAnswer,
  }) async {
    final settings = AppSettings();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TypePinyinExerciseWidget(
            question: ExerciseQuestion(
              id: 'q1',
              wordId: 'w1',
              type: ExerciseType.typePinyin,
              hanzi: '你好',
              correctPinyin: correctPinyin,
            ),
            settings: settings,
            onAnswer: onAnswer,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<bool?> answerWith(
    WidgetTester tester,
    String typed, {
    String correct = 'nǐ hǎo',
  }) async {
    bool? result;
    await pumpInput(
      tester,
      correctPinyin: correct,
      onAnswer: (ok) => result = ok,
    );
    await tester.enterText(find.byType(TextField), typed);
    await tester.tap(find.text('Проверить'));
    await tester.pump();
    // The widget waits a beat before reporting, so the learner sees the
    // right answer before the screen moves on.
    await tester.pump(const Duration(seconds: 2));
    return result;
  }

  testWidgets('pinyin typed without a space is accepted', (tester) async {
    expect(await answerWith(tester, 'nihao'), isTrue);
  });

  testWidgets('pinyin typed with a space is still accepted', (tester) async {
    expect(await answerWith(tester, 'ni hao'), isTrue);
  });

  testWidgets('tone numbers are accepted', (tester) async {
    expect(await answerWith(tester, 'ni3hao3'), isTrue);
  });

  testWidgets('tone marks are accepted', (tester) async {
    expect(await answerWith(tester, 'nǐhǎo'), isTrue);
  });

  testWidgets('an unspaced stored pinyin also matches a spaced answer', (
    tester,
  ) async {
    expect(await answerWith(tester, 'kuai le', correct: 'kuàilè'), isTrue);
  });

  testWidgets('a genuinely wrong answer is still wrong', (tester) async {
    expect(await answerWith(tester, 'zaijian'), isFalse);
  });
}
