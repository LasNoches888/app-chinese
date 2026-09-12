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

  /// Correctly write N hanzi from memory (the writeHanzi exercise type).
  writing,

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

  /// One line on what the step actually covers. A step called "говорить о
  /// времени" says nothing about whether that means clock times, dates or
  /// both; this is where that goes.
  final String detailRu;

  const PlanStep.deck(this.deckId, this.titleRu, this.detailRu)
    : kind = PlanStepKind.deck,
      target = 1;

  const PlanStep.words(this.target, this.titleRu, this.detailRu)
    : kind = PlanStepKind.words,
      deckId = null;

  const PlanStep.streak(this.target, this.titleRu, this.detailRu)
    : kind = PlanStepKind.streak,
      deckId = null;

  const PlanStep.dailyChallenge(this.target, this.titleRu, this.detailRu)
    : kind = PlanStepKind.dailyChallenge,
      deckId = null;

  const PlanStep.perfectLesson(this.target, this.titleRu, this.detailRu)
    : kind = PlanStepKind.perfectLesson,
      deckId = null;

  const PlanStep.listening(this.target, this.titleRu, this.detailRu)
    : kind = PlanStepKind.listening,
      deckId = null;

  const PlanStep.writing(this.target, this.titleRu, this.detailRu)
    : kind = PlanStepKind.writing,
      deckId = null;

  const PlanStep.pronunciation(this.target, this.titleRu, this.detailRu)
    : kind = PlanStepKind.pronunciation,
      deckId = null;
}

/// A phrase the learner will be able to say once the plan is done.
///
/// Plans described only in the abstract ("расширить словарь") all sound
/// alike; three real sentences say more about what a plan is worth than
/// any amount of description. Every sample is built from characters the
/// course actually teaches, so it is a promise the app can keep.
class PlanSample {
  final String hanzi;
  final String pinyin;
  final String ru;

  const PlanSample(this.hanzi, this.pinyin, this.ru);
}

/// Which of the app's two learning tracks a plan belongs to — shown as two
/// separate sections on the Plans screen so "learn to talk about things"
/// and "prepare for the HSK exam" read as distinct goals rather than one
/// undifferentiated list.
enum PlanTrack {
  /// Everyday-life topics (greetings, family, food, getting around...),
  /// not tied to clearing a specific exam level.
  topic,

  /// Aimed at finishing a whole HSK level.
  hsk,
}

class StudyPlan {
  final String id;
  final String emoji;
  final String titleRu;
  final String descriptionRu;

  /// Concrete abilities the plan buys, in the learner's words. Kept
  /// separate from [descriptionRu] because "зачем это мне" and "что это
  /// такое" are different questions, and only the first one keeps
  /// somebody going.
  final List<String> outcomesRu;

  /// Sentences unlocked by the plan. See [PlanSample].
  final List<PlanSample> samples;

  /// Honest pace estimate. Published beginner plans converge on the same
  /// point — consistency moves the timeline far more than intensity — so
  /// these are quoted as "N minutes a day for about M weeks" rather than
  /// a single deadline.
  final String paceRu;

  /// Roughly which stage this belongs to: 1 foundation, 2 expanding,
  /// 3 approaching intermediate. Orders plans within their [track] section.
  final int stage;

  /// Which of the two Plans-screen sections this belongs in. See
  /// [PlanTrack].
  final PlanTrack track;

  final List<PlanStep> steps;

