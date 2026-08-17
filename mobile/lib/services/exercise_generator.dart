import 'dart:math';

import '../models/exercise_question.dart';
import '../models/word.dart';

/// Builds a randomized queue of exercises for a set of lesson/review
/// words, cycling through the exercise types from the spec (flashcard
/// flip, multiple-choice translation, reverse multiple-choice, pinyin
/// typing, sentence building) and pulling multiple-choice distractors
/// from the full word bank for variety. No audio/TTS-based types — those
/// are explicitly out of scope.
class ExerciseGenerator {
  static List<ExerciseQuestion> build({
    required List<Word> lessonWords,
    required List<Word> allWords,
    Set<String> availableStrokeChars = const {},
    int sentenceQuestionCap = 2,
    int writeHanziCap = 2,
  }) {
    final rng = Random();
    final questions = <ExerciseQuestion>[];
    const types = [
      ExerciseType.flip,
      ExerciseType.chooseTranslation,
      ExerciseType.chooseHanzi,
      ExerciseType.typePinyin,
    ];

    for (var i = 0; i < lessonWords.length; i++) {
      final word = lessonWords[i];
      final type = types[i % types.length];
      final id = '${word.id}-${type.name}-$i';

      switch (type) {
        case ExerciseType.flip:
          questions.add(ExerciseQuestion(
            id: id,
            wordId: word.id,
            type: ExerciseType.flip,
            hanzi: word.hanzi,
            pinyin: word.pinyin,
            translation: word.translationRu,
          ));
          break;
        case ExerciseType.chooseTranslation:
          {
            final distractors = _distractors(word, allWords, (w) => w.translationRu, rng, 3);
            final options = [word.translationRu, ...distractors]..shuffle(rng);
            questions.add(ExerciseQuestion(
              id: id,
              wordId: word.id,
              type: ExerciseType.chooseTranslation,
              hanzi: word.hanzi,
              options: options,
              correctOption: word.translationRu,
            ));
          }
          break;
        case ExerciseType.chooseHanzi:
          {
            final distractors = _distractors(word, allWords, (w) => w.hanzi, rng, 3);
            final options = [word.hanzi, ...distractors]..shuffle(rng);
            questions.add(ExerciseQuestion(
              id: id,
              wordId: word.id,
              type: ExerciseType.chooseHanzi,
              translation: word.translationRu,
              options: options,
              correctOption: word.hanzi,
            ));
          }
          break;
        case ExerciseType.typePinyin:
          questions.add(ExerciseQuestion(
            id: id,
            wordId: word.id,
            type: ExerciseType.typePinyin,
            hanzi: word.hanzi,
            correctPinyin: word.pinyin,
          ));
          break;
        case ExerciseType.buildSentence:
        case ExerciseType.writeHanzi:
          break; // handled separately below
      }
    }

    final withSentences = lessonWords.where((w) => w.exampleSentence != null && w.exampleSentence!.isNotEmpty).toList()
      ..shuffle(rng);
    for (final word in withSentences.take(sentenceQuestionCap)) {
      final tiles = word.exampleSentence!.split('').toList()..shuffle(rng);
      questions.add(ExerciseQuestion(
        id: 'sentence-${word.id}',
        wordId: word.id,
        type: ExerciseType.buildSentence,
        tiles: tiles,
        correctOrder: word.exampleSentence!.split(''),
        sentenceTranslation: word.exampleTranslation,
      ));
    }

    if (availableStrokeChars.isNotEmpty) {
      // One writing question per unique character (not per word) with
      // stroke data available, tied back to a word that contains it so
      // SRS/mistake tracking still has a real word to attach to.
      final charToWord = <String, Word>{};
      for (final word in lessonWords) {
        for (final ch in word.hanzi.split('')) {
          if (availableStrokeChars.contains(ch)) {
            charToWord.putIfAbsent(ch, () => word);
          }
        }
      }
      final chars = charToWord.keys.toList()..shuffle(rng);
      for (final ch in chars.take(writeHanziCap)) {
        final word = charToWord[ch]!;
        questions.add(ExerciseQuestion(
          id: 'write-$ch',
          wordId: word.id,
          type: ExerciseType.writeHanzi,
          hanzi: ch,
          translation: word.translationRu,
        ));
      }
    }

    questions.shuffle(rng);
    return questions;
  }

  static List<String> _distractors(
    Word word,
    List<Word> pool,
    String Function(Word) selector,
    Random rng,
    int count,
  ) {
    final value = selector(word);
    // Dedupe by value, not just word id — two different words can share a
    // translation/hanzi, which would otherwise render two identical-text
    // answer buttons.
    final seen = <String>{value};
    final candidates = <String>[];
    for (final w in pool..shuffle(rng)) {
      final v = selector(w);
      if (seen.add(v)) candidates.add(v);
    }
    return candidates.take(count).toList();
  }
}
