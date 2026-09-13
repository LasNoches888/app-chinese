import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A phrase or word shown for a dialect.
///
/// [reading] is a romanization the app can vouch for — Pinyin for Mandarin,
/// Jyutping for Cantonese, POJ for Southern Min. For dialects with no
/// standardized, widely-agreed romanization the app can print with
/// confidence (Wu, Hakka, Xiang, Gan), it's left null rather than guessing:
/// the hanzi and translation are still shown, just without a made-up
/// phonetic spelling attached to them.
class DialectExample {
  final String hanzi;
  final String? reading;
  final String ru;

  const DialectExample(this.hanzi, this.ru, {this.reading});
}

/// One line of the dialect's short scripted practice dialogue.
enum PracticeSpeaker { mascot, learner }

class PracticeLine {
  final PracticeSpeaker speaker;
  final String hanzi;
  final String? reading;
  final String ru;

  const PracticeLine(this.speaker, this.hanzi, this.ru, {this.reading});
}

/// One of China's major dialect (topolect) groups.
///
/// This is deliberately *not* a course that teaches these dialects — the
/// app only has real spoken-audio and exercise infrastructure for
/// Mandarin (see [SpeakButton]/`speech_service.dart`, hard-wired to
/// zh-CN). What this data buys is honest cultural/linguistic awareness:
/// what each group sounds like in broad strokes, where it's spoken, and a
/// handful of real, well-documented example words — with romanization
/// only where a standard system exists and can be given correctly
/// (Pinyin for Mandarin, Jyutping for Cantonese, POJ for Southern Min).
/// The other groups get hanzi + translation + real facts, not invented
/// phonetics dressed up as authoritative.
class DialectInfo {
  final String id;
  final String nameRu;
  final String nativeName;
  final String romanization;
  final String regionRu;
  final Color color;

  /// True only for Mandarin — the one dialect the device's TTS engine can
  /// actually speak (see `speech_service.dart`'s hard-coded `zh-CN`
  /// locale). Showing a speaker icon that plays the wrong dialect's audio,
  /// or none at all, is worse than not showing one.
  final bool hasAudio;

  final String descriptionRu;
  final List<String> featuresRu;
  final List<DialectExample> examples;

  final String cultureTitleRu;
  final String cultureBodyRu;
  final List<DialectExample> cultureVocab;

  /// A short scripted read-along exchange. Null for every dialect except
  /// Mandarin — a "practice conversation" only means something where the
  /// app can vouch for both the words and the pronunciation.
  final List<PracticeLine>? dialogue;

  const DialectInfo({
    required this.id,
    required this.nameRu,
    required this.nativeName,
    required this.romanization,
    required this.regionRu,
    required this.color,
    required this.hasAudio,
    required this.descriptionRu,
    required this.featuresRu,
    required this.examples,
    required this.cultureTitleRu,
    required this.cultureBodyRu,
    required this.cultureVocab,
    this.dialogue,
  });
}

