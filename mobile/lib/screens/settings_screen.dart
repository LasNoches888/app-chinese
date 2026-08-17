import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../api/app_strings.dart';
import '../api/reminder_service.dart';
import '../app_repositories.dart';
import '../models/user_stats.dart';
import '../services/local_llm_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _controller;
  late final TextEditingController _hfTokenController;
  UserStats? _stats;
  bool _downloading = false;
  int _downloadProgress = 0;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<AppSettings>().baseUrl);
    _hfTokenController = TextEditingController(text: context.read<AppSettings>().hfToken);
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
    _hfTokenController.dispose();
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
    LocalLlmService.resetSession();
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

  Future<void> _downloadLocalModel(AppSettings settings) async {
    final token = _hfTokenController.text.trim();
    if (token.isEmpty) return;
    await settings.setHfToken(token);
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
      _downloadError = null;
    });
    try {
      await LocalLlmService.downloadModel(
        huggingFaceToken: token,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      if (!mounted) return;
      setState(() => _downloading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _downloadError = '$e';
      });
    }
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
          const Divider(height: 40),
          Text(settings.t('chatSource'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ChatMode>(
            segments: [
              ButtonSegment(value: ChatMode.server, label: Text(settings.t('chatSourceServer'))),
              ButtonSegment(value: ChatMode.local, label: Text(settings.t('chatSourceLocal'))),
            ],
            selected: {settings.chatMode},
            onSelectionChanged: (s) => context.read<AppSettings>().setChatMode(s.first),
          ),
          if (settings.chatMode == ChatMode.server) ...[
            const SizedBox(height: 16),
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
          ] else
            _buildLocalModelSection(settings),
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

  Widget _buildLocalModelSection(AppSettings settings) {
    if (LocalLlmService.isModelReady) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Card(
          color: Colors.green.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('🎓', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(child: Text(settings.t('littleBrotherReady'))),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🧒', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      settings.t('littleBrotherNeedsTraining'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(settings.t('littleBrotherIntro'), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              Text(settings.t('hfTokenLabel')),
              const SizedBox(height: 4),
              Text(
                settings.t('hfTokenHint'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _hfTokenController,
                enabled: !_downloading,
                obscureText: true,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'hf_...'),
              ),
              const SizedBox(height: 16),
              if (_downloading) ...[
                LinearProgressIndicator(value: _downloadProgress / 100),
                const SizedBox(height: 8),
                Text('${settings.t('trainingInProgress')}… $_downloadProgress%'),
              ] else
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _hfTokenController,
                  builder: (context, value, _) => FilledButton.icon(
                    onPressed: value.text.trim().isEmpty ? null : () => _downloadLocalModel(settings),
                    icon: const Icon(Icons.school),
                    label: Text(settings.t('startTraining')),
                  ),
                ),
              if (_downloadError != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${settings.t('error')}: $_downloadError',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
