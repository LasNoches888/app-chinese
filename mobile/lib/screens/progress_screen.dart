import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/achievements.dart';
import '../api/app_settings.dart';
import '../api/app_strings.dart';
import '../models/user_stats.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  UserStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await context.read<AppSettings>().client.fetchStats();
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('progress')),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh)],
      ),
      body: _buildBody(settings),
    );
  }

  Widget _buildBody(AppSettings settings) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('${settings.t('error')}: $_error', textAlign: TextAlign.center));
    }
    final stats = _stats!;
    final goalProgress = (stats.xpToday / stats.dailyGoalXp).clamp(0.0, 1.0);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        child: Text('${stats.level}', style: const TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 12),
                      Text('${settings.t('level')} ${stats.level}',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      Text('${stats.xpTotal} XP', style: Theme.of(context).textTheme.titleMedium),
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
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _StatCard(
                icon: Icons.local_fire_department,
                iconColor: Colors.deepOrange,
                label: settings.t('streakDays'),
                value: '${stats.streakDays}',
              ),
              _StatCard(
                icon: Icons.check_circle,
                iconColor: Colors.green,
                label: settings.t('learnedWords'),
                value: '${stats.learnedWords}',
              ),
              _StatCard(
                icon: Icons.menu_book,
                iconColor: Colors.blue,
                label: settings.t('totalWords'),
                value: '${stats.totalWords}',
              ),
              _StatCard(
                icon: Icons.error_outline,
                iconColor: Colors.orange,
                label: settings.t('weakWords'),
                value: '${stats.weakWords}',
              ),
              _StatCard(
                icon: Icons.today,
                iconColor: Colors.purple,
                label: settings.t('reviewsToday'),
                value: '${stats.reviewsToday}',
              ),
              _StatCard(
                icon: Icons.percent,
                iconColor: Colors.teal,
                label: settings.t('accuracy'),
                value: '${stats.accuracyPercent.toStringAsFixed(0)}%',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(settings.t('achievements'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final achievement in kAllAchievements)
                _AchievementChip(
                  achievement: achievement,
                  unlocked: stats.achievements.contains(achievement.id),
                  locale: settings.locale,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementChip extends StatelessWidget {
  final AchievementInfo achievement;
  final bool unlocked;
  final AppLocale locale;

  const _AchievementChip({required this.achievement, required this.unlocked, required this.locale});

  @override
  Widget build(BuildContext context) {
    final color = unlocked ? Colors.amber.shade700 : Theme.of(context).disabledColor;
    return Chip(
      avatar: Icon(achievement.icon, size: 18, color: unlocked ? Colors.white : color),
      label: Text(achievement.labelFor(locale)),
      backgroundColor: unlocked ? Colors.amber.shade700 : null,
      labelStyle: unlocked ? const TextStyle(color: Colors.white) : TextStyle(color: color),
    );
  }
}