/// The per-group `color`s here are the app's blue-family set, because the
/// app runs styles #1/#2 of the brand sheet. The website runs style #6
/// (warm paper), where those hues fight the background, so
/// `website/js/dialects-data.js` carries an earth-toned set instead. The
/// two lists differing is intentional — neither is a stale copy of the
/// other, and everything else about a group (names, examples, which ones
/// honestly have audio) is identical on both sides.
const List<DialectInfo> kDialects = [
  DialectInfo(
    id: 'mandarin',
    nameRu: 'Мандарин',
    nativeName: '官话',
    romanization: 'Guānhuà',
    regionRu: 'Север и юго-запад Китая',
    color: AppColors.blue,
    hasAudio: true,
    descriptionRu:
        'Самый распространённый диалект Китая — основа современного '
        'путунхуа, официального языка страны.',
    featuresRu: [
      'Основа путунхуа — стандартного языка, который преподают в школах',
      'Сравнительно простая тональная система: всего 4 тона',
      'Понимают практически на всей территории Китая',
    ],
    examples: [
      DialectExample('你好', 'Привет', reading: 'nǐ hǎo'),
      DialectExample('谢谢', 'Спасибо', reading: 'xièxie'),
      DialectExample('再见', 'До свидания', reading: 'zàijiàn'),
    ],
    cultureTitleRu: 'Путунхуа как общий язык',
    cultureBodyRu:
        'Путунхуа — стандартизированная форма мандарина на основе пекинского '
        'произношения — с 1950-х годов преподаётся в школах и звучит на ТВ '
        'по всей стране. Именно благодаря ему носители самых разных '
        'диалектов — от кантонского до миньского — вообще могут понимать '
        'друг друга: сами диалекты между собой зачастую взаимно '
        'непонятны, а письменность и путунхуа остаются общими.',
    cultureVocab: [
      DialectExample('普通话', 'путунхуа, стандартный китайский'),
      DialectExample('汉语', 'китайский язык'),
    ],
    dialogue: [
      PracticeLine(
        PracticeSpeaker.mascot,
        '你好！你是学生吗？',
        'Привет! Ты студент?',
        reading: 'Nǐ hǎo! Nǐ shì xuéshēng ma?',
      ),
      PracticeLine(
        PracticeSpeaker.learner,
        '是，我是学生。',
        'Да, я студент.',
        reading: 'Shì, wǒ shì xuéshēng.',
      ),
      PracticeLine(
        PracticeSpeaker.mascot,
        '很高兴认识你！你喜欢喝茶吗？',
        'Приятно познакомиться! Ты любишь пить чай?',
        reading: 'Hěn gāoxìng rènshi nǐ! Nǐ xǐhuan hē chá ma?',
      ),
      PracticeLine(
        PracticeSpeaker.learner,
        '喜欢，我喜欢喝茶。',
        'Да, я люблю пить чай.',
        reading: 'Xǐhuan, wǒ xǐhuan hē chá.',
      ),
      PracticeLine(PracticeSpeaker.mascot, '太好了！', 'Отлично!', reading: 'Tài hǎo le!'),
    ],
  ),
  DialectInfo(
    id: 'wu',
    nameRu: 'У (шанхайский)',
    nativeName: '吴语',
    romanization: 'Wúyǔ',
    regionRu: 'Шанхай, юг Цзянсу, Чжэцзян',
    color: AppColors.green,
    hasAudio: false,
    descriptionRu:
        'Один из самых своеобразных диалектов юго-востока Китая — на нём '
        'говорят в Шанхае и соседних регионах.',
    featuresRu: [
      'Фонетика сильно отличается от путунхуа',
      'Сохраняет звонкие согласные, утраченные в мандарине',
      'У Шанхая, Сучжоу и Нинбо — разные, не всегда взаимопонятные варианты',
    ],
    examples: [
      DialectExample('阿拉', 'я / мы (в шанхайском — не 我/我们)', reading: 'ala'),
    ],
    cultureTitleRu: 'Шанхайская речь и 阿拉',
    cultureBodyRu:
        'Самая известная черта шанхайского — местоимение 阿拉 (ala) вместо '
        'путунхуашных 我/我们. У — один из старейших диалектных ареалов, '
        'исторически связанный с культурой региона Цзяннань (опера, '
        'литература). Сегодня в Шанхае дети растут в основном на путунхуа '
        'в школе, и живая шанхайская речь постепенно смешивается с ним.',
    cultureVocab: [
      DialectExample('阿拉', 'я / мы (шанхайский)', reading: 'ala'),
      DialectExample('上海', 'Шанхай'),
    ],
  ),
  DialectInfo(
    id: 'yue',
    nameRu: 'Юэ (кантонский)',
    nativeName: '粤语',
    romanization: 'Yuèyǔ',
    regionRu: 'Гуандун, Гуанси, Гонконг, Макао',
    color: AppColors.orange,
    hasAudio: false,
    descriptionRu:
        'Яркий, мелодичный диалект с собственной лексикой и грамматикой — '
        'основной язык Гонконга и Макао.',
    featuresRu: [
      'От 6 до 9 тонов в зависимости от анализа — заметно больше, чем в '
          'путунхуа',
      'Своя лексика и грамматика, не сводимая к путунхуа один в один',
      'Собственная система романизации — джютпин (Jyutping)',
    ],
    examples: [
      DialectExample('你好', 'Привет', reading: 'nei5 hou2'),
      DialectExample('唔該', 'Извините / спасибо (за услугу)', reading: 'm4 goi1'),
      DialectExample('多謝', 'Спасибо (за подарок)', reading: 'do1 ze6'),
    ],
    cultureTitleRu: 'Кантонский вне материкового Китая',
    cultureBodyRu:
        'Кантонский — основной язык Гонконга и Макао и язык кантопопа и '
        'гонконгского кино, благодаря которым он известен по всему миру. '
        'Из-за исторической эмиграции из провинции Гуандун именно '
        'кантонский, а не путунхуа, долгое время был самым узнаваемым '
        'китайским языком в китайских кварталах Европы и Америки.',
    cultureVocab: [
      DialectExample('唔該', 'извините / спасибо', reading: 'm4 goi1'),
      DialectExample('冇', 'нет, не иметь — своего аналога в путунхуа нет', reading: 'mou5'),
    ],
  ),
  DialectInfo(
    id: 'min',
    nameRu: 'Мин',
    nativeName: '闽语',
    romanization: 'Mǐnyǔ',
    regionRu: 'Фуцзянь, Тайвань, Хайнань',
    color: AppColors.purple,
    hasAudio: false,
    descriptionRu:
        'Одна из древнейших ветвей китайских диалектов — включает южноминьский '
        '(тайваньский) и ряд других, слабо понятных друг другу вариантов.',
    featuresRu: [
      'Рано отделился от общего ствола — сохраняет очень архаичные черты',
      'Внутри самой группы Мин — несколько взаимно непонятных вариантов',
      'Южноминьский широко распространён на Тайване и среди китайской '
          'диаспоры Юго-Восточной Азии',
    ],
    examples: [
      DialectExample(
        '食飽未',
        'Ты поел? — так в южноминьском (хоккиен) традиционно здороваются, '
            'а не «привет»',
        reading: 'chia̍h pá--buē?',
      ),
      DialectExample('你好', 'Привет (современный, общекитайский вариант)', reading: 'lí hó'),
    ],
    cultureTitleRu: '«Ты поел?» вместо «привет»',
    cultureBodyRu:
        'Традиционное южноминьское приветствие — не аналог «привет», а '
        'вопрос 食飽未 «ты уже поел?», отражающий место еды в местной '
        'культуре. Южноминьский (хоккиен) — основа тайваньской разговорной '
        'речи и один из самых распространённых китайских языков среди '
        'диаспоры в Юго-Восточной Азии.',
    cultureVocab: [
      DialectExample('食', 'есть, кушать (минь/тайваньский — не 吃)', reading: 'chia̍h'),
      DialectExample('你好', 'привет', reading: 'lí hó'),
    ],
  ),
  DialectInfo(
    id: 'hakka',
    nameRu: 'Хакка',
    nativeName: '客家话',
    romanization: 'Kèjiāhuà',
    regionRu: 'Разрозненно на стыке Фуцзянь, Гуандун, Цзянси',
    color: AppColors.amber,
    hasAudio: false,
    descriptionRu:
        'Диалект не одного региона, а рассеянной по югу Китая группы хакка '
        '(«гостевых семей») — потомков переселенцев с севера.',
    featuresRu: [
      'Название 客家 буквально значит «гостевые семьи»',
      'Говорящие живут анклавами в разных провинциях, а не одним ареалом',
      'Хакка знамениты круглыми глинобитными домами тулоу в Фуцзяни',
    ],
    examples: [
      DialectExample('涯', 'я (на хакка — не 我)', reading: 'ngai'),
    ],
    cultureTitleRu: 'Народ хакка и дома тулоу',
    cultureBodyRu:
        'Хакка переселялись с севера Китая на юг несколькими волнами за '
        'последнюю тысячу лет, поэтому живут не сплошным регионом, а '
        'анклавами на стыке Фуцзяни, Гуандуна и Цзянси, а также на Тайване '
        'и среди диаспоры. Самый узнаваемый символ культуры хакка — круглые '
        'многоэтажные глинобитные дома тулоу, где жил целый клан.',
    cultureVocab: [
      DialectExample('客家', 'хакка, буквально «гостевые семьи»'),
      DialectExample('涯', 'я (хакка)', reading: 'ngai'),
    ],
  ),
  DialectInfo(
    id: 'xiang',
    nameRu: 'Сян',
    nativeName: '湘语',
    romanization: 'Xiāngyǔ',
    regionRu: 'Хунань',
    color: AppColors.greenDark,
    hasAudio: false,
    descriptionRu:
        'Диалект провинции Хунань, исторически связанный с языком древнего '
        'царства Чу.',
    featuresRu: [
      'Делится на «новый сян» (ближе к путунхуа) и «старый сян» '
          '(более консервативный)',
      'Письменная форма — как в путунхуа, произношение своё и различается '
          'по уездам',
      'Родной диалект Мао Цзэдуна, который так и не перешёл на образцовое '
          'произношение путунхуа',
    ],
    examples: [
      DialectExample(
        '谢谢',
        'спасибо (письменная форма как в путунхуа; сянское произношение '
            'своё)',
      ),
    ],
    cultureTitleRu: 'Хунаньский акцент Мао Цзэдуна',
    cultureBodyRu:
        'Сян — один из наименее известных за пределами Китая диалектов, '
        'хотя на нём говорят десятки миллионов человек в Хунани. Известный '
        'факт: Мао Цзэдун, уроженец Хунани, всю жизнь говорил на путунхуа '
        'с заметным сянским акцентом, даже выступая перед всей страной.',
    cultureVocab: [DialectExample('湖南', 'провинция Хунань')],
  ),
  DialectInfo(
    id: 'gan',
    nameRu: 'Гань',
    nativeName: '赣语',
    romanization: 'Gànyǔ',
    regionRu: 'Цзянси',
    color: AppColors.greyDark,
    hasAudio: false,
    descriptionRu:
        'Диалект провинции Цзянси — один из наименее изученных крупных '
        'диалектов Китая.',
    featuresRu: [
      'Некоторые лингвисты считают гань исторически близким к хакка',
      'Письменная форма — как в путунхуа, произношение своё',
      'Цзянси — исторический центр фарфорового производства (Цзиндэчжэнь)',
    ],
    examples: [
      DialectExample(
        '谢谢',
        'спасибо (письменная форма как в путунхуа; ганьское произношение '
            'своё)',
      ),
    ],
    cultureTitleRu: 'Цзянси и фарфор',
    cultureBodyRu:
        'Гань изучен заметно меньше, чем мандарин, у или кантонский, а его '
        'границы с соседним хакка — предмет споров лингвистов. Сама '
        'провинция Цзянси на протяжении веков была центром китайского '
        'фарфорового производства: город Цзиндэчжэнь называют «фарфоровой '
        'столицей» Китая.',
    cultureVocab: [DialectExample('江西', 'провинция Цзянси')],
  ),
];

