/// What a plan step measures. Every kind maps onto something the app
/// already records, so progress is read off real activity rather than
/// asking the learner to tick boxes.
enum PlanStepKind {
  /// Finish a specific deck.
  deck,

  /// Reach a total number of learned words (SRS-confirmed, not just seen).
  words,

  /// Reach a current streak length.
  streak,

  /// Complete N daily challenges.
  dailyChallenge,

  /// Finish N lessons with no mistakes.
  perfectLesson,

  /// Answer N listening comprehension questions correctly.
  listening,

  /// Pass N pronunciation checks.
  pronunciation,
}

class PlanStep {
  final PlanStepKind kind;

  /// Which deck, for [PlanStepKind.deck].
  final String? deckId;

  /// How many, for the counting kinds.
  final int target;

  /// What the learner will be able to do — phrased as a capability, not a
  /// task, because that's what makes a plan feel like progress rather
  /// than a checklist.
  final String titleRu;

  const PlanStep.deck(this.deckId, this.titleRu)
    : kind = PlanStepKind.deck,
      target = 1;

  const PlanStep.words(this.target, this.titleRu)
    : kind = PlanStepKind.words,
      deckId = null;

  const PlanStep.streak(this.target, this.titleRu)
    : kind = PlanStepKind.streak,
      deckId = null;

  const PlanStep.dailyChallenge(this.target, this.titleRu)
    : kind = PlanStepKind.dailyChallenge,
      deckId = null;

  const PlanStep.perfectLesson(this.target, this.titleRu)
    : kind = PlanStepKind.perfectLesson,
      deckId = null;

  const PlanStep.listening(this.target, this.titleRu)
    : kind = PlanStepKind.listening,
      deckId = null;

  const PlanStep.pronunciation(this.target, this.titleRu)
    : kind = PlanStepKind.pronunciation,
      deckId = null;
}

class StudyPlan {
  final String id;
  final String emoji;
  final String titleRu;
  final String descriptionRu;

  /// Honest pace estimate. Published beginner plans converge on the same
  /// point — consistency moves the timeline far more than intensity — so
  /// these are quoted as "N minutes a day for about M weeks" rather than
  /// a single deadline.
  final String paceRu;

  /// Roughly which stage this belongs to: 1 foundation, 2 expanding,
  /// 3 approaching intermediate. Drives grouping in the list.
  final int stage;

  final List<PlanStep> steps;

  const StudyPlan({
    required this.id,
    required this.emoji,
    required this.titleRu,
    required this.descriptionRu,
    required this.paceRu,
    required this.stage,
    required this.steps,
  });
}

