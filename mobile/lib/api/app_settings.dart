import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'app_strings.dart';

enum ChatMode { server, local }

/// How fast the tutor's Mandarin is read aloud. Beginners routinely can't
/// separate tones at native pace, so slow is the default.
enum SpeechSpeed {
  slow,
  normal;

  /// Platform speech rate, where the engine treats 0.5 as normal speed.
  double get rate => this == SpeechSpeed.slow ? 0.35 : 0.5;
}

/// App-wide UI preferences that don't belong in the learning-data database:
/// chat backend URL, interface language/theme, flashcard front-side
/// preference, and daily reminder settings. None of this is required for
/// offline learning to work — it's just presentation config.
class AppSettings extends ChangeNotifier {
  static const _baseUrlKey = 'base_url';
  static const _localeKey = 'app_locale';
  static const _cardFrontKey = 'card_front_side';
  static const _themeKey = 'theme_mode';
  static const _reminderEnabledKey = 'reminder_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';
  static const _chatModeKey = 'chat_mode';
  static const _speechSpeedKey = 'speech_speed';
  static const _onboardedKey = 'onboarded';
  static const defaultBaseUrl = 'http://10.0.2.2:8000';

  String _baseUrl = defaultBaseUrl;
  String get baseUrl => _baseUrl;

  AppLocale _locale = AppLocale.ru;
  AppLocale get locale => _locale;

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  CardFrontSide _cardFrontSide = CardFrontSide.hanzi;
  CardFrontSide get cardFrontSide => _cardFrontSide;

  bool _reminderEnabled = false;
  bool get reminderEnabled => _reminderEnabled;

  TimeOfDay _reminderTime = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay get reminderTime => _reminderTime;

  ChatMode _chatMode = ChatMode.server;
  ChatMode get chatMode => _chatMode;

  SpeechSpeed _speechSpeed = SpeechSpeed.slow;
  SpeechSpeed get speechSpeed => _speechSpeed;

  bool _onboarded = false;
  bool get onboarded => _onboarded;

  ChatApiClient get chatClient => ChatApiClient(baseUrl: _baseUrl);

  String t(String key) => Strings.of(_locale, key);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
    _locale = prefs.getString(_localeKey) == 'en' ? AppLocale.en : AppLocale.ru;
    _themeMode = prefs.getString(_themeKey) == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    _cardFrontSide = prefs.getString(_cardFrontKey) == 'translation'
        ? CardFrontSide.translation
        : CardFrontSide.hanzi;
    _reminderEnabled = prefs.getBool(_reminderEnabledKey) ?? false;
    _reminderTime = TimeOfDay(
      hour: prefs.getInt(_reminderHourKey) ?? 19,
      minute: prefs.getInt(_reminderMinuteKey) ?? 0,
    );
    _chatMode = prefs.getString(_chatModeKey) == 'local'
        ? ChatMode.local
        : ChatMode.server;
    _speechSpeed = prefs.getString(_speechSpeedKey) == 'normal'
        ? SpeechSpeed.normal
        : SpeechSpeed.slow;
    _onboarded = prefs.getBool(_onboardedKey) ?? false;
    notifyListeners();
  }

  Future<void> setOnboarded() async {
    _onboarded = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, true);
  }

  Future<void> setSpeechSpeed(SpeechSpeed speed) async {
    _speechSpeed = speed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _speechSpeedKey,
      speed == SpeechSpeed.normal ? 'normal' : 'slow',
    );
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }

  Future<void> setLocale(AppLocale locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale == AppLocale.en ? 'en' : 'ru');
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> setCardFrontSide(CardFrontSide side) async {
    _cardFrontSide = side;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cardFrontKey,
      side == CardFrontSide.translation ? 'translation' : 'hanzi',
    );
  }

  Future<void> setChatMode(ChatMode mode) async {
    _chatMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _chatModeKey,
      mode == ChatMode.local ? 'local' : 'server',
    );
  }

  Future<void> setReminder({
    required bool enabled,
    required TimeOfDay time,
  }) async {
    _reminderEnabled = enabled;
    _reminderTime = time;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reminderEnabledKey, enabled);
    await prefs.setInt(_reminderHourKey, time.hour);
    await prefs.setInt(_reminderMinuteKey, time.minute);
  }
}
