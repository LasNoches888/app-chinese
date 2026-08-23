import '../models/dict_entry.dart';
import '../models/word.dart';
import '../repositories/dictionary_repository.dart';
import 'pinyin.dart';
import 'pinyin_annotator.dart';

/// Builds the word reference the tutor model is told to speak from.
///
/// The model is 1.5B. It writes fluent Russian and passable Chinese, but
/// it cannot hold the facts of the language — asked what a word it has
/// never seen means, it invents an answer, confidently. Fine-tuning does
/// not fix that: it teaches format and voice, not knowledge, and there is
/// no room in 1.5B parameters for tens of thousands of characters.
///
/// So the model stops being asked to remember. Before every reply the app
/// looks the relevant words up in the shipped 124k-entry dictionary and
/// hands the entries over in the prompt, with an instruction to speak
/// about words only from them. The task changes from "recall what 但是
/// means" — which it cannot do — to "say this naturally in Russian",
/// which testing showed it does well.
///
/// The failure mode changes with it. An ungrounded model states something
/// false with confidence; a grounded one is either right or says it isn't
/// sure, and a learner survives the second far better than the first.
class TutorReference {
  /// Cap on entries. The context window is 4096 tokens and the persona,
  /// history and reply all have to fit beside this.
  static const maxEntries = 12;

  /// Russian words too short or too common to be worth a lookup — without
  /// this, "как это сказать" searches the dictionary three times for
  /// nothing.
  static const _stopWords = {
    'как',
    'что',
    'это',
    'кто',
    'где',
    'когда',
    'почему',
    'зачем',
    'который',
    'значит',
    'сказать',
    'слово',
    'слова',
    'китайском',
    'китайски',
    'китайский',
    'пожалуйста',
    'можно',
    'нужно',
    'хочу',
    'меня',
    'тебя',
    'быть',
    'есть',
  };

  static final _han = RegExp(r'[㐀-䶿一-鿿]');
  static final _cyrillicWord = RegExp(r'[а-яёА-ЯЁ]{3,}');

  /// Assembles the reference for one turn.
  ///
  /// Three sources, in falling order of certainty: the words the learner
  /// just wrote, the words the app is asking the tutor to revise, and
  /// whatever the learner's Russian seems to be asking about.
  static Future<String> build({
    required String learnerMessage,
    required List<Word> weakWords,
    required DictionaryRepository dictionary,
    required PinyinAnnotator annotator,
  }) async {
    final lines = <String, String>{};

    // What the learner wrote is what the reply is about, so it comes
    // first and is never crowded out by the rest.
    final written = await annotator.segment(learnerMessage);
    final entries = await dictionary.entriesFor(written);
    for (final word in written) {
      final entry = entries[word];
      if (entry != null) lines[word] = _lineFor(entry);
    }

    // The tutor is told to weave these back in, so it had better know
    // what they mean. Their Russian was checked by hand.
    for (final word in weakWords) {
      if (lines.length >= maxEntries) break;
      lines.putIfAbsent(
        word.hanzi,
        () =>
            '${word.hanzi} — ${Pinyin.joinErhua(word.pinyin)} — '
            '${word.translationRu}',
      );
    }

    // A beginner asks in Russian far more often than in Chinese, so
    // without this the reference would usually be empty exactly when it
    // is needed most.
    for (final query in _russianQueries(learnerMessage)) {
      if (lines.length >= maxEntries) break;
      final hits = await dictionary.search(query, limit: 2);
      for (final hit in hits) {
        if (lines.length >= maxEntries) break;
        lines.putIfAbsent(hit.simplified, () => _lineFor(hit));
      }
    }

    if (lines.isEmpty) return '';
    return '''

## Справка по словам
Это единственный источник о значении и чтении слов. Если нужного слова
здесь нет — не придумывай его перевод, чтение или состав, а скажи, что
не уверен, и предложи посмотреть в словаре приложения.
${lines.values.join('\n')}
''';
  }

  /// One entry, trimmed to what a tutor needs: the word, how it is read,
  /// and the first couple of meanings. The full gloss list runs to a
  /// paragraph for common words and would eat the context.
  static String _lineFor(DictEntry entry) {
    final meanings = entry.russian.isEmpty ? entry.english : entry.russian;
    final short = meanings.split('; ').take(3).join('; ');
    return '${entry.simplified} — ${Pinyin.joinErhua(Pinyin.withMarks(entry.pinyin))} — $short';
  }

  static Iterable<String> _russianQueries(String message) sync* {
    if (_han.hasMatch(message)) return;
    final seen = <String>{};
    for (final match in _cyrillicWord.allMatches(message)) {
      final word = match.group(0)!.toLowerCase();
      if (_stopWords.contains(word) || !seen.add(word)) continue;
      yield word;
    }
  }
}