/// One row of the pronunciation-comparison screen: a word shown with a
/// real, standard romanization in every dialect the app can vouch for.
/// Kept to Mandarin/Cantonese/Southern Min — the only three with a
/// romanization system precise and well-documented enough to print with
/// confidence at the single-character level.
class DialectCompareEntry {
  final String hanziMandarin;
  final String pinyin;
  final String hanziYue;
  final String jyutping;
  final String hanziMin;
  final String poj;
  final String ru;
  final String tipRu;

  const DialectCompareEntry({
    required this.hanziMandarin,
    required this.pinyin,
    required this.hanziYue,
    required this.jyutping,
    required this.hanziMin,
    required this.poj,
    required this.ru,
    required this.tipRu,
  });
}

const List<DialectCompareEntry> kDialectCompareEntries = [
  DialectCompareEntry(
    hanziMandarin: '你',
    pinyin: 'nǐ',
    hanziYue: '你',
    jyutping: 'nei5',
    hanziMin: '你',
    poj: 'lí',
    ru: 'ты, вы',
    tipRu:
        'Один и тот же иероглиф — три совсем разных чтения: кантонский и '
        'миньский сохранили финали, которых в путунхуа давно нет.',
  ),
  DialectCompareEntry(
    hanziMandarin: '好',
    pinyin: 'hǎo',
    hanziYue: '好',
    jyutping: 'hou2',
    hanziMin: '好',
    poj: 'hó',
    ru: 'хороший',
    tipRu:
        'Тон путунхуа (3-й, «ныряющий») здесь не соответствует напрямую ни '
        'кантонскому, ни миньскому тону — тоновые системы у диалектов '
        'разные, а не просто по-другому пронумерованные.',
  ),
  DialectCompareEntry(
    hanziMandarin: '吃',
    pinyin: 'chī',
    hanziYue: '食',
    jyutping: 'sik6',
    hanziMin: '食',
    poj: 'chia̍h',
    ru: 'есть, кушать',
    tipRu:
        'Здесь различается не только звучание, но и сам иероглиф: '
        'кантонский и миньский сохранили древнее 食, которое путунхуа почти '
        'вытеснил словом 吃.',
  ),
];
