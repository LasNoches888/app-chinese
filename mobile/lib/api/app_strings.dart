enum AppLocale { ru, en }

enum CardFrontSide { hanzi, translation }

class Strings {
  static const Map<String, Map<AppLocale, String>> _values = {
    'flashcards': {AppLocale.ru: 'Карточки', AppLocale.en: 'Flashcards'},
    'chat': {AppLocale.ru: 'Чат', AppLocale.en: 'Chat'},
    'settings': {AppLocale.ru: 'Настройки', AppLocale.en: 'Settings'},
    'noCardsDue': {
      AppLocale.ru: 'Нет карточек на сегодня. 太好了! 🎉',
      AppLocale.en: 'No cards due. 太好了! 🎉',
    },
    'tapToReveal': {
      AppLocale.ru: 'Нажмите, чтобы перевернуть',
      AppLocale.en: 'Tap to reveal',
    },
    'swipeHint': {
      AppLocale.ru: 'Смахните: влево — не помню, вправо — помню',
      AppLocale.en: 'Swipe: left = forgot, right = remembered',
    },
    'due': {AppLocale.ru: 'осталось', AppLocale.en: 'due'},
    'again': {AppLocale.ru: 'Снова', AppLocale.en: 'Again'},
    'hard': {AppLocale.ru: 'Трудно', AppLocale.en: 'Hard'},
    'good': {AppLocale.ru: 'Хорошо', AppLocale.en: 'Good'},
    'easy': {AppLocale.ru: 'Легко', AppLocale.en: 'Easy'},
    'addWord': {AppLocale.ru: 'Добавить слово', AppLocale.en: 'Add word'},
    'word': {AppLocale.ru: 'Слово (汉字)', AppLocale.en: 'Word (汉字)'},
    'pinyin': {AppLocale.ru: 'Пиньинь', AppLocale.en: 'Pinyin'},
    'translation': {AppLocale.ru: 'Перевод', AppLocale.en: 'Translation'},
    'cancel': {AppLocale.ru: 'Отмена', AppLocale.en: 'Cancel'},
    'add': {AppLocale.ru: 'Добавить', AppLocale.en: 'Add'},
    'backendUrl': {AppLocale.ru: 'Адрес сервера', AppLocale.en: 'Backend base URL'},
    'save': {AppLocale.ru: 'Сохранить', AppLocale.en: 'Save'},
    'saved': {AppLocale.ru: 'Сохранено', AppLocale.en: 'Saved'},
    'language': {AppLocale.ru: 'Язык интерфейса', AppLocale.en: 'Interface language'},
    'cardFrontSideLabel': {
      AppLocale.ru: 'Что показывать первым',
      AppLocale.en: 'Show first',
    },
    'cardFrontHanzi': {AppLocale.ru: 'Иероглиф', AppLocale.en: 'Hanzi'},
    'cardFrontTranslation': {AppLocale.ru: 'Перевод', AppLocale.en: 'Translation'},
    'chatHint': {AppLocale.ru: 'Пишите по-китайски...', AppLocale.en: 'Type in Chinese...'},
    'chatTitle': {AppLocale.ru: 'Чат с Xiao Qiao', AppLocale.en: 'Chat with Xiao Qiao'},
    'tryRecast': {AppLocale.ru: 'Лучше сказать', AppLocale.en: 'Try'},
    'error': {AppLocale.ru: 'Ошибка', AppLocale.en: 'Error'},
    'progress': {AppLocale.ru: 'Прогресс', AppLocale.en: 'Progress'},
    'totalWords': {AppLocale.ru: 'Всего слов', AppLocale.en: 'Total words'},
    'learnedWords': {AppLocale.ru: 'Выучено', AppLocale.en: 'Learned'},
    'weakWords': {AppLocale.ru: 'Слабые слова', AppLocale.en: 'Weak words'},
    'reviewsToday': {AppLocale.ru: 'Повторений сегодня', AppLocale.en: 'Reviews today'},
    'streakDays': {AppLocale.ru: 'Серия дней', AppLocale.en: 'Streak'},
    'accuracy': {AppLocale.ru: 'Точность', AppLocale.en: 'Accuracy'},
    'themes': {AppLocale.ru: 'Темы', AppLocale.en: 'Themes'},
    'addDeck': {AppLocale.ru: 'Добавить', AppLocale.en: 'Add'},
    'deckAdded': {AppLocale.ru: 'Добавлено слов', AppLocale.en: 'Words added'},
    'close': {AppLocale.ru: 'Закрыть', AppLocale.en: 'Close'},
    'dailyReminder': {AppLocale.ru: 'Ежедневное напоминание', AppLocale.en: 'Daily reminder'},
    'reminderTime': {AppLocale.ru: 'Время напоминания', AppLocale.en: 'Reminder time'},
    'reminderBody': {
      AppLocale.ru: 'Не теряй серию — пора повторить слова!',
      AppLocale.en: "Don't lose your streak — time to review!",
    },
    'wordsUnit': {AppLocale.ru: 'слов', AppLocale.en: 'words'},
  };

  static String of(AppLocale locale, String key) => _values[key]?[locale] ?? key;
}
