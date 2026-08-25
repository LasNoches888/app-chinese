import 'package:flutter/material.dart';

import '../api/app_settings.dart';
import '../api/app_strings.dart' show AppLocale;
import '../models/achievement.dart';
import '../models/word.dart';
import '../services/reward_service.dart';

class LessonResult {
  final int xpEarned;
  final List<Word> mistakes;
  final bool perfect;
  final bool isReview;
  final List<String> newAchievements;

  /// An occasional unprompted extra — bonus XP, a cheer, or a fact about
  /// China. Null most of the time by design; see [RewardService].
  final LessonReward? reward;

  const LessonResult({
    required this.xpEarned,
    required this.mistakes,
    required this.perfect,
    required this.isReview,
    required this.newAchievements,
    this.reward,
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
                // The celebrating panda only for a genuinely good outcome —
                // perfect run or a fresh achievement — so it stays a reward
                // rather than decorating every ordinary completion.
                if (result.perfect || result.newAchievements.isNotEmpty)
                  Image.asset('assets/mascot/panda_04.png', height: 140)
                else
                  const Text('🎉', style: TextStyle(fontSize: 64)),
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
                if (result.reward != null) ...[
                  const SizedBox(height: 16),
                  _RewardCard(reward: result.reward!, settings: settings),
                ],
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

/// The occasional surprise from [RewardService] — a little card that only
/// shows up when there's actually something to say, so it stays a treat
/// rather than more boilerplate on every results screen.
class _RewardCard extends StatelessWidget {
  final LessonReward reward;
  final AppSettings settings;

  const _RewardCard({required this.reward, required this.settings});

  @override
  Widget build(BuildContext context) {
    final ru = settings.locale == AppLocale.ru;
    final (icon, text) = switch (reward.kind) {
      RewardKind.bonusXp => (
        '🎁',
        settings.t('rewardBonusXp').replaceFirst('{xp}', '${reward.xp}'),
      ),
      RewardKind.cheer => ('🐼', ru ? reward.cheer!.ru : reward.cheer!.en),
      RewardKind.fact => ('🧧', ru ? reward.fact!.ru : reward.fact!.en),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
