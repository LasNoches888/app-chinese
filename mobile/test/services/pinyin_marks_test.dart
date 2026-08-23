import 'package:flutter_test/flutter_test.dart';

import 'package:app_chinese/services/pinyin.dart';

/// Where a tone mark sits is a fixed rule, not a preference, and the
/// dictionary stores every reading in the numbered notation — so this is
/// the step that turns 124k stored readings into something a learner can
/// read. Getting the vowel wrong silently mis-spells every one of them.
void main() {
  group('Pinyin.withMarks', () {
    test('marks the single vowel', () {
      expect(Pinyin.withMarks('wo3'), 'wǒ');
      expect(Pinyin.withMarks('shi4'), 'shì');
    });

    test('prefers a over everything else', () {
      expect(Pinyin.withMarks('hao3'), 'hǎo');
      expect(Pinyin.withMarks('jiao4'), 'jiào');
    });

    test('prefers o over e', () {
      expect(Pinyin.withMarks('guo2'), 'guó');
      expect(Pinyin.withMarks('dou1'), 'dōu');
    });

    test('falls back to e', () {
      expect(Pinyin.withMarks('xue2'), 'xué');
      expect(Pinyin.withMarks('lei4'), 'lèi');
    });

    test('iu takes the mark on the u, ui on the i', () {
      // The one rule people get wrong, and the reason this is not simply
      // "mark the first vowel".
      expect(Pinyin.withMarks('liu4'), 'liù');
      expect(Pinyin.withMarks('hui2'), 'huí');
    });

    test('v stands in for ü', () {
      expect(Pinyin.withMarks('lv4'), 'lǜ');
      expect(Pinyin.withMarks('nv3'), 'nǚ');
    });

    test('the neutral tone gets no mark', () {
      expect(Pinyin.withMarks('le5'), 'le');
      expect(Pinyin.withMarks('ma5'), 'ma');
    });

    test('a whole word keeps its syllables apart', () {
      expect(Pinyin.withMarks('ni3 hao3'), 'nǐ hǎo');
      expect(Pinyin.withMarks('xi3 huan5'), 'xǐ huan');
    });

    test('anything that is not a numbered syllable is left alone', () {
      expect(Pinyin.withMarks('OK'), 'OK');
      expect(Pinyin.withMarks(''), '');
    });

    test('a marked reading is the same syllables as its numbered source', () {
      expect(
        Pinyin.toneless(Pinyin.withMarks('zhang3 da4')),
        Pinyin.toneless('zhang3 da4'),
      );
    });

    test('the two notations put the tone digit in different places', () {
      // Not a defect being pinned down so much as a boundary: withTones()
      // writes the digit against the toned vowel ("ha3o"), while numbered
      // input carries it at the end of the syllable ("hao3"). So it
      // compares readings written the same way, never across notations —
      // the graders only ever see the course's marked pinyin.
      expect(Pinyin.withTones('hǎo'), 'ha3o');
      expect(Pinyin.withTones('hao3'), 'hao3');
      expect(Pinyin.sameIgnoringTones('hǎo', 'hao3'), isTrue);
    });
  });

  group('Pinyin.joinErhua', () {
    test('a standalone r joins the syllable before it', () {
      expect(Pinyin.joinErhua('nǎ r'), 'nǎr');
      expect(Pinyin.joinErhua('zhè r'), 'zhèr');
    });

    test('an r that starts a syllable is untouched', () {
      expect(Pinyin.joinErhua('rén'), 'rén');
      expect(Pinyin.joinErhua('wǒ rènshi'), 'wǒ rènshi');
    });
  });
}
