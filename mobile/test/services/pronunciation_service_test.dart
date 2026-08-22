import 'package:flutter_test/flutter_test.dart';

import 'package:app_chinese/services/pronunciation_service.dart';

/// The grading is the whole value of the pronunciation check — a bare
/// "contains the word" boolean couldn't tell the learner *what* to fix,
/// and couldn't tell a perfectly-pronounced homophone apart from a real
/// mistake.
void main() {
  // A tiny stand-in for the app's word bank: the grader needs a reading
  // for whatever the recognizer returns before it can say anything more
  // useful than "different characters".
  const bank = {
    '妈': 'mā',
    '马': 'mǎ',
    '麻': 'má',
    '骂': 'mà',
    '他': 'tā',
    '她': 'tā',
    '你好': 'nǐ hǎo',
    '再见': 'zài jiàn',
  };

  PronunciationResult gradeOne(
    String heard,
    String target, {
    String? targetPinyin,
    List<String>? alternates,
  }) => PronunciationService.grade(
    alternates: alternates ?? [heard],
    targetHanzi: target,
    targetPinyin: targetPinyin ?? bank[target] ?? '',
    pinyinByHanzi: bank,
  );

  group('PronunciationService.grade', () {
    test('an exact match is correct', () {
      final r = gradeOne('你好', '你好');
      expect(r.grade, PronunciationGrade.correct);
      expect(r.isPass, isTrue);
      expect(r.mistakes, isEmpty);
    });

    test('punctuation the recognizer adds does not break an exact match', () {
      expect(gradeOne('你好。', '你好').grade, PronunciationGrade.correct);
    });

    test('a homophone counts as correctly pronounced', () {
      // 他/她 are both "tā" — the learner's mouth did the right thing and
      // the recognizer just picked the other spelling.
      final r = gradeOne('她', '他');
      expect(r.grade, PronunciationGrade.homophone);
      expect(r.isPass, isTrue);
    });

    test('same syllable with a different tone is diagnosed as a tone miss', () {
      final r = gradeOne('马', '妈');
      expect(r.grade, PronunciationGrade.toneMiss);
      expect(r.isPass, isFalse);
      // The pinyin of what was heard is what makes the hint actionable.
      expect(r.heardPinyin, 'mǎ');
      expect(r.mistakes.single.expected, '妈');
      expect(r.mistakes.single.heard, '马');
    });

    test('a genuinely different word is not reported as a tone miss', () {
      final r = gradeOne('再见', '你好');
      expect(r.grade, PronunciationGrade.wrongWord);
    });

    test('the target buried in a longer phrase counts as close', () {
      final r = gradeOne('那个你好吗', '你好');
      expect(r.grade, PronunciationGrade.closeExtraWords);
      expect(r.isPass, isFalse);
    });

    test('a correct alternate outranks a wrong headline guess', () {
      // Recognizers routinely put the right word second; grading only the
      // top guess threw those attempts away.
      final r = gradeOne('', '你好', alternates: ['再见', '你好']);
      expect(r.grade, PronunciationGrade.correct);
    });

    test('the best of several imperfect alternates wins', () {
      final r = gradeOne('', '妈', alternates: ['再见', '马']);
      expect(r.grade, PronunciationGrade.toneMiss);
    });

    test('silence is reported as not heard, not as a wrong answer', () {
      final r = gradeOne('   ', '你好');
      expect(r.grade, PronunciationGrade.notHeard);
      expect(r.heard, isEmpty);
    });

    test('an unknown word still grades, just without a reading', () {
      final r = gradeOne('电脑', '你好');
      expect(r.grade, PronunciationGrade.wrongWord);
      expect(r.heardPinyin, isEmpty);
    });

    test('a different-length miss has no misleading alignment', () {
      final r = gradeOne('好', '你好');
      expect(r.grade, PronunciationGrade.wrongWord);
      expect(r.comparison, isEmpty);
    });
  });

  group('PronunciationService.isConclusive', () {
    test('an exact partial match lets listening stop early', () {
      expect(
        PronunciationService.isConclusive(
          alternates: ['你好'],
          targetHanzi: '你好',
        ),
        isTrue,
      );
    });

    test('a partial that is not the target keeps listening', () {
      expect(
        PronunciationService.isConclusive(alternates: ['你'], targetHanzi: '你好'),
        isFalse,
      );
    });
  });
}
