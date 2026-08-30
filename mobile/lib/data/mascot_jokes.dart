/// A lighthearted quip the 3D companion pops up with after a good streak
/// mid-lesson — distinct from [MascotCheers], which is sincere post-lesson
/// praise. These are meant to actually be jokes, even loose ones.
class MascotJoke {
  final String ru;
  final String en;

  const MascotJoke({required this.ru, required this.en});
}

class MascotJokes {
  MascotJokes._();

  static const all = <MascotJoke>[
    MascotJoke(
      ru: 'Знаешь, почему 8 (八) любят в Китае? Потому что она никогда не звучит как беда!',
      en: "Why is 8 (八) everyone's favorite number in China? It never sounds like trouble.",
    ),
    MascotJoke(
      ru: 'Я один раз перепутал тон — и вместо "мама" сказал "лошадь". С тех пор мама зовёт себя лошадью.',
      en: 'I once mixed up a tone and called my mom a horse instead. She still brings it up.',
    ),
    MascotJoke(
      ru: 'Бамбук — это просто моя версия энергетика. Ты — молодец, это тоже энергетик, только словесный.',
      en: "Bamboo is basically my energy drink. You're on one too — the word kind.",
    ),
    MascotJoke(
      ru: 'Если бы иероглифы были едой, ты бы сейчас доедал десерт.',
      en: "If hanzi were food, you'd be on dessert by now.",
    ),
    MascotJoke(
      ru: 'Я почти начал понимать китайский. Почти. Хорошо, что есть ты.',
      en: "I almost understand Chinese now. Almost. Good thing you're here.",
    ),
    MascotJoke(
      ru: 'Ещё немного — и тебе не будет нужен я, только словарь и уверенность.',
      en: "Keep this up and you won't need me — just a dictionary and nerve.",
    ),
  ];
}
