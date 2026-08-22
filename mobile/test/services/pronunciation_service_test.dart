import 'package:flutter_test/flutter_test.dart';

import 'package:app_chinese/services/pronunciation_service.dart';

/// The grading is the whole value of the pronunciation check — a bare
/// "contains the word" boolean couldn't tell the learner *what* to fix.
void main() {
  group('PronunciationService.grade', () {
    test('an exact match is correct', () {
      final r = PronunciationService.grade('你好', '你好');
      expect(r.grade, PronunciationGrade.correct);
      expect(r.isCorrect, isTrue);
      expect(r.mistakes, isEmpty);
    });

    test('punctuation the recognizer adds does not break an exact match', () {
      final r = PronunciationService.grade('你好。', '你好');
      expect(r.grade, PronunciationGrade.correct);
    });

    test('the target buried in a longer phrase counts as close', () {
      final r = PronunciationService.grade('那个你好吗', '你好');
      expect(r.grade, PronunciationGrade.closeExtraWords);
      expect(r.isCorrect, isFalse);
    });

    test('a same-length different word reports per-character mistakes', () {
      // 妈 vs 马 is the classic wrong-tone outcome: the syllable is right,
      // the tone lands on another real character.
      final r = PronunciationService.grade('马', '妈');
      expect(r.grade, PronunciationGrade.wrongWord);
      expect(r.mistakes.length, 1);
      expect(r.mistakes.single.expected, '妈');
      expect(r.mistakes.single.heard, '马');
    });

    test('only the differing characters are reported as mistakes', () {
      final r = PronunciationService.grade('你号', '你好');
      expect(r.grade, PronunciationGrade.wrongWord);
      expect(r.mistakes.length, 1);
      expect(r.mistakes.single.expected, '好');
    });

    test('a different-length miss has no misleading alignment', () {
      final r = PronunciationService.grade('好', '你好吗');
      expect(r.grade, PronunciationGrade.wrongWord);
      expect(r.comparison, isEmpty);
    });

    test('silence is reported as not heard, not as a wrong answer', () {
      final r = PronunciationService.grade('   ', '你好');
      expect(r.grade, PronunciationGrade.notHeard);
      expect(r.heard, isEmpty);
    });
  });
}
