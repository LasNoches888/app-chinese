import '../models/chat_message.dart';
import '../repositories/dictionary_repository.dart';
import '../repositories/word_repository.dart';
import 'pinyin.dart';

/// Produces the pinyin for Chinese text instead of trusting the tutor
/// model's.
///
/// The on-device model is 1.5B parameters. It learned to write characters
/// well, but transcription is a separate skill it cannot hold for the
/// whole language — on words outside its training data it guesses, and a
/// wrong transcription is worse than none, because a learner has no way
/// to tell. Transcription is a lookup, not a judgement call, so it is
/// done here: the shipped dictionary already holds CC-CEDICT's
/// hand-curated reading for all 124k entries.
///
/// Segmentation is the reason this works at all. Half the common
/// characters have several readings — 长 is cháng or zhǎng, 行 is xíng or
/// háng — and only the surrounding word decides which. Matching the
/// longest word first resolves those; going character by character would
/// be wrong about as often as the model is.
class PinyinAnnotator {
  final DictionaryRepository _dictionary;
  final WordRepository _words;

  PinyinAnnotator(this._dictionary, this._words);

  /// Longest word the segmenter will try. CC-CEDICT holds longer entries
  /// (chengyu, proper names), but every extra length costs another
  /// candidate per character, and beyond four the matches are idioms
  /// whose reading is the sum of their parts anyway.
  static const _maxWordLength = 4;

  static final _han = RegExp(r'[㐀-䶿一-鿿]');

  /// The course's own readings, which are hand-checked and therefore beat
  /// the dictionary where they overlap. Loaded once: it is a few hundred
  /// words and every chat reply would otherwise re-read them.
  static Future<Map<String, String>>? _courseReadings;

  /// Chinese punctuation has no pinyin; its Latin equivalent keeps the
  /// transcription readable as a sentence.
  static const _punctuation = <String, String>{
    '。': '.',
    '，': ',',
    '、': ',',
    '！': '!',
    '？': '?',
    '：': ':',
    '；': ';',
    '“': '"',
    '”': '"',
    '‘': "'",
    '’': "'",
    '（': '(',
    '）': ')',
    '《': '"',
    '》': '"',
  };

  /// Transcribes [text], leaving anything that isn't Chinese as it is.
  ///
  /// A character the dictionary doesn't know is passed through unchanged
  /// rather than guessed at — an unreadable character in the output is
  /// honest, a plausible wrong syllable is not.
  Future<String> transcribe(String text) async {
    if (!_han.hasMatch(text)) return text;
    final readings = await _readingsFor(text);

    final out = StringBuffer();
    var i = 0;
    while (i < text.length) {
      final char = text[i];
      if (!_han.hasMatch(char)) {
        out.write(_punctuation[char] ?? char);
        i++;
        continue;
      }

      final match = _longestMatch(text, i, readings);
      if (match == null) {
        out.write(char);
        i++;
      } else {
        out.write('${readings[match]} ');
        i += match.length;
      }
    }
    return _tidy(out.toString());
  }

  /// Replaces the model's pinyin — on the reply and on every word it
  /// claims to have introduced — with the looked-up one.
  Future<ChatMessage> correct(ChatMessage message) async {
    if (!_han.hasMatch(message.text)) return message;
    return message.copyWith(
      pinyin: await transcribe(message.text),
      newWords: [
        for (final word in message.newWords)
          NewWord(
            word: word.word,
            pinyin: await transcribe(word.word),
            translation: word.translation,
          ),
      ],
    );
  }

  /// Readings for every candidate word in [text], already in tone marks.
  ///
  /// The dictionary answers for the language; the course overrides it for
  /// the words it teaches, where the reading was checked by hand. That
  /// matters most on the particles CC-CEDICT lists twice — 吧 is both bā
  /// and the neutral ba, and only one of them ends a sentence.
  Future<Map<String, String>> _readingsFor(String text) async {
    final candidates = _candidates(text);
    final numbered = await _dictionary.pinyinFor(candidates);
    final course = await (_courseReadings ??= _loadCourseReadings());

    return {
      for (final entry in numbered.entries)
        entry.key: Pinyin.joinErhua(Pinyin.withMarks(entry.value)),
      for (final word in candidates)
        if (course.containsKey(word)) word: course[word]!,
    };
  }

  Future<Map<String, String>> _loadCourseReadings() async {
    final words = await _words.getAllWords();
    return {
      for (final word in words) word.hanzi: Pinyin.joinErhua(word.pinyin),
    };
  }

  /// Every Chinese substring up to [_maxWordLength] that could be a word,
  /// so the whole sentence resolves in one query.
  Set<String> _candidates(String text) {
    final out = <String>{};
    for (var i = 0; i < text.length; i++) {
      if (!_han.hasMatch(text[i])) continue;
      for (
        var len = 1;
        len <= _maxWordLength && i + len <= text.length;
        len++
      ) {
        final slice = text.substring(i, i + len);
        if (!_isAllHan(slice)) break;
        out.add(slice);
      }
    }
    return out;
  }

  String? _longestMatch(String text, int at, Map<String, String> readings) {
    final maxLen = (at + _maxWordLength <= text.length)
        ? _maxWordLength
        : text.length - at;
    for (var len = maxLen; len >= 1; len--) {
      final slice = text.substring(at, at + len);
      if (!_isAllHan(slice)) continue;
      if (readings.containsKey(slice)) return slice;
    }
    return null;
  }

  static bool _isAllHan(String slice) {
    for (var i = 0; i < slice.length; i++) {
      if (!_han.hasMatch(slice[i])) return false;
    }
    return true;
  }

  /// Syllables are emitted with a trailing space, so punctuation ends up
  /// with a gap in front of it and none behind.
  static String _tidy(String text) => text
      .replaceAllMapped(RegExp(r' +([,.!?:;)"])'), (m) => m[1]!)
      .replaceAllMapped(RegExp(r'([,.!?:;])(?=[^\s,.!?:;])'), (m) => '${m[1]} ')
      .replaceAll(RegExp(r' {2,}'), ' ')
      .trim();

  /// Test seam: drops the cached course readings.
  static void resetCacheForTest() => _courseReadings = null;
}
