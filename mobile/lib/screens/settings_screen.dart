import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../api/app_strings.dart';
import '../api/reminder_service.dart';
import '../app_repositories.dart';
import '../models/user_stats.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _controller;
  UserStats? _stats;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<AppSettings>().baseUrl);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await context.read<AppRepositories>().stats.getStats();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleReminder(bool enabled, AppSettings settings) async {
    if (enabled) {
      await ReminderService.requestPermission();
      await ReminderService.scheduleDaily(
        hour: settings.reminderTime.hour,
        minute: settings.reminderTime.minute,
        title: 'AppChinese',
        body: settings.t('reminderBody'),
      );
    } else {
      await ReminderService.cancel();
    }
    await settings.setReminder(enabled: enabled, time: settings.reminderTime);
  }

  Future<void> _pickTime(AppSettings settings) async {
    final picked = await showTimePicker(context: context, initialTime: settings.reminderTime);
    if (picked == null) return;
    await settings.setReminder(enabled: settings.reminderEnabled, time: picked);
    if (settings.reminderEnabled) {
      await ReminderService.scheduleDaily(
        hour: picked.hour,
        minute: picked.minute,
        title: 'AppChinese',
        body: settings.t('reminderBody'),
      );
    }
  }

  Future<void> _setDailyGoal(int xp) async {
    final repos = context.read<AppRepositories>();
    final updated = await repos.stats.setDailyGoalXp(xp);
    if (!mounted) return;
    setState(() => _stats = updated);
  }

  Future<void> _clearChatHistory(AppSettings settings) async {
    await context.read<AppRepositories>().chat.clearHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t('done'))));
  }

  Future<void> _confirmResetProgress(AppSettings settings) async {
    final repos = context.read<AppRepositories>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(settings.t('resetProgressConfirmTitle')),
        content: Text(settings.t('resetProgressConfirmBody')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(settings.t('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(settings.t('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await repos.stats.resetAllProgress();
    await _loadStats();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t('done'))));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: Text(settings.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(settings.t('language')),
          const SizedBox(height: 8),
          SegmentedButton<AppLocale>(
            segments: const [
              ButtonSegment(value: AppLocale.ru, label: Text('Русский')),
              ButtonSegment(value: AppLocale.en, label: Text('English')),
            ],
            selected: {settings.locale},
            onSelectionChanged: (s) => context.read<AppSettings>().setLocale(s.first),
          ),
          const SizedBox(height: 24),
          Text(settings.t('theme')),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(value: ThemeMode.light, label: Text(settings.t('themeLight'))),
              ButtonSegment(value: ThemeMode.dark, label: Text(settings.t('themeDark'))),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => context.read<AppSettings>().setThemeMode(s.first),
          ),
          const SizedBox(height: 24),
          Text(settings.t('dailyGoal')),
          const SizedBox(height: 8),
          if (_stats != null)
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 10, label: Text('10 XP')),
                ButtonSegment(value: 20, label: Text('20 XP')),
                ButtonSegment(value: 50, label: Text('50 XP')),
              ],
              selected: {_stats!.dailyGoalXp},
              onSelectionChanged: (s) => _setDailyGoal(s.first),
            ),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(settings.t('dailyReminder')),
            value: settings.reminderEnabled,
            onChanged: (v) => _toggleReminder(v, settings),
          ),
          if (settings.reminderEnabled)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(settings.t('reminderTime')),
              trailing: Text(settings.reminderTime.format(context)),
              onTap: () => _pickTime(settings),
            ),
          const SizedBox(height: 24),
          Text(settings.t('backendUrl')),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'http://10.0.2.2:8000',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              context.read<AppSettings>().setBaseUrl(_controller.text.trim());
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(settings.t('saved'))));
            },
            child: Text(settings.t('save')),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () => _clearChatHistory(settings),
            icon: const Icon(Icons.delete_outline),
            label: Text(settings.t('clearChatHistory')),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => _confirmResetProgress(settings),
            icon: const Icon(Icons.warning_amber),
            label: Text(settings.t('resetProgress')),
          ),
        ],
      ),
    );
  }
}
