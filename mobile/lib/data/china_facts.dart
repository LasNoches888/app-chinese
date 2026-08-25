/// A short, bilingual trivia snippet shown as an occasional between-lesson
/// surprise — see [RewardService].
class ChinaFact {
  final String ru;
  final String en;

  const ChinaFact({required this.ru, required this.en});
}

/// Small bank of language/culture/geography trivia, deliberately kept to
/// safe, uncontroversial ground (food, characters, history, wildlife) —
/// nothing here is meant to make a claim beyond "neat, verifiable fact".
class ChinaFacts {
  ChinaFacts._();

  static const all = <ChinaFact>[
    ChinaFact(
      ru: 'В путунхуа четыре тона (плюс нейтральный) — один и тот же слог «ma» значит «мама», «конопля», «лошадь» или «ругать» в зависимости от тона.',
      en: 'Mandarin has four tones plus a neutral one — the same syllable "ma" can mean mother, hemp, horse, or scold depending on pitch.',
    ),
    ChinaFact(
      ru: 'В китайском нет алфавита — каждый иероглиф сам по себе единица смысла, а для повседневного чтения хватает примерно 2500–3000 из десятков тысяч существующих.',
      en: "Chinese has no alphabet — each character is its own unit of meaning, and roughly 2,500–3,000 of the tens of thousands that exist cover most daily reading.",
    ),
    ChinaFact(
      ru: 'Великая Китайская стена — это не одна сплошная стена, а сеть укреплений, которые разные династии строили и достраивали на протяжении веков.',
      en: "The Great Wall isn't one continuous wall — it's a network of fortifications built and extended by different dynasties over centuries.",
    ),
    ChinaFact(
      ru: 'Дата китайского Нового года каждый год разная, потому что он считается по лунному календарю, а не по солнечному.',
      en: "Chinese New Year's date shifts every year because it follows the lunar calendar, not the solar one.",
    ),
    ChinaFact(
      ru: 'Чай появился в Китае — по легенде, император Шэнь-нун открыл его около 2737 года до н.э., когда листья случайно попали в его кипящую воду.',
      en: 'Tea originated in China — legend credits Emperor Shennong with discovering it around 2737 BCE, when leaves blew into his boiling water.',
    ),
    ChinaFact(
      ru: 'Число 4 (四, sì) созвучно со словом «смерть» (死, sǐ), поэтому во многих домах нет четвёртого этажа — суеверие, обратное удаче красного цвета.',
      en: 'The number 4 (四, sì) sounds like "death" (死, sǐ) in Mandarin, so many buildings skip a 4th floor — the mirror image of red being lucky.',
    ),
    ChinaFact(
      ru: 'Письменность не зависит от диалекта — говорящие на кантонском и на путунхуа могут читать одну и ту же газету, даже не понимая речи друг друга.',
      en: 'Chinese writing works across dialects — a Cantonese speaker and a Mandarin speaker can read the same newspaper even if they can\'t follow each other\'s speech.',
    ),
    ChinaFact(
      ru: 'Печенье с предсказаниями — вовсе не китайское изобретение: его придумали в Калифорнии в начале XX века.',
      en: "Fortune cookies aren't actually Chinese — they were invented in California in the early 1900s.",
    ),
    ChinaFact(
      ru: 'Пекин был столицей Китая почти всё последнее тысячелетие, но в разные эпохи этот статус носили ещё как минимум шесть других городов.',
      en: 'Beijing has held the title of capital for most of the last thousand years, but at least six other cities have held it at different points in history.',
    ),
    ChinaFact(
      ru: 'Палочкам для еды больше 3000 лет, и изначально их использовали для готовки, а не для еды.',
      en: 'Chopsticks are over 3,000 years old and were originally used for cooking, not eating.',
    ),
    ChinaFact(
      ru: 'Путунхуа — это не один язык, а стандартизированная «общая речь» поверх целой группы родственных диалектов и единой письменности.',
      en: 'Mandarin is less a single language than a standardized "common speech" layered over a group of related dialects sharing one writing system.',
    ),
    ChinaFact(
      ru: 'Панды едят до 14 часов в сутки — в основном бамбук, который настолько беден питательными веществами, что на отдых почти не остаётся сил.',
      en: 'Pandas spend up to 14 hours a day eating — mostly bamboo, which is so low in nutrients they can barely afford to rest.',
    ),
    ChinaFact(
      ru: 'Иероглиф «хорошо» (好) состоит из знаков «женщина» (女) и «ребёнок» (子), стоящих рядом.',
      en: 'The character for "good" (好) is built from "woman" (女) and "child" (子) placed side by side.',
    ),
    ChinaFact(
      ru: 'У Китая один часовой пояс на всю страну, хотя территория растянута примерно на ту же ширину, что и материковые США.',
      en: 'China runs on a single time zone for the whole country, even though it spans roughly the same width as the continental US.',
    ),
    ChinaFact(
      ru: 'Слово «кунг-фу» (功夫) вовсе не значит «боевые искусства» — оно обозначает мастерство, достигнутое упорным трудом и временем, в любом деле.',
      en: 'The word "kung fu" (功夫) doesn\'t actually mean martial arts — it refers to skill built through hard work and time, in any field.',
    ),
    ChinaFact(
      ru: 'Секрет производства шёлка китайцы хранили больше 2000 лет — разглашение технологии каралось смертью.',
      en: 'Silk-making was a guarded Chinese secret for over 2,000 years — revealing how it was made was punishable by death.',
    ),
    ChinaFact(
      ru: 'Маджонг, популярный сегодня во всём мире, возник в Китае в XIX веке и изначально был игрой императорского двора.',
      en: 'Mahjong, popular worldwide today, originated in 19th-century China and was first played at the imperial court.',
    ),
    ChinaFact(
      ru: 'По преданию, в пекинском Запретном городе 9999 комнат — на одну меньше мифических 10000, которые полагались только небесам.',
      en: "Beijing's Forbidden City has 9,999 rooms by tradition — one short of the mythical 10,000 that only heaven was allowed to have.",
    ),
    ChinaFact(
      ru: 'Китайские иероглифы когда-то использовались в Корее, Японии и Вьетнаме — поэтому в этих языках до сих пор много общих корней.',
      en: 'Chinese characters were once used across Korea, Japan, and Vietnam, which is why those languages still share so many word roots.',
    ),
    ChinaFact(
      ru: 'Чёрно-белый окрас панды может работать как маскировка и в снегу, и в тени — а заодно как предупреждающий знак для хищников, вроде окраса скунса.',
      en: "A panda's black-and-white pattern may double as camouflage in both snow and shade — and as a predator warning, similar to a skunk's.",
    ),
  ];
}
