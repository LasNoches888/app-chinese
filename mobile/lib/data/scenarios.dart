/// A guided roleplay setup for practice chat: the tutor plays a fixed role
/// (waiter, stranger on the street, ...) and is nudged to stick to one
/// topic's vocabulary, instead of the open-ended tutor persona used by the
/// main chat.
class ChatScenario {
  final String id;
  final String emoji;
  final String titleRu;
  final String descriptionRu;
  final String role;
  final String topicHintRu;
  final String openingLineZh;

  const ChatScenario({
    required this.id,
    required this.emoji,
    required this.titleRu,
    required this.descriptionRu,
    required this.role,
    required this.topicHintRu,
    required this.openingLineZh,
  });
}

const kChatScenarios = <ChatScenario>[
  ChatScenario(
    id: 'cafe',
    emoji: '☕',
    titleRu: 'В кафе',
    descriptionRu: 'Закажи себе чай, кофе или что-нибудь поесть',
    role: 'официант в небольшом кафе',
    topicHintRu: 'еда и напитки (чай, кофе, вода, яблоко, лапша...)',
    openingLineZh: '你好！你想喝什么？',
  ),
  ChatScenario(
    id: 'meet',
    emoji: '🤝',
    titleRu: 'Знакомство',
    descriptionRu: 'Познакомься с новым человеком — как зовут, кто он',
    role: 'новый знакомый на встрече студентов',
    topicHintRu: 'знакомство (имя, кто ты, студент/учитель)',
    openingLineZh: '你好！你叫什么名字？',
  ),
  ChatScenario(
    id: 'family',
    emoji: '👨‍👩‍👧',
    titleRu: 'Рассказ о семье',
    descriptionRu: 'Расскажи, кто есть в твоей семье',
    role: 'друг, который спрашивает про твою семью',
    topicHintRu: 'семья (папа, мама, брат, сестра)',
    openingLineZh: '你家有几个人？',
  ),
  ChatScenario(
    id: 'directions',
    emoji: '🚶',
    titleRu: 'Дорога домой',
    descriptionRu: 'Расскажи, куда и как ты идёшь',
    role: 'прохожий, который встретил тебя на улице',
    topicHintRu: 'движение (идти, ехать, домой, на работу)',
    openingLineZh: '你去哪儿？',
  ),
];
