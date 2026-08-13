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
    int sentenceQuestionCap = 2,
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
    final candidates = pool.where((w) => w.id != word.id && selector(w) != value).toList()..shuffle(rng);
    return candidates.take(count).map(selector).toList();
  }
}
