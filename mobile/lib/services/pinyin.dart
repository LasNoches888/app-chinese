/// Pinyin normalization shared by the typed-pinyin exercise and the
/// pronunciation grader.
///
/// Pinyin reaches the app in three notations — tone marks (nǐ), tone
/// digits (ni3) and bare letters (ni) — and the stored data isn't even
/// consistently spaced ("nǐ hǎo" but "kuàilè"). Comparing any of that
/// meaningfully needs one canonical form, and both callers were about to
/// grow their own copy of it.
class Pinyin {
  /// Vowel with a tone mark -> plain letter + tone digit.
  static const _toneMarks = <String, String>{
    'ā': 'a1',
    'á': 'a2',
    'ǎ': 'a3',
    'à': 'a4',
    'ē': 'e1',
    'é': 'e2',
    'ě': 'e3',
    'è': 'e4',
    'ī': 'i1',
    'í': 'i2',
    'ǐ': 'i3',
    'ì': 'i4',
    'ō': 'o1',
    'ó': 'o2',
    'ǒ': 'o3',
    'ò': 'o4',
    'ū': 'u1',
    'ú': 'u2',
    'ǔ': 'u3',
    'ù': 'u4',
    'ǖ': 'v1',
    'ǘ': 'v2',
    'ǚ': 'v3',
    'ǜ': 'v4',
    'ü': 'v',
  };

  /// Letters only: no tones, no spaces, no apostrophes. Two spellings of
  /// the same sounds compare equal — "nǐ hǎo", "ni3hao3" and "nihao" all
  /// collapse to "nihao".
  static String toneless(String input) =>
      _stripSeparators(_expand(input)).replaceAll(RegExp(r'[0-9]'), '');

  /// Letters plus a tone digit after each toned vowel, spaces removed —
  /// "nǐ hǎo" and "ni3hao3" both become "ni3hao3", so tone differences
  /// survive the comparison that [toneless] deliberately erases.
  static String withTones(String input) => _stripSeparators(_expand(input));

  /// Whether two pinyin strings are the same syllables said with the same
  /// tones.
  static bool sameWithTones(String a, String b) => withTones(a) == withTones(b);

  /// Whether two pinyin strings are the same syllables, tones aside —
  /// true for a tone slip, false for a genuinely different word.
  static bool sameIgnoringTones(String a, String b) =>
      toneless(a) == toneless(b);

  /// True when the syllables match but the tones don't: the specific
  /// "you said the right sounds with the wrong melody" case.
  static bool isToneOnlyDifference(String a, String b) =>
      sameIgnoringTones(a, b) && !sameWithTones(a, b);

  static String _expand(String input) {
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_toneMarks[ch] ?? ch);
    }
    return buffer.toString();
  }

  static String _stripSeparators(String input) =>
      input.replaceAll(RegExp(r"[\s'’\-]+"), '').trim();
}