/// The bundled study plans.
///
/// Structured after the way published beginner Chinese curricula are
/// built: three stages (foundation, expanding, approaching intermediate),
/// each step a concrete capability, and every plan mixing vocabulary with
/// listening and speaking rather than being a long flashcard queue —
/// spending almost all the time on passive drilling is the single most
/// common criticism of self-study plans.
const kStudyPlans = <StudyPlan>[
  StudyPlan(
    id: 'first_steps',
    emoji: '🌱',
    titleRu: 'Первые шаги',
    descriptionRu:
        'Поздороваться, назвать себя и посчитать до ста. С этого начинают все.',
    paceRu: '10–15 минут в день · около недели',
    stage: 1,
    steps: [
      PlanStep.deck('greetings', 'Здороваться и прощаться'),
      PlanStep.deck('numbers', 'Считать и называть числа'),
      PlanStep.deck('people', 'Говорить «я», «ты», «学生»'),
      PlanStep.streak(3, 'Позаниматься 3 дня подряд'),
      PlanStep.perfectLesson(1, 'Пройти урок без единой ошибки'),
    ],
  ),
  StudyPlan(
    id: 'about_me',
    emoji: '👋',
    titleRu: 'Рассказать о себе',
    descriptionRu:
        'Семья, занятия и простые описания — чтобы поддержать разговор о себе.',
    paceRu: '15 минут в день · 1–2 недели',
    stage: 1,
    steps: [
      PlanStep.deck('family', 'Назвать членов семьи'),
      PlanStep.deck('verbs1', 'Сказать, что ты делаешь'),
      PlanStep.deck('adjectives1', 'Описать словами «большой», «хороший»'),
      PlanStep.pronunciation(5, 'Проверить своё произношение 5 раз'),
      PlanStep.dailyChallenge(3, 'Пройти 3 ежедневных испытания'),
    ],
  ),
  StudyPlan(
    id: 'food_city',
    emoji: '🍜',
    titleRu: 'Еда и покупки',
    descriptionRu:
        'Заказать в кафе, спросить цену и не растеряться в магазине.',
    paceRu: '15 минут в день · 2 недели',
    stage: 2,
    steps: [
      PlanStep.deck('food', 'Заказать еду и напитки'),
      PlanStep.deck('food2', 'Разобраться в меню пошире'),
      PlanStep.deck('shopping2', 'Спросить цену и купить'),
      PlanStep.listening(5, 'Понять 5 диалогов на слух'),
    ],
  ),
  StudyPlan(
    id: 'getting_around',
    emoji: '🚌',
    titleRu: 'Дорога и город',
    descriptionRu:
        'Спросить дорогу, доехать до места и объяснить, где ты находишься.',
    paceRu: '15 минут в день · 2 недели',
    stage: 2,
    steps: [
      PlanStep.deck('places1', 'Назвать места в городе'),
      PlanStep.deck('movement', 'Сказать, куда идёшь'),
      PlanStep.deck('transport2', 'Разобраться с транспортом'),
      PlanStep.listening(5, 'Понять 5 диалогов на слух'),
      PlanStep.pronunciation(5, 'Проверить произношение 5 раз'),
    ],
  ),
  StudyPlan(
    id: 'hsk1_complete',
    emoji: '📘',
    titleRu: 'Весь HSK 1',
    descriptionRu:
        'Закрыть базовый уровень целиком: все темы, устойчивая привычка заниматься.',
    paceRu: '15–20 минут в день · 4–6 недель',
    stage: 2,
    steps: [
      PlanStep.deck('time', 'Говорить о времени и датах'),
      PlanStep.deck('questions', 'Задавать вопросы'),
      PlanStep.deck('objects1', 'Называть предметы вокруг'),
      PlanStep.deck('grammar1', 'Собирать простые фразы'),
      PlanStep.words(100, 'Выучить 100 слов'),
      PlanStep.streak(7, 'Заниматься 7 дней подряд'),
      PlanStep.listening(10, 'Понять 10 диалогов на слух'),
    ],
  ),
  StudyPlan(
    id: 'hsk2_complete',
    emoji: '📗',
    titleRu: 'Весь HSK 2',
    descriptionRu:
        'Расширить словарь до бытовых тем и научиться понимать связную речь.',
    paceRu: '20 минут в день · 6–8 недель',
    stage: 2,
    steps: [
      PlanStep.deck('colors', 'Различать цвета'),
      PlanStep.deck('study2', 'Говорить об учёбе'),
      PlanStep.deck('body2', 'Рассказать о самочувствии'),
      PlanStep.deck('adverbs2', 'Связывать мысли: «потому что», «поэтому»'),
      PlanStep.deck('daily2', 'Обсуждать повседневное'),
      PlanStep.words(250, 'Выучить 250 слов'),
      PlanStep.streak(14, 'Заниматься 14 дней подряд'),
    ],
  ),
  StudyPlan(
    id: 'hsk3_start',
    emoji: '📕',
    titleRu: 'Вход в HSK 3',
    descriptionRu:
        'Абстрактные темы: чувства, работа, общество — язык взрослых разговоров.',
    paceRu: '20 минут в день · 6–8 недель',
    stage: 3,
    steps: [
      PlanStep.deck('emotions3', 'Говорить о чувствах'),
      PlanStep.deck('work3', 'Обсуждать работу'),
      PlanStep.deck('travel3', 'Рассказать о поездке'),
      PlanStep.deck('nature3', 'Описать погоду и сезоны'),
      PlanStep.deck('society3', 'Рассуждать об окружающем'),
      PlanStep.words(300, 'Выучить 300 слов'),
    ],
  ),
];
