import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../api/app_strings.dart';
import '../api/reminder_service.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../models/user_stats.dart';
import '../services/local_llm_service.dart';

const _brandStart = Color(0xFFFF7A59);
const _brandEnd = Color(0xFF6C5CE7);
const _accentGreen = Color(0xFF23C58F);
const _accentGreenDark = Color(0xFF17A673);
const _accentBlue = Color(0xFF4E7CFF);

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
    _controller = TextEditingController(
      text: context.read<AppSettings>().baseUrl,
    );
    _hfTokenController = TextEditingController(
      text: context.read<AppSettings>().hfToken,
    );
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

  Future<void> _downloadLocalModel(AppSettings settings) async {
    final token = _hfTokenController.text.trim();
    if (token.isNotEmpty) await settings.setHfToken(token);
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
      _downloadError = null;
    });
    try {
      await LocalLlmService.downloadModel(
        huggingFaceToken: token.isEmpty ? null : token,
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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: false,
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
              icon: Icons.forum_outlined,
              accent: _accentBlue,
              title: settings.t('chatSource'),
              children: [
                // IntrinsicHeight is what makes `stretch` legal here: inside a
                // ListView the Row has unbounded height, and stretching a child
                // to that throws "BoxConstraints forces an infinite height",
                // which takes the whole settings list down with it.
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ChatModeCard(
                          emoji: '🎓',
                          gradient: const [_accentBlue, _brandEnd],
                          title: settings.t('chatSourceServer'),
                          subtitle: settings.t('chatSourceServerDesc'),
                          selected: settings.chatMode == ChatMode.server,
                          onTap: () => context.read<AppSettings>().setChatMode(
                            ChatMode.server,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ChatModeCard(
                          emoji: LocalLlmService.isModelReady ? '👋' : '🚪',
                          gradient: const [_accentGreen, _accentGreenDark],
                          title: settings.t('chatSourceLocal'),
                          subtitle: settings.t('chatSourceLocalDesc'),
                          selected: settings.chatMode == ChatMode.local,
                          onTap: () => context.read<AppSettings>().setChatMode(
                            ChatMode.local,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Server and local panels are very different heights, so the
                // card is resized as well as cross-faded — otherwise the swap
                // jumps the whole list.
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: KeyedSubtree(
                      key: ValueKey<ChatMode>(settings.chatMode),
                      child: settings.chatMode == ChatMode.server
                          ? _buildServerSection(settings)
                          : _buildLocalModelSection(settings),
                    ),
                  ),
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

  Widget _buildServerSection(AppSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          settings.t('backendUrl'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.link),
            hintText: 'http://10.0.2.2:8000',
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _accentBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              context.read<AppSettings>().setBaseUrl(_controller.text.trim());
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(settings.t('saved'))));
            },
            icon: const Icon(Icons.save_outlined),
            label: Text(settings.t('save')),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalModelSection(AppSettings settings) {
    final theme = Theme.of(context);

    if (LocalLlmService.isModelReady) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [_accentGreen, _accentGreenDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const _EmojiAvatar(emoji: '👋', background: Color(0x38FFFFFF)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                settings.t('nearbyFriendReady'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentGreen.withValues(alpha: 0.4)),
        color: _accentGreen.withValues(alpha: 0.06),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _EmojiAvatar(
                emoji: '🚪',
                background: _accentGreen.withValues(alpha: 0.18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  settings.t('nearbyFriendNeedsSetup'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            settings.t('nearbyFriendIntro'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          Text(
            settings.t('hfTokenLabelOptional'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            settings.t('hfTokenHint'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _hfTokenController,
            enabled: !_downloading,
            obscureText: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              hintText: 'hf_...',
              isDense: true,
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
          ),
          const SizedBox(height: 16),
          if (_downloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _downloadProgress / 100,
                minHeight: 10,
                color: _accentGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text('${settings.t('trainingInProgress')}… $_downloadProgress%'),
          ] else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _accentGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _downloadLocalModel(settings),
                icon: const Icon(Icons.download_outlined),
                label: Text(settings.t('startTraining')),
              ),
            ),
          if (_downloadError != null) ...[
            const SizedBox(height: 10),
            Text(
              '${settings.t('error')}: $_downloadError',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
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

class _ChatModeCard extends StatelessWidget {
  final String emoji;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ChatModeCard({
    required this.emoji,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: selected
              ? LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected
              ? null
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.24)
                        : theme.colorScheme.surface,
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: 19,
                  color: selected ? Colors.white : theme.colorScheme.outline,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: selected ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                color: selected
                    ? Colors.white.withValues(alpha: 0.92)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
