import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'app_strings.dart';

/// Holds app-wide configuration: backend base URL, UI language, flashcard
/// front-side preference, and daily reminder settings. Default backend URL
/// targets the Android emulator's host loopback; override in-app for a
/// physical device.
class AppSettings extends ChangeNotifier {
  static const _baseUrlKey = 'base_url';
  static const _localeKey = 'app_locale';
  static const _cardFrontKey = 'card_front_side';
  static const _reminderEnabledKey = 'reminder_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';
  static const defaultBaseUrl = 'http://10.0.2.2:8000';
  static const _userId = 'demo-user';

  String _baseUrl = defaultBaseUrl;
  String get baseUrl => _baseUrl;
  String get userId => _userId;

  AppLocale _locale = AppLocale.ru;
  AppLocale get locale => _locale;

  CardFrontSide _cardFrontSide = CardFrontSide.hanzi;
  CardFrontSide get cardFrontSide => _cardFrontSide;

  bool _reminderEnabled = false;
  bool get reminderEnabled => _reminderEnabled;

  TimeOfDay _reminderTime = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay get reminderTime => _reminderTime;

  ApiClient get client => ApiClient(baseUrl: _baseUrl, userId: _userId);

  String t(String key) => Strings.of(_locale, key);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
    _locale = prefs.getString(_localeKey) == 'en' ? AppLocale.en : AppLocale.ru;
    _cardFrontSide = prefs.getString(_cardFrontKey) == 'translation'
        ? CardFrontSide.translation
        : CardFrontSide.hanzi;
    _reminderEnabled = prefs.getBool(_reminderEnabledKey) ?? false;
    _reminderTime = TimeOfDay(
      hour: prefs.getInt(_reminderHourKey) ?? 19,
      minute: prefs.getInt(_reminderMinuteKey) ?? 0,
    );
    notifyListeners();
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

  Future<void> setCardFrontSide(CardFrontSide side) async {
    _cardFrontSide = side;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cardFrontKey,
      side == CardFrontSide.translation ? 'translation' : 'hanzi',
    );
  }

  Future<void> setReminder({required bool enabled, required TimeOfDay time}) async {
    _reminderEnabled = enabled;
    _reminderTime = time;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reminderEnabledKey, enabled);
    await prefs.setInt(_reminderHourKey, time.hour);
    await prefs.setInt(_reminderMinuteKey, time.minute);
  }
}
