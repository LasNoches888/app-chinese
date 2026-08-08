import 'package:flutter/material.dart';

import 'app_strings.dart';

class AchievementInfo {
  final String id;
  final IconData icon;
  final Map<AppLocale, String> label;

  const AchievementInfo({required this.id, required this.icon, required this.label});

  String labelFor(AppLocale locale) => label[locale] ?? id;
}

const List<AchievementInfo> kAllAchievements = [
  AchievementInfo(
    id: 'first_step',
    icon: Icons.flag,
    label: {AppLocale.ru: 'Первый шаг', AppLocale.en: 'First step'},
  ),
  AchievementInfo(
    id: 'streak_3',
    icon: Icons.local_fire_department,
    label: {AppLocale.ru: '3 дня подряд', AppLocale.en: '3-day streak'},
  ),
  AchievementInfo(
    id: 'streak_7',
    icon: Icons.local_fire_department,
    label: {AppLocale.ru: '7 дней подряд', AppLocale.en: '7-day streak'},
  ),
  AchievementInfo(
    id: 'streak_30',
    icon: Icons.local_fire_department,
    label: {AppLocale.ru: '30 дней подряд', AppLocale.en: '30-day streak'},
  ),
  AchievementInfo(
    id: 'words_10',
    icon: Icons.menu_book,
    label: {AppLocale.ru: '10 слов выучено', AppLocale.en: '10 words learned'},
  ),
  AchievementInfo(
    id: 'words_50',
    icon: Icons.menu_book,
    label: {AppLocale.ru: '50 слов выучено', AppLocale.en: '50 words learned'},
  ),
  AchievementInfo(
    id: 'words_100',
    icon: Icons.menu_book,
    label: {AppLocale.ru: '100 слов выучено', AppLocale.en: '100 words learned'},
  ),
  AchievementInfo(
    id: 'reviews_100',
    icon: Icons.emoji_events,
    label: {AppLocale.ru: '100 повторений', AppLocale.en: '100 reviews'},
  ),
];
