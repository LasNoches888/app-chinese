enum AppLocale { ru, en }

enum CardFrontSide { hanzi, translation }

class Strings {
  static const Map<String, Map<AppLocale, String>> _values = {
    // Nav
    'lessons': {AppLocale.ru: 'Уроки', AppLocale.en: 'Lessons'},
    'review': {AppLocale.ru: 'Повторить', AppLocale.en: 'Review'},
    'progress': {AppLocale.ru: 'Прогресс', AppLocale.en: 'Progress'},
    'chat': {AppLocale.ru: 'Чат', AppLocale.en: 'Chat'},
    'settings': {AppLocale.ru: 'Настройки', AppLocale.en: 'Settings'},

    // Lessons / deck map
    'deckLocked': {AppLocale.ru: 'Заблокировано', AppLocale.en: 'Locked'},
    'deckCompleted': {AppLocale.ru: 'Пройдено', AppLocale.en: 'Completed'},
    'noReviewDue': {
      AppLocale.ru: 'Нечего повторять — все слова свежие! 🎉',
      AppLocale.en: 'Nothing to review — everything is fresh! 🎉',
    },

    // Exercise UI
    'tapToReveal': {
      AppLocale.ru: 'Нажмите, чтобы перевернуть',
      AppLocale.en: 'Tap to reveal'
    },
    'iKnowIt': {AppLocale.ru: 'Знаю', AppLocale.en: 'I know it'},
    'iDontKnow': {AppLocale.ru: 'Не знаю', AppLocale.en: "I don't know"},
    'chooseTranslationPrompt': {
      AppLocale.ru: 'Выберите перевод',
      AppLocale.en: 'Choose the translation'
    },
    'chooseHanziPrompt': {
      AppLocale.ru: 'Выберите иероглиф',
      AppLocale.en: 'Choose the character'
    },
    'buildSentencePrompt': {
      AppLocale.ru: 'Соберите предложение',
      AppLocale.en: 'Build the sentence'
    },
    'typePinyinPrompt': {
      AppLocale.ru: 'Введите пиньинь',
      AppLocale.en: 'Type the pinyin'
    },
    'typePinyinHint': {
      AppLocale.ru: 'например: ni3 hao3 или ni hao',
      AppLocale.en: 'e.g. ni3 hao3 or ni hao',
    },
    'check': {AppLocale.ru: 'Проверить', AppLocale.en: 'Check'},
    'writeHanziPrompt': {
      AppLocale.ru: 'Напишите иероглиф',
      AppLocale.en: 'Write the character'
    },
    'hint': {AppLocale.ru: 'Подсказка', AppLocale.en: 'Hint'},
    'correctAnswerIs': {
      AppLocale.ru: 'Правильный ответ',
      AppLocale.en: 'Correct answer'
    },
    'due': {AppLocale.ru: 'осталось', AppLocale.en: 'due'},

    // Hearts / results
    'outOfHearts': {
      AppLocale.ru: 'Жизни закончились!',
      AppLocale.en: 'Out of hearts!',
    },
    'outOfHeartsBody': {
      AppLocale.ru:
          'Подождите восстановления или повторите урок без ошибок в следующий раз.',
      AppLocale.en:
          'Wait for hearts to refill, or come back and try a flawless run.',
    },
    'nextHeartIn': {
      AppLocale.ru: 'Следующее сердце через',
      AppLocale.en: 'Next heart in'
    },
    'backToLessons': {
      AppLocale.ru: 'К урокам',
      AppLocale.en: 'Back to lessons'
    },
    'lessonComplete': {
      AppLocale.ru: 'Урок завершён!',
      AppLocale.en: 'Lesson complete!'
    },
    'perfectLesson': {
      AppLocale.ru: 'Идеальный урок!',
      AppLocale.en: 'Perfect lesson!'
    },
    'reviewComplete': {
      AppLocale.ru: 'Повторение завершено!',
      AppLocale.en: 'Review complete!'
    },
    'mistakesToReview': {
      AppLocale.ru: 'Слова с ошибками',
      AppLocale.en: 'Words to review'
    },
    'continueLabel': {AppLocale.ru: 'Продолжить', AppLocale.en: 'Continue'},
    'newAchievement': {
      AppLocale.ru: 'Новое достижение!',
      AppLocale.en: 'New achievement!'
    },

    // Progress screen
    'level': {AppLocale.ru: 'Уровень', AppLocale.en: 'Level'},
    'totalXp': {AppLocale.ru: 'Всего XP', AppLocale.en: 'Total XP'},
    'dailyGoal': {AppLocale.ru: 'Дневная цель', AppLocale.en: 'Daily goal'},
    'streakDays': {
      AppLocale.ru: 'Текущая серия',
      AppLocale.en: 'Current streak'
    },
    'longestStreak': {
      AppLocale.ru: 'Рекордная серия',
      AppLocale.en: 'Longest streak'
    },
    'wordsLearned': {
      AppLocale.ru: 'Слов выучено',
      AppLocale.en: 'Words learned'
    },
    'accuracyAllTime': {
      AppLocale.ru: 'Точность (всё время)',
      AppLocale.en: 'Accuracy (all time)'
    },
    'accuracy7d': {
      AppLocale.ru: 'Точность (7 дней)',
      AppLocale.en: 'Accuracy (7 days)'
    },
    'achievements': {AppLocale.ru: 'Достижения', AppLocale.en: 'Achievements'},
    'streakCalendar': {
      AppLocale.ru: 'Календарь серии (30 дней)',
      AppLocale.en: 'Streak calendar (30 days)'
    },

    // Achievements
    'achStreak3': {AppLocale.ru: '3 дня подряд', AppLocale.en: '3-day streak'},
    'achStreak3Desc': {
      AppLocale.ru: 'Занимайтесь 3 дня подряд',
      AppLocale.en: 'Study 3 days in a row'
    },
    'achStreak7': {AppLocale.ru: '7 дней подряд', AppLocale.en: '7-day streak'},
    'achStreak7Desc': {
      AppLocale.ru: 'Занимайтесь 7 дней подряд',
      AppLocale.en: 'Study 7 days in a row'
    },
    'achStreak30': {
      AppLocale.ru: '30 дней подряд',
      AppLocale.en: '30-day streak'
    },
    'achStreak30Desc': {
      AppLocale.ru: 'Занимайтесь 30 дней подряд',
      AppLocale.en: 'Study 30 days in a row'
    },
    'achWords50': {AppLocale.ru: '50 слов', AppLocale.en: '50 words'},
    'achWords50Desc': {
      AppLocale.ru: 'Выучите 50 слов',
      AppLocale.en: 'Learn 50 words'
    },
    'achWords100': {AppLocale.ru: '100 слов', AppLocale.en: '100 words'},
    'achWords100Desc': {
      AppLocale.ru: 'Выучите 100 слов',
      AppLocale.en: 'Learn 100 words'
    },
    'achWords300': {AppLocale.ru: '300 слов', AppLocale.en: '300 words'},
    'achWords300Desc': {
      AppLocale.ru: 'Выучите 300 слов',
      AppLocale.en: 'Learn 300 words'
    },
    'achPerfectLesson': {
      AppLocale.ru: 'Идеальный урок',
      AppLocale.en: 'Perfect lesson'
    },
    'achPerfectLessonDesc': {
      AppLocale.ru: 'Пройдите урок без единой ошибки',
      AppLocale.en: 'Finish a lesson with zero mistakes',
    },
    'achHsk1': {AppLocale.ru: 'HSK1 пройден', AppLocale.en: 'HSK1 complete'},
    'achHsk1Desc': {
      AppLocale.ru: 'Выучите все слова уровня HSK1',
      AppLocale.en: 'Learn every HSK1 word',
    },

    // Chat
    'chatHint': {
      AppLocale.ru: 'Пишите по-китайски...',
      AppLocale.en: 'Type in Chinese...'
    },
    'chatTitle': {
      AppLocale.ru: 'Чат с Xiao Qiao',
      AppLocale.en: 'Chat with Xiao Qiao'
    },
    'tryRecast': {AppLocale.ru: 'Лучше сказать', AppLocale.en: 'Try'},
    'offlineBanner': {
      AppLocale.ru: 'Нет подключения к интернету — чат недоступен офлайн',
      AppLocale.en: 'No internet connection — chat is unavailable offline',
    },
    'online': {AppLocale.ru: 'В сети', AppLocale.en: 'Online'},
    'offline': {AppLocale.ru: 'Не в сети', AppLocale.en: 'Offline'},
    'chatSource': {
      AppLocale.ru: 'Источник ответов чата',
      AppLocale.en: 'Chat source'
    },
    'chatSourceServer': {AppLocale.ru: 'Профессор', AppLocale.en: 'Professor'},
    'chatSourceServerDesc': {
      AppLocale.ru: 'Большая модель на сервере — нужен интернет',
      AppLocale.en: 'Big model on the server — needs internet',
    },
    'chatSourceLocal': {
      AppLocale.ru: 'Друг поблизости',
      AppLocale.en: 'Nearby friend'
    },
    'chatSourceLocalDesc': {
      AppLocale.ru: 'Живёт у вас в телефоне — работает офлайн',
      AppLocale.en: 'Lives right on your phone — works offline',
    },
    'nearbyFriendNeedsSetup': {
      AppLocale.ru: 'Друг поблизости пока не зашёл в гости',
      AppLocale.en: 'Your nearby friend hasn\'t stopped by yet',
    },
    'nearbyFriendIntro': {
      AppLocale.ru:
          'Друг поблизости (Gemma 3, 1B) живёт прямо на телефоне и болтает совсем без интернета — но сначала его нужно один раз позвать в гости: скачать модель (~500 МБ). Дальше сеть не понадобится вообще.',
      AppLocale.en:
          'Your nearby friend (Gemma 3, 1B) lives right on your phone and chats with zero internet — but first you need to invite them over once: download the model (~500 MB). After that, no network needed at all.',
    },
    'nearbyFriendReady': {
      AppLocale.ru: 'Друг поблизости зашёл в гости и готов болтать офлайн 👋',
      AppLocale.en:
          'Your nearby friend has settled in and is ready to chat offline 👋',
    },
    'hfTokenLabel': {
      AppLocale.ru: 'Токен HuggingFace',
      AppLocale.en: 'HuggingFace token'
    },
    'hfTokenHint': {
      AppLocale.ru:
          'Модель Gemma закрыта лицензией Google — примите условия на странице модели на huggingface.co и создайте read-токен (Settings → Access Tokens).',
      AppLocale.en:
          'Gemma is gated by Google\'s license — accept the terms on the model page on huggingface.co and create a read token (Settings → Access Tokens).',
    },
    'startTraining': {
      AppLocale.ru: 'Позвать в гости',
      AppLocale.en: 'Invite them over'
    },
    'trainingInProgress': {
      AppLocale.ru: 'Идёт в гости',
      AppLocale.en: 'On their way'
    },
    'localModelUnavailable': {
      AppLocale.ru: 'Друг поблизости ещё не зашёл в гости — откройте Настройки',
      AppLocale.en:
          'Your nearby friend hasn\'t stopped by yet — check Settings',
    },

    // Settings
    'appearance': {AppLocale.ru: 'Внешний вид', AppLocale.en: 'Appearance'},
    'goalsSection': {
      AppLocale.ru: 'Цели и напоминания',
      AppLocale.en: 'Goals & reminders'
    },
    'dataSection': {AppLocale.ru: 'Данные', AppLocale.en: 'Data'},
    'backendUrl': {
      AppLocale.ru: 'Адрес сервера чата',
      AppLocale.en: 'Chat backend URL'
    },
    'save': {AppLocale.ru: 'Сохранить', AppLocale.en: 'Save'},
    'saved': {AppLocale.ru: 'Сохранено', AppLocale.en: 'Saved'},
    'language': {
      AppLocale.ru: 'Язык интерфейса',
      AppLocale.en: 'Interface language'
    },
    'theme': {AppLocale.ru: 'Тема оформления', AppLocale.en: 'Theme'},
    'themeLight': {AppLocale.ru: 'Светлая', AppLocale.en: 'Light'},
    'themeDark': {AppLocale.ru: 'Тёмная', AppLocale.en: 'Dark'},
    'dailyReminder': {
      AppLocale.ru: 'Ежедневное напоминание',
      AppLocale.en: 'Daily reminder'
    },
    'reminderTime': {
      AppLocale.ru: 'Время напоминания',
      AppLocale.en: 'Reminder time'
    },
    'reminderBody': {
      AppLocale.ru: 'Не теряй серию — позанимайся сегодня 🔥',
      AppLocale.en: "Don't lose your streak — study today 🔥",
    },
    'clearChatHistory': {
      AppLocale.ru: 'Очистить историю чата',
      AppLocale.en: 'Clear chat history'
    },
    'resetProgress': {
      AppLocale.ru: 'Сбросить прогресс',
      AppLocale.en: 'Reset progress'
    },
    'resetProgressConfirmTitle': {
      AppLocale.ru: 'Сбросить весь прогресс?',
      AppLocale.en: 'Reset all progress?',
    },
    'resetProgressConfirmBody': {
      AppLocale.ru:
          'XP, серия, жизни и история повторений будут удалены безвозвратно. Словарь останется.',
      AppLocale.en:
          'XP, streak, hearts, and review history will be permanently deleted. The word bank stays.',
    },
    'confirm': {AppLocale.ru: 'Подтвердить', AppLocale.en: 'Confirm'},
    'cancel': {AppLocale.ru: 'Отмена', AppLocale.en: 'Cancel'},
    'done': {AppLocale.ru: 'Готово', AppLocale.en: 'Done'},
    'error': {AppLocale.ru: 'Ошибка', AppLocale.en: 'Error'},
  };

  static String of(AppLocale locale, String key) =>
      _values[key]?[locale] ?? key;
}