  const StudyPlan({
    required this.id,
    required this.emoji,
    required this.titleRu,
    required this.descriptionRu,
    required this.outcomesRu,
    required this.samples,
    required this.paceRu,
    required this.stage,
    required this.track,
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
    outcomesRu: [
      'Поздороваться и попрощаться так, как это делают в Китае',
      'Сказать, кто ты, и спросить собеседника о том же',
      'Считать до ста и понимать числа на слух',
      'Вежливо ответить на «спасибо» и извиниться',
    ],
    samples: [
      PlanSample('你好！我是学生。', 'nǐ hǎo! wǒ shì xuésheng.', 'Привет! Я студент.'),
      PlanSample('谢谢！不客气。', 'xièxie! bú kèqi.', 'Спасибо! — Не за что.'),
      PlanSample('我们三个人。', 'wǒmen sān ge rén.', 'Нас трое.'),
    ],
    paceRu: '10–15 минут в день · около недели',
    stage: 1,
    track: PlanTrack.topic,
    steps: [
      PlanStep.deck(
        'greetings',
        'Здороваться и прощаться',
        'Десять фраз вежливости, с которых начинается любой разговор',
      ),
      PlanStep.deck(
        'numbers',
        'Считать и называть числа',
        'От 一 до 百: возраст, цены, номера — числа нужны сразу везде',
      ),
      PlanStep.deck(
        'people',
        'Говорить «я», «ты», «学生»',
        'Местоимения и слова о людях — без них не собрать ни одной фразы',
      ),
      PlanStep.listening(
        3,
        'Понять 3 коротких диалога',
        'Аудирование входит в HSK 1 с самого начала — не только читать, но и слышать',
      ),
      PlanStep.streak(
        3,
        'Позаниматься 3 дня подряд',
        'Три дня — тот момент, после которого занятия становятся привычкой',
      ),
      PlanStep.perfectLesson(
        1,
        'Пройти урок без единой ошибки',
        'Проверка, что материал усвоен, а не просто просмотрен',
      ),
    ],
  ),
  StudyPlan(
    id: 'about_me',
    emoji: '👋',
    titleRu: 'Рассказать о себе',
    descriptionRu:
        'Семья, занятия и простые описания — чтобы поддержать разговор о себе.',
    outcomesRu: [
      'Рассказать, кто есть в твоей семье и чем они занимаются',
      'Сказать, что ты делаешь прямо сейчас и что любишь',
      'Описать человека или вещь: большой, хороший, новый',
      'Разобрать на слух простой рассказ о семье и увлечениях',
    ],
    samples: [
      PlanSample(
        '我家有五个人。',
        'wǒ jiā yǒu wǔ ge rén.',
        'У нас в семье пять человек.',
      ),
      PlanSample('我妈妈是老师。', 'wǒ māma shì lǎoshī.', 'Моя мама — учительница.'),
      PlanSample(
        '我弟弟很小。',
        'wǒ dìdi hěn xiǎo.',
        'Мой младший брат совсем маленький.',
      ),
    ],
    paceRu: '15 минут в день · 1–2 недели',
    stage: 1,
    track: PlanTrack.topic,
    steps: [
      PlanStep.deck(
        'family',
        'Назвать членов семьи',
        'Родители, братья и сёстры — в китайском для каждого своё слово',
      ),
      PlanStep.deck(
        'verbs1',
        'Сказать, что ты делаешь',
        'Базовые глаголы: быть, иметь, смотреть, слушать, говорить',
      ),
      PlanStep.deck(
        'adjectives1',
        'Описать словами «большой», «хороший»',
        'Признаки и оценки — то, чем фраза перестаёт быть сухой',
      ),
      PlanStep.listening(
        5,
        'Понять 5 диалогов на слух',
        'HSK 1 проверяет чтение и слух, а не устную речь — тренировать стоит именно это',
      ),
      PlanStep.dailyChallenge(
        3,
        'Пройти 3 ежедневных испытания',
        'Короткая смешанная тренировка — заодно держит серию',
      ),
    ],
  ),
  StudyPlan(
    id: 'food_city',
    emoji: '🍜',
    titleRu: 'Еда и покупки',
    descriptionRu:
        'Заказать в кафе, спросить цену и не растеряться в магазине.',
    outcomesRu: [
      'Заказать еду и напитки, не показывая пальцем в меню',
      'Спросить, сколько стоит, и понять ответ',
      'Поторговаться: «дорого», «подешевле»',
      'Разобрать на слух короткий диалог в кафе или магазине',
    ],
    samples: [
      PlanSample('我要一杯茶。', 'wǒ yào yì bēi chá.', 'Мне, пожалуйста, чашку чая.'),
      PlanSample('这个多少钱？', 'zhège duōshao qián?', 'Сколько это стоит?'),
      PlanSample(
        '太贵了，便宜点儿。',
        'tài guì le, piányi diǎnr.',
        'Дорого, можно подешевле.',
      ),
    ],
    paceRu: '15 минут в день · 2 недели',
    stage: 2,
    track: PlanTrack.topic,
    steps: [
      PlanStep.deck(
        'food',
        'Заказать еду и напитки',
        'Рис, чай, вода, фрукты — самое частое в любом меню',
      ),
      PlanStep.deck(
        'food2',
        'Разобраться в меню пошире',
        'Лапша, кофе, яйца, мясо, рыба — уже можно выбирать',
      ),
      PlanStep.deck(
        'shopping2',
        'Спросить цену и купить',
        'Дорого и дёшево, юани и килограммы, примерить и купить',
      ),
      PlanStep.listening(
        5,
        'Понять 5 диалогов на слух',
        'Речь на скорости — то, чего не даёт чтение карточек',
      ),
      PlanStep.writing(
        5,
        'Написать 5 иероглифов по памяти',
        'Меню и цены — не только узнавать, но и уметь записать: с HSK 2 это часть экзамена',
      ),
    ],
  ),
  StudyPlan(
    id: 'getting_around',
    emoji: '🚌',
    titleRu: 'Дорога и город',
    descriptionRu:
        'Спросить дорогу, доехать до места и объяснить, где ты находишься.',
    outcomesRu: [
      'Спросить, где находится нужное место, и понять направление',
      'Сказать, куда ты едешь и на чём',
      'Объясниться на вокзале, в аэропорту и в гостинице',
      'Записать иероглифами пару слов о дороге и транспорте',
    ],
    samples: [
      PlanSample(
        '请问，火车站在哪儿？',
        'qǐngwèn, huǒchēzhàn zài nǎr?',
        'Простите, где вокзал?',
      ),
      PlanSample(
        '我坐公共汽车去学校。',
        'wǒ zuò gōnggòng qìchē qù xuéxiào.',
        'Я еду в школу на автобусе.',
      ),
      PlanSample('我们回家吧。', 'wǒmen huí jiā ba.', 'Пойдём домой.'),
    ],
    paceRu: '15 минут в день · 2 недели',
    stage: 2,
    track: PlanTrack.topic,
    steps: [
      PlanStep.deck(
        'places1',
        'Назвать места в городе',
        'Школа, магазин, больница — и как сказать «внутри», «наверху»',
      ),
      PlanStep.deck(
        'movement',
        'Сказать, куда идёшь',
        'Идти, бежать, войти, выйти, вернуться домой, поехать',
      ),
      PlanStep.deck(
        'transport2',
        'Разобраться с транспортом',
        'Автобус, поезд, велосипед, вокзал, аэропорт, гостиница',
      ),
      PlanStep.listening(
        5,
        'Понять 5 диалогов на слух',
        'Названия мест на слух путаются легче всего — тренируй их',
      ),
      PlanStep.writing(
        5,
        'Написать 5 иероглифов по памяти',
        'Транспорт и путь — HSK 2 уже спрашивает не узнавание слова, а его запись',
      ),
    ],
  ),
  StudyPlan(
    id: 'hsk1_complete',
    emoji: '📘',
    titleRu: 'Весь HSK 1',
    descriptionRu:
        'Закрыть базовый уровень целиком: все темы, устойчивая привычка заниматься.',
    outcomesRu: [
      'Собрать любую простую фразу: кто, что, когда и где',
      'Задать вопрос и понять ответ',
      'Говорить о времени: сегодня, завтра, утром, в три часа',
      'Дойти до 150 слов — это и есть весь словарь HSK 1',
    ],
    samples: [
      PlanSample('今天几号？', 'jīntiān jǐ hào?', 'Какое сегодня число?'),
      PlanSample('这本书是谁的？', 'zhè běn shū shì shéi de?', 'Чья это книга?'),
      PlanSample(
        '明天下午我在家看电影。',
        'míngtiān xiàwǔ wǒ zài jiā kàn diànyǐng.',
        'Завтра днём я дома смотрю кино.',
      ),
    ],
    paceRu: '15–20 минут в день · 4–6 недель',
    stage: 2,
    track: PlanTrack.hsk,
    steps: [
      PlanStep.deck(
        'time',
        'Говорить о времени и датах',
        'Дни, части суток, часы и минуты — когда именно что происходит',
      ),
      PlanStep.deck(
        'questions',
        'Задавать вопросы',
        'Что, кто, где, как — и частица 吗, превращающая фразу в вопрос',
      ),
      PlanStep.deck(
        'objects1',
        'Называть предметы вокруг',
        'Книга, стол, стул, компьютер, телевизор — быт под рукой',
      ),
      PlanStep.deck(
        'grammar1',
        'Собирать простые фразы',
        'Служебные слова: 的, 了, 和, счётные слова. Скелет китайской фразы',
      ),
      PlanStep.words(
        100,
        'Выучить 100 слов',
        'Не «увидеть», а вспомнить с интервальным повторением',
      ),
      PlanStep.streak(
        7,
        'Заниматься 7 дней подряд',
        'Неделя без пропусков — на этом уровне решает регулярность',
      ),
      PlanStep.listening(
        10,
        'Понять 10 диалогов на слух',
        'К концу HSK 1 простой диалог должен разбираться с первого раза',
      ),
    ],
  ),
  StudyPlan(
    id: 'hsk2_complete',
    emoji: '📗',
    titleRu: 'Весь HSK 2',
    descriptionRu:
        'Расширить словарь до бытовых тем и научиться понимать связную речь.',
    outcomesRu: [
      'Связывать мысли: «потому что», «поэтому», «но»',
      'Рассказать о самочувствии и сходить к врачу',
      'Говорить об учёбе: экзамен, вопрос, понял или нет',
      'Дойти до 300 слов — этого хватает на бытовой разговор',
    ],
    samples: [
      PlanSample(
        '因为我生病了，所以没去上班。',
        'yīnwèi wǒ shēngbìng le, suǒyǐ méi qù shàngbān.',
        'Я не пошёл на работу, потому что заболел.',
      ),
      PlanSample(
        '我觉得这个问题很难。',
        'wǒ juéde zhège wèntí hěn nán.',
        'По-моему, это трудный вопрос.',
      ),
      PlanSample(
        '他穿着一件红色的衣服。',
        'tā chuānzhe yí jiàn hóngsè de yīfu.',
        'На нём красная одежда.',
      ),
    ],
    paceRu: '20 минут в день · 6–8 недель',
    stage: 2,
    track: PlanTrack.hsk,
    steps: [
      PlanStep.deck(
        'colors',
        'Различать цвета',
        'Шесть цветов и само слово «цвет» — описания станут точнее',
      ),
      PlanStep.deck(
        'study2',
        'Говорить об учёбе',
        'Экзамен, вопрос, ответ, понимать, знать, считать нужным',
      ),
      PlanStep.deck(
        'body2',
        'Рассказать о самочувствии',
        'Тело, болезнь, лекарство, усталость — на случай врача',
      ),
      PlanStep.deck(
        'adverbs2',
        'Связывать мысли: «потому что», «поэтому»',
        'Союзы и наречия. Отсюда начинается речь длиннее одной фразы',
      ),
      PlanStep.deck(
        'daily2',
        'Обсуждать повседневное',
        'Время, день рождения, планы, начало и конец дел',
      ),
      PlanStep.listening(
        10,
        'Понять 10 диалогов на слух',
        'Как в HSK 1, но на бытовые темы уровня — учёба, самочувствие, планы',
      ),
      PlanStep.writing(
        10,
        'Написать 10 иероглифов по памяти',
        'С HSK 2 письмо входит в экзамен — мало узнавать иероглиф, нужно уметь его записать',
      ),
      PlanStep.words(
        250,
        'Выучить 250 слов',
        'Порог, за которым перестаёшь искать каждое второе слово',
      ),
      PlanStep.streak(
        14,
        'Заниматься 14 дней подряд',
        'Две недели подряд — привычка, которую уже трудно бросить',
      ),
    ],
  ),
  StudyPlan(
    id: 'hsk3_start',
    emoji: '📕',
    titleRu: 'Вход в HSK 3',
    descriptionRu:
        'Абстрактные темы: чувства, работа, общество — язык взрослых разговоров.',
    outcomesRu: [
      'Говорить о чувствах, а не только о фактах',
      'Обсуждать работу: встречи, решения, коллеги',
      'Рассказать о поездке — от визы до впечатлений',
      'Рассуждать об общем: привычки, отношения, среда',
    ],
    samples: [
      PlanSample(
        '我很高兴认识你。',
        'wǒ hěn gāoxìng rènshi nǐ.',
        'Очень рад знакомству.',
      ),
      PlanSample(
        '经理正在开会。',
        'jīnglǐ zhèngzài kāihuì.',
        'Начальник сейчас на встрече.',
      ),
      PlanSample(
        '秋天的风景最漂亮。',
        'qiūtiān de fēngjǐng zuì piàoliang.',
        'Осенью пейзаж самый красивый.',
      ),
    ],
    paceRu: '20 минут в день · 6–8 недель',
    stage: 3,
    track: PlanTrack.hsk,
    steps: [
      PlanStep.deck(
        'emotions3',
        'Говорить о чувствах',
        'Радость, тревога, страх, злость — то, чего нет в HSK 1–2',
      ),
      PlanStep.deck(
        'work3',
        'Обсуждать работу',
        'Профессии, офис, совещание, участие, решение',
      ),
      PlanStep.deck(
        'travel3',
        'Рассказать о поездке',
        'Паспорт, виза, багаж, карта, гид, пейзаж',
      ),
      PlanStep.deck(
        'nature3',
        'Описать погоду и сезоны',
        'Времена года, солнце и луна, погода за окном',
      ),
      PlanStep.deck(
        'society3',
        'Рассуждать об окружающем',
        'Вежливость, привычки, отношения, общество, среда',
      ),
      PlanStep.words(
        300,
        'Выучить 300 слов',
        'Столько нужно, чтобы читать простые тексты без словаря',
      ),
      PlanStep.listening(
        10,
        'Понять 10 диалогов на слух',
        'На HSK 3 темы взрослее и говорят быстрее — тренировка нужна серьёзнее, чем раньше',
      ),
      PlanStep.writing(
        10,
        'Написать 10 иероглифов по памяти',
        'Иероглифы HSK 3 сложнее по структуре — писать их по памяти отдельная задача',
      ),
      PlanStep.pronunciation(
        5,
        'Проверить произношение 5 раз',
        'С HSK 3 в экзамене появляется устная часть (HSKK) — стоит держать форму заранее',
      ),
    ],
  ),
];
