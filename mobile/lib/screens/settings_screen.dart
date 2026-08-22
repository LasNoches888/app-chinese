import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../api/app_strings.dart';
import '../api/reminder_service.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../models/user_stats.dart';
import '../services/local_llm_service.dart';
import '../services/speech_service.dart';

const _brandStart = Color(0xFFFF7A59);
const _brandEnd = Color(0xFF6C5CE7);
const _accentGreen = Color(0xFF23C58F);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with StopSpeechOnDispose, WidgetsBindingObserver {
  UserStats? _stats;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from Android's "install voice data" flow is the one case
    // where speech availability can change without any action inside this
    // screen — recheck so the panel updates itself instead of needing a
    // manual refresh.
    if (state == AppLifecycleState.resumed) setState(() {});
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _toggleReminder(bool enabled, AppSettings settings) async {
    if (enabled) {
      await ReminderService.requestPermission();
      await ReminderService.scheduleDaily(
        hour: settings.reminderTime.hour,
        minute: settings.reminderTime.minute,
        title: 'Uchi',
        body: settings.t('reminderBody'),
      );
    } else {
      await ReminderService.cancel();
    }
    await settings.setReminder(enabled: enabled, time: settings.reminderTime);
  }

  Future<void> _pickTime(AppSettings settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: settings.reminderTime,
    );
    if (picked == null) return;
    await settings.setReminder(enabled: settings.reminderEnabled, time: picked);
    if (settings.reminderEnabled) {
      await ReminderService.scheduleDaily(
        hour: picked.hour,
        minute: picked.minute,
        title: 'Uchi',
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(settings.t('done'))));
  }

  Future<void> _confirmResetProgress(AppSettings settings) async {
    final repos = context.read<AppRepositories>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(settings.t('resetProgressConfirmTitle')),
        content: Text(settings.t('resetProgressConfirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(settings.t('cancel')),
          ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(settings.t('done'))));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('settings')),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            const _BrandHeader(),
            const SizedBox(height: 20),
            _SectionCard(
              icon: Icons.palette_outlined,
              accent: _brandEnd,
              title: settings.t('appearance'),
              children: [
                _SettingTile(
                  label: settings.t('language'),
                  child: SegmentedButton<AppLocale>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: AppLocale.ru,
                        label: Text('Русский'),
                      ),
                      ButtonSegment(
                        value: AppLocale.en,
                        label: Text('English'),
                      ),
                    ],
                    selected: {settings.locale},
                    onSelectionChanged: (s) =>
                        context.read<AppSettings>().setLocale(s.first),
                  ),
                ),
                _SettingTile(
                  label: settings.t('theme'),
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode_outlined, size: 18),
                        label: Text(settings.t('themeLight')),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode_outlined, size: 18),
                        label: Text(settings.t('themeDark')),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (s) =>
                        context.read<AppSettings>().setThemeMode(s.first),
                  ),
                ),
              ],
            ),
            _SectionCard(
              icon: Icons.volume_up_outlined,
              accent: _accentGreen,
              title: settings.t('speechSection'),
              children: [_buildSpeechSection(settings)],
            ),
            _SectionCard(
              icon: Icons.local_fire_department_outlined,
              accent: _brandStart,
              title: settings.t('goalsSection'),
              children: [
                _SettingTile(
                  label: settings.t('dailyGoal'),
                  child: _stats == null
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        )
                      : SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: 10, label: Text('10 XP')),
                            ButtonSegment(value: 20, label: Text('20 XP')),
                            ButtonSegment(value: 50, label: Text('50 XP')),
                          ],
                          selected: {_stats!.dailyGoalXp},
                          onSelectionChanged: (s) => _setDailyGoal(s.first),
                        ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: Text(settings.t('dailyReminder')),
                  value: settings.reminderEnabled,
                  onChanged: (v) => _toggleReminder(v, settings),
                ),
                // Grows/shrinks the card instead of the time row popping in
                // and out when the reminder switch is toggled.
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: settings.reminderEnabled
                      ? ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule_outlined),
                          title: Text(settings.t('reminderTime')),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _brandStart.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              settings.reminderTime.format(context),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _brandStart,
                              ),
                            ),
                          ),
                          onTap: () => _pickTime(settings),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
            _SectionCard(
              icon: Icons.storage_outlined,
              accent: Colors.blueGrey,
              title: settings.t('dataSection'),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline),
                  title: Text(settings.t('clearChatHistory')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _clearChatHistory(settings),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber, color: Colors.red),
                  title: Text(
                    settings.t('resetProgress'),
                    style: const TextStyle(color: Colors.red),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.red),
                  onTap: () => _confirmResetProgress(settings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeechSection(AppSettings settings) {
    return FutureBuilder<bool>(
      future: SpeechService.ensureInitialized(),
      builder: (context, snapshot) {
        // No setup action to offer here on purpose — the first tap on any
        // ▶ button anywhere in the app quietly triggers the voice install
        // itself (see SpeechService.speak), so this is just a status note.
        if (snapshot.hasData && snapshot.data != true) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.bedtime_outlined,
                  size: 20,
                  color: Colors.grey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    settings.t('speechUnavailable'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _SettingTile(
              label: settings.t('speechSpeed'),
              child: SegmentedButton<SpeechSpeed>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: SpeechSpeed.slow,
                    label: Text(settings.t('speechSlow')),
                  ),
                  ButtonSegment(
                    value: SpeechSpeed.normal,
                    label: Text(settings.t('speechNormal')),
                  ),
                ],
                selected: {settings.speechSpeed},
                onSelectionChanged: (s) =>
                    context.read<AppSettings>().setSpeechSpeed(s.first),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => SpeechService.speak(
                  '你好，我们一起学中文吧',
                  rate: settings.speechSpeed.rate,
                ),
                icon: const Icon(Icons.play_circle_outline),
                label: Text(settings.t('speechSample')),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Gradient banner at the top of Settings — gives the screen an identity
/// without relying on blur/backdrop filters, which have historically
/// rendered inconsistently on Android's Impeller backend.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [_brandStart, _brandEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _brandEnd.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: const Stack(
          children: [
            Positioned.fill(child: BrandHeaderArt()),
            Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  _EmojiAvatar(emoji: '🎓', background: Color(0x38FFFFFF)),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uchi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '学中文 · 每天一点',
                          style: TextStyle(
                            color: Color(0xE6FFFFFF),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grouped settings block: a rounded card with a coloured icon chip, a
/// title, and its rows underneath.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Material (not just a coloured DecoratedBox) so ListTile/InkWell rows
    // inside can paint their ink splashes — a plain container would sit on
    // top of the nearest Material and swallow them.
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 19, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled row inside a [_SectionCard] — label on top, control below,
/// so wide controls (segmented buttons) never overflow on narrow phones.
class _SettingTile extends StatelessWidget {
  final String label;
  final Widget child;

  const _SettingTile({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: child),
        ],
      ),
    );
  }
}

class _EmojiAvatar extends StatelessWidget {
  final String emoji;
  final Color background;

  const _EmojiAvatar({required this.emoji, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 24)),
    );
  }
}
