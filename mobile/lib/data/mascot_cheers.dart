/// A short, bilingual cheer line for the mascot's occasional unprompted
/// "hooray" — see [RewardService].
class MascotCheer {
  final String ru;
  final String en;

  const MascotCheer({required this.ru, required this.en});
}

class MascotCheers {
  MascotCheers._();

  static const all = <MascotCheer>[
    MascotCheer(ru: 'Ты сегодня в ударе! 🐼', en: "You're on a roll today! 🐼"),
    MascotCheer(ru: 'Панда гордится тобой!', en: 'The panda is proud of you!'),
    MascotCheer(
      ru: 'Ещё чуть-чуть — и ты заговоришь как местный.',
      en: "Keep this up and you'll sound like a local.",
    ),
    MascotCheer(
      ru: 'Красота! Продолжай в том же духе.',
      en: 'Nice! Keep it up.',
    ),
    MascotCheer(
      ru: 'Твой китайский растёт быстрее бамбука.',
      en: 'Your Chinese is growing faster than bamboo.',
    ),
    MascotCheer(
      ru: 'Панда машет лапой — отличная работа!',
      en: 'The panda gives you a paw-five!',
    ),
  ];
}
