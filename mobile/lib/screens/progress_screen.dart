import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../models/achievement.dart';
import '../models/user_stats.dart';
import '../services/xp_service.dart';
import 'settings_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  UserStats? _stats;
  int _learnedWords = 0;
  double _accuracyAllTime = 0;
  double _accuracy7d = 0;
  Set<DateTime> _activeDays = {};
  Map<String, DateTime> _unlocked = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final repos = context.read<AppRepositories>();
    final stats = await repos.stats.getStats();
    final learned = await repos.srs.countLearnedWords();
    final accAll = await repos.srs.accuracyPercent();
    final acc7 = await repos.srs.accuracyPercent(within: const Duration(days: 7));
    final activeDays = await repos.srs.getActiveDaysSince(DateTime.now().subtract(const Duration(days: 30)));
    final unlocked = await repos.achievements.getUnlockedMap();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _learnedWords = learned;
      _accuracyAllTime = accAll;
      _accuracy7d = acc7;
      _activeDays = activeDays;
      _unlocked = unlocked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final stats = _stats;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('progress')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: stats == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _levelCard(context, settings, stats),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      _statTile(context, Icons.local_fire_department, Colors.deepOrange,
                          settings.t('streakDays'), '${stats.currentStreak}'),
                      _statTile(context, Icons.emoji_events, Colors.purple, settings.t('longestStreak'),
                          '${stats.longestStreak}'),
                      _statTile(context, Icons.menu_book, Colors.blue, settings.t('wordsLearned'), '$_learnedWords'),
                      _statTile(context, Icons.percent, Colors.teal, settings.t('accuracyAllTime'),
                          '${_accuracyAllTime.toStringAsFixed(0)}%'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _statTile(context, Icons.trending_up, Colors.green, settings.t('accuracy7d'),
                      '${_accuracy7d.toStringAsFixed(0)}%', wide: true),
                  const SizedBox(height: 24),
                  Text(settings.t('streakCalendar'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _calendar(),
                  const SizedBox(height: 24),
                  Text(settings.t('achievements'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final def in kAchievementDefs) _achievementChip(settings, def)],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _levelCard(BuildContext context, AppSettings settings, UserStats stats) {
    final level = XpService.levelForXp(stats.totalXp);
    final goalProgress = stats.dailyGoalXp > 0 ? (stats.xpToday / stats.dailyGoalXp).clamp(0.0, 1.0) : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 22, child: Text('$level')),
                const SizedBox(width: 12),
                Text('${settings.t('level')} $level', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('${stats.totalXp} XP', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(settings.t('dailyGoal')),
                Text('${stats.xpToday}/${stats.dailyGoalXp} XP'),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: goalProgress, minHeight: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(BuildContext context, IconData icon, Color color, String label, String value,
      {bool wide = false}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: wide
            ? Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label)),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 26),
                  const SizedBox(height: 6),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
      ),
    );
  }

  Widget _calendar() {
    final days = List.generate(30, (i) {
      final d = DateTime.now().subtract(Duration(days: 29 - i));
      return DateTime(d.year, d.month, d.day);
    });
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final d in days)
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _activeDays.contains(d) ? Colors.green : Colors.grey.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }

  Widget _achievementChip(AppSettings settings, AchievementDef def) {
    final unlocked = _unlocked.containsKey(def.code);
    return Chip(
      avatar: Text(def.icon),
      label: Text(settings.t(def.titleKey)),
      backgroundColor: unlocked ? Colors.amber.shade600 : null,
      labelStyle: unlocked ? const TextStyle(color: Colors.white) : null,
    );
  }
}
