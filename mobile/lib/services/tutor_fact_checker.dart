import '../models/chat_message.dart';
import '../repositories/dictionary_repository.dart';

/// What a fact check changed, if anything.
class CheckedReply {
  final ChatMessage message;

  /// True when something was taken out. The learner is told, because a
  /// reply with a hole in it that claims to be untouched is its own kind
  /// of wrong.
  final bool wasEdited;

  const CheckedReply(this.message, {this.wasEdited = false});
}

/// Removes claims about Chinese that the app can prove are false.
///
/// Testing the on-device tutor turned up a second failure beyond its
/// pinyin: it occasionally states something untrue about the language
/// itself — in one run it called 但是 "важная часть русского языка".
/// That is not a transcription slip that a lookup fixes; it is the model
/// being wrong about its subject, which no amount of fine-tuning a 1.5B
/// model reliably cures.
///
/// So the app checks the two claims it can actually settle:
///
///  * **Which language a word belongs to.** Anything written in Chinese
///    characters is Chinese. A sentence that hands those characters to
///    some other named language, without mentioning Chinese at all, is
///    wrong — and a sentence that does mention Chinese is a comparison,
///    which is legitimate and left alone.
///  * **Whether a word exists.** Vocabulary is presented to the learner
///    as things to go and memorise, so an invented compound does real
///    damage. Anything absent from all 124k dictionary entries is
///    dropped from that list.
///
/// Everything else the tutor says about the language stands. This is a
/// filter for the provably false, not a judge of teaching quality.
class TutorFactChecker {
  final DictionaryRepository _dictionary;

  const TutorFactChecker(this._dictionary);

  static final _han = RegExp(r'[㐀-䶿一-鿿]');

  /// The tutor writes in Russian, so these are the Russian names of the
  /// languages a Chinese word could be misassigned to.
  ///
  /// Endings are spelled out as Cyrillic ranges rather than `\w`, which in
  /// Dart matches ASCII only and so matched none of this.
  static final _foreignLanguage = RegExp(
    r'(русск|английск|японск|корейск|француз|немецк|испанск|итальянск|'
    r'арабск|турецк|украинск)[а-яё]*\s+'
    r'(язык[а-яё]*|слов[а-яё]*|фраз[а-яё]*|выражени[а-яё]*|речи|речь)',
    caseSensitive: false,
  );

  /// A sentence naming Chinese is comparing languages, not confusing
  /// them.
  static final _mentionsChinese = RegExp(
    r'(китайск|путунхуа|мандарин|中文|汉语|普通话)',
    caseSensitive: false,
  );

  /// Sentence boundaries in both scripts, kept so the surviving text
  /// still reads as sentences.
  static final _sentenceSplit = RegExp(r'(?<=[.!?。！？\n])\s*');

  /// Marker values rather than sentences: the screen turns these into
  /// text in the learner's language.
  static const partRemoved = 'chatFactRemoved';
  static const replyUnreliable = 'chatFactUnreliable';

  Future<CheckedReply> check(ChatMessage message) async {
    final text = _withoutMisattribution(message.text);
    final words = await _verifiedWords(message.newWords);
    final filteredRecast = message.grammarRecast == null
        ? null
        : _withoutMisattribution(message.grammarRecast!);
    final recast = (filteredRecast?.isEmpty ?? true) ? null : filteredRecast;

    final edited =
        text != message.text ||
        words.length != message.newWords.length ||
        recast != message.grammarRecast;
    if (!edited) return CheckedReply(message);

    // A reply that was nothing but a false claim has nothing left to
    // show; the note becomes the whole message rather than leaving an
    // empty bubble.
    final nothingLeft = text.isEmpty;
    return CheckedReply(
      message.copyWith(
        text: text,
        clearGrammarRecast: recast == null,
        grammarRecast: recast,
        newWords: words,
        note: nothingLeft ? replyUnreliable : partRemoved,
      ),
      wasEdited: true,
    );
  }

  String _withoutMisattribution(String text) {
    if (!_han.hasMatch(text)) return text;
    final kept = text
        .split(_sentenceSplit)
        .where((sentence) => !_misattributes(sentence))
        .join(' ');
    return kept.replaceAll(RegExp(r' {2,}'), ' ').trim();
  }

  static bool _misattributes(String sentence) =>
      _han.hasMatch(sentence) &&
      _foreignLanguage.hasMatch(sentence) &&
      !_mentionsChinese.hasMatch(sentence);

  /// Drops vocabulary the dictionary has never heard of, and anything
  /// whose gloss misattributes it.
  Future<List<NewWord>> _verifiedWords(List<NewWord> words) async {
    if (words.isEmpty) return words;
    final chinese = words.where((w) => _han.hasMatch(w.word)).toList();
    final known = await _dictionary.pinyinFor(chinese.map((w) => w.word));
    return [
      for (final word in chinese)
        if (known.containsKey(word.word) &&
            !_misattributes('${word.word} ${word.translation}'))
          word,
    ];
  }
}
