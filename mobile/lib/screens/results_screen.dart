import 'package:flutter/material.dart';

import '../api/app_settings.dart';
import '../models/achievement.dart';
import '../models/word.dart';

class LessonResult {
  final int xpEarned;
  final List<Word> mistakes;
  final bool perfect;
  final bool isReview;
  final List<String> newAchievements;

  const LessonResult({
    required this.xpEarned,
    required this.mistakes,
    required this.perfect,
    required this.isReview,
    required this.newAchievements,
  });
}

class ResultsScreen extends StatelessWidget {
  final LessonResult result;
  final AppSettings settings;
  final VoidCallback onContinue;

  const ResultsScreen({
    super.key,
    required this.result,
    required this.settings,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final title = result.isReview
        ? settings.t('reviewComplete')
        : (result.perfect
              ? settings.t('perfectLesson')
              : settings.t('lessonComplete'));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  result.perfect ? '🏆' : '🎉',
                  style: const TextStyle(fontSize: 64),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '+${result.xpEarned} XP',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (result.newAchievements.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    settings.t('newAchievement'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final code in result.newAchievements)
                        Chip(
                          avatar: Text(_iconFor(code)),
                          label: Text(settings.t(_titleKeyFor(code))),
                          backgroundColor: Colors.amber.shade600,
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                    ],
                  ),
                ],
                if (result.mistakes.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      settings.t('mistakesToReview'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          for (final w in result.mistakes)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    w.hanzi,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  Text(
                                    w.pinyin,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(w.translationRu),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onContinue,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 14,
                    ),
                  ),
                  child: Text(settings.t('continueLabel')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _iconFor(String code) => kAchievementDefs
      .firstWhere((a) => a.code == code, orElse: () => kAchievementDefs.first)
      .icon;

  String _titleKeyFor(String code) => kAchievementDefs
      .firstWhere((a) => a.code == code, orElse: () => kAchievementDefs.first)
      .titleKey;
}
