# AppChinese — mobile

Offline-first Flutter-приложение для изучения китайского (Android). Всё,
что не требует LLM, работает без сети: уроки, SRS-повторение, XP/уровни,
жизни, стрики, ачивки — локальная SQLite-БД (`sqflite`), стартовые колоды
HSK1/2 зашиты в APK как JSON-ассеты. Единственная фича, которой нужен
интернет, — чат с AI-репетитором; при отсутствии сети поле ввода
блокируется, а не падает с ошибкой.

## Архитектура

```
lib/
  db/app_database.dart        — схема SQLite, миграции
  models/                     — Word, Deck, UserStats, ExerciseQuestion, ...
  repositories/                — единственная точка доступа к БД
    word_repository.dart       — seed из assets/, запросы словаря
    srs_repository.dart        — review_history (SM-2), due-слова, стрик-календарь
    stats_repository.dart      — XP/уровень/жизни/дневная цель
    achievements_repository.dart
    chat_repository.dart       — локальная история чата
  services/                    — чистые функции, без Flutter/БД (юнит-тестируемые)
    srs_service.dart           — упрощённый SM-2
    xp_service.dart            — XP/уровни
    streak_service.dart        — стрики (граничные случаи дня)
    hearts_service.dart        — регенерация жизней по времени
    exercise_generator.dart    — сборка очереди упражнений
    connectivity_service.dart  — обёртка над connectivity_plus
  screens/                     — Уроки, Повторить, Прогресс, Чат, Настройки
```

## Упражнения

6 типов: флеш-карточка (самооценка), тест с вариантами (иероглиф→перевод и
обратно), сборка предложения, ввод пиньиня, написание иероглифа по
штрихам (`stroke_order_animator`).

Данные о порядке штрихов — `assets/seed/stroke_data.json`, вырезаны из
датасета [Make Me a Hanzi](https://github.com/skishore/makemeahanzi)
(ARPHIC public license) под 94 иероглифа, реально встречающихся в словаре
приложения. Полностью офлайн — грузится из ассетов, сети не требует.

Бэкенд (`../backend`) нужен только для `/chat` — он получает снимок
локального словаря (`known_words`/`weak_words`) прямо в теле запроса и
ничего не хранит на сервере.

## Разработка

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Base URL чат-бэкенда настраивается на экране Settings в приложении
(по умолчанию `http://10.0.2.2:8000` для Android-эмулятора).

## Тесты

`test/services/*_test.dart` — юнит-тесты алгоритмов (SM-2, XP/уровни,
стрики с граничными случаями, регенерация жизней), без БД и без Flutter-биндингов.

`test/widget_test.dart` — виджет-тест на главную навигацию. Использует
`sqflite_common_ffi` (вариант `databaseFactoryFfiNoIsolate`) для реальной
SQLite в `flutter test`, и `tester.runAsync()` для открытия БД — открытие
файла реального SQLite внутри fake-async зоны `testWidgets` иначе
подвисает намертво.

## Известные ограничения (сознательно вне скоупа)

- Голосовой ввод/произношение, TTS для оценки — нет.
- Реальные аккаунты, облачная синхронизация, лиги — нет (единый локальный
  пользователь).
- Push-уведомления с сервера — только локальные (`flutter_local_notifications`).
