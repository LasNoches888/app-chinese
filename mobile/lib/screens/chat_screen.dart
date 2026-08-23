import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../components/speak_button.dart';
import '../models/chat_message.dart';
import '../services/pinyin_annotator.dart';
import '../services/tutor_reference.dart';
import '../services/tutor_fact_checker.dart';
import '../services/connectivity_service.dart';
import '../services/local_llm_service.dart';
import '../services/persona.dart';
import '../services/system_prompt.dart';
import 'settings_screen.dart';

const _accentGreen = Color(0xFF23C58F);
const _accentGreenDark = Color(0xFF17A673);
const _accentBlue = Color(0xFF4E7CFF);
const _brandEnd = Color(0xFF6C5CE7);

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputCtl = TextEditingController();
  final ConnectivityService _connectivity = ConnectivityService();
  StreamSubscription<bool>? _sub;
  bool _sending = false;
  bool _online = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _initConnectivity();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The weights are on disk but not in memory after a cold start — read
    // them back so the active persona is usable without re-downloading.
    final variant = localVariantFor(context.read<AppSettings>().chatMode);
    if (variant != null &&
        LocalLlmService.status[variant]!.value == LocalModelStatus.unknown) {
      LocalLlmService.loadFromCacheIfPresent(variant);
    }
  }

  Future<void> _initConnectivity() async {
    final online = await _connectivity.isOnline();
    if (mounted) setState(() => _online = online);
    _sub = _connectivity.onStatusChange.listen((online) {
      if (mounted) setState(() => _online = online);
    });
  }

  Future<void> _loadHistory() async {
    final repos = context.read<AppRepositories>();
    final history = await repos.chat.getHistory();
    if (!mounted) return;
    setState(() => _messages.addAll(history));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _inputCtl.dispose();
    super.dispose();
  }

  bool _canSend(AppSettings settings) {
    if (_sending) return false;
    final variant = localVariantFor(settings.chatMode);
    if (variant != null) return LocalLlmService.isModelReady(variant);
    return _online;
  }

  Future<void> _send() async {
    final text = _inputCtl.text.trim();
    final settings = context.read<AppSettings>();
    if (text.isEmpty || !_canSend(settings)) return;
    final repos = context.read<AppRepositories>();

    final userMessage = await repos.chat.addUserMessage(text);
    setState(() {
      _messages.add(userMessage);
      _sending = true;
      _inputCtl.clear();
    });

    try {
      final knownIds = await repos.srs.getKnownWordIds();
      final weakIds = await repos.srs.getWeakWordIds();
      final knownWords = (await repos.words.getWordsByIds(
        knownIds,
      )).map((w) => w.hanzi).toList();
      final weak = await repos.words.getWordsByIds(weakIds);
      final weakWords = weak.map((w) => w.hanzi).toList();

      final ChatMessage reply;
      final variant = localVariantFor(settings.chatMode);
      if (variant != null) {
        final annotator = PinyinAnnotator(repos.dictionary, repos.words);
        // The model can't hold the facts of the language, so it is given
        // them instead of asked to recall them.
        final reference = await TutorReference.build(
          learnerMessage: text,
          weakWords: weak,
          dictionary: repos.dictionary,
          annotator: annotator,
        );
        final prompt = variant == LocalModelVariant.friend
            ? buildFriendSystemPrompt(
                hskLevel: 1,
                knownWords: knownWords,
                weakWords: weakWords,
                reference: reference,
              )
            : buildTutorSystemPrompt(
                hskLevel: 1,
                knownWords: knownWords,
                weakWords: weakWords,
                reference: reference,
              );
        final raw = await LocalLlmService.sendMessage(
          variant,
          text,
          systemPrompt: prompt,
        );
        final json = LocalLlmService.extractReplyJson(raw);
        reply = json != null
            ? ChatMessage.fromReplyJson(json)
            : ChatMessage(fromUser: false, text: raw);
      } else {
        reply = await settings.chatClient.sendChatMessage(
          text,
          knownWords: knownWords,
          weakWords: weakWords,
        );
      }
      // The tutor writes characters well but transcribes them by guess;
      // the dictionary knows the readings for certain.
      final corrected = await PinyinAnnotator(
        repos.dictionary,
        repos.words,
      ).correct(reply);
      // And it states the occasional falsehood about the language, which
      // the dictionary can also settle.
      final checked = await TutorFactChecker(repos.dictionary).check(corrected);
      final saved = await repos.chat.addAssistantMessage(checked.message);
      if (!mounted) return;
      setState(() => _messages.add(saved));
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          ChatMessage(fromUser: false, text: '${settings.t('error')}: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openPersonaPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _PersonaPickerSheet(
        onPicked: () {
          if (mounted) Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  Future<void> _clearHistory() async {
    final repos = context.read<AppRepositories>();
    await repos.chat.clearHistory();
    LocalLlmService.resetSession();
    if (!mounted) return;
    setState(() => _messages.clear());
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return AnimatedBuilder(
      animation: Listenable.merge(LocalLlmService.status.values.toList()),
      builder: (context, _) => _buildScaffold(settings),
    );
  }

  Widget _buildScaffold(AppSettings settings) {
    final variant = localVariantFor(settings.chatMode);
    final modelStatus = variant == null
        ? null
        : LocalLlmService.status[variant]!.value;
    final localReady = modelStatus == LocalModelStatus.ready;
    final canSend = _canSend(settings);
    final showBlockedBanner = variant != null ? !localReady : !_online;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('chatTitle'), overflow: TextOverflow.ellipsis),
        actions: [
          // Tapping the badge opens the persona picker — a small emoji
          // rather than a text label, since a full status label made the
          // actions row wide enough to overflow the AppBar on narrow
          // phones and push the settings button off-screen entirely.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _openPersonaPicker,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(switch (variant) {
                  null => '🎓',
                  LocalModelVariant.friend => localReady ? '👋' : '🚪',
                  LocalModelVariant.tutor => localReady ? '📖' : '📕',
                }, style: const TextStyle(fontSize: 18)),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: settings.t('clearChatHistory'),
            onPressed: _clearHistory,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: settings.t('settings'),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: AppBackground(
        child: variant == null
            ? _ProfessorInDevelopment(
                settings: settings,
                onPickAnother: _openPersonaPicker,
              )
            : Column(
                children: [
                  if (showBlockedBanner)
                    Builder(
                      builder: (context) {
                        // Loading cached weights is a normal, short-lived
                        // state — showing it in alarming red as "model
                        // unavailable" would read like something's broken.
                        final isWakingUp =
                            modelStatus == LocalModelStatus.loading;
                        final color = isWakingUp ? _accentGreen : Colors.red;
                        final personaLabel = personaName(settings, variant);
                        return InkWell(
                          onTap: isWakingUp ? null : _openPersonaPicker,
                          child: Container(
                            width: double.infinity,
                            color: color.withValues(alpha: 0.12),
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              (isWakingUp
                                      ? settings.t('personaWakingUp')
                                      : settings.t('personaUnavailable'))
                                  .replaceFirst('{name}', personaLabel),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: color),
                            ),
                          ),
                        );
                      },
                    ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      itemBuilder: (ctx, i) => i < _messages.length
                          ? _MessageBubble(
                              message: _messages[i],
                              settings: settings,
                            )
                          : _TypingBubble(label: settings.t('chatThinking')),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputCtl,
                              enabled: canSend,
                              decoration: InputDecoration(
                                hintText: settings.t('chatHint'),
                                border: const OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            icon: const Icon(Icons.send),
                            onPressed: canSend ? _send : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Friendly placeholder shown instead of a real chat when Professor —
/// the only server-backed persona — is selected. Professor isn't offered
/// as a choice in the picker anymore (see _PersonaPickerSheet), so this
/// only appears for someone whose saved chatMode predates that change.
class _ProfessorInDevelopment extends StatelessWidget {
  final AppSettings settings;
  final VoidCallback onPickAnother;

  const _ProfessorInDevelopment({
    required this.settings,
    required this.onPickAnother,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/mascot/panda_25.png', height: 140),
            const SizedBox(height: 20),
            Text(
              settings.t('professorInDevTitle'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              settings.t('professorInDevBody'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onPickAnother,
              icon: const Icon(Icons.forum_outlined),
              label: Text(settings.t('switchPersona')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for picking who to chat with. Professor is shown but
/// disabled — a coming-soon card rather than a working option — since the
/// server-hosted model isn't ready to be someone's daily study partner
/// yet; Friend and Tutor are the two real choices, each downloadable
/// (and re-downloadable) straight from here.
class _PersonaPickerSheet extends StatelessWidget {
  final VoidCallback onPicked;

  const _PersonaPickerSheet({required this.onPicked});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              settings.t('choosePersona'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _PersonaRow(
              emoji: '🎓',
              gradient: const [_accentBlue, _brandEnd],
              title: settings.t('chatSourceServer'),
              subtitle: settings.t('professorInDevBadge'),
              enabled: false,
              selected: false,
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _LocalPersonaRow(
              variant: LocalModelVariant.friend,
              emoji: '🚪',
              readyEmoji: '👋',
              gradient: const [_accentGreen, _accentGreenDark],
              title: settings.t('chatSourceLocal'),
              settings: settings,
              onPicked: onPicked,
            ),
            const SizedBox(height: 10),
            _LocalPersonaRow(
              variant: LocalModelVariant.tutor,
              emoji: '📕',
              readyEmoji: '📖',
              gradient: const [_accentGreenDark, _accentGreen],
              title: settings.t('chatSourceTutor'),
              settings: settings,
              onPicked: onPicked,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalPersonaRow extends StatelessWidget {
  final LocalModelVariant variant;
  final String emoji;
  final String readyEmoji;
  final List<Color> gradient;
  final String title;
  final AppSettings settings;
  final VoidCallback onPicked;

  const _LocalPersonaRow({
    required this.variant,
    required this.emoji,
    required this.readyEmoji,
    required this.gradient,
    required this.title,
    required this.settings,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        LocalLlmService.status[variant]!,
        LocalLlmService.downloadProgress[variant]!,
      ]),
      builder: (context, _) {
        final status = LocalLlmService.status[variant]!.value;
        final progress = LocalLlmService.downloadProgress[variant]!.value;
        final selected = localVariantFor(settings.chatMode) == variant;
        final subtitle = switch (status) {
          LocalModelStatus.ready => settings.t('personaReadyShort'),
          LocalModelStatus.downloading =>
            '${settings.t('trainingInProgress')}… $progress%',
          LocalModelStatus.loading =>
            settings
                .t('personaWakingUp')
                .replaceFirst('{name}', personaName(settings, variant)),
          LocalModelStatus.absent ||
          LocalModelStatus.unknown => settings.t('personaTapToStart'),
        };
        return _PersonaRow(
          emoji: status == LocalModelStatus.ready ? readyEmoji : emoji,
          gradient: gradient,
          title: title,
          subtitle: subtitle,
          enabled: true,
          selected: selected,
          onTap: () {
            context.read<AppSettings>().setChatMode(
              variant == LocalModelVariant.friend
                  ? ChatMode.localFriend
                  : ChatMode.localTutor,
            );
            if (status == LocalModelStatus.unknown ||
                status == LocalModelStatus.absent) {
              LocalLlmService.ensureReady(variant);
            }
            onPicked();
          },
        );
      },
    );
  }
}

class _PersonaRow extends StatelessWidget {
  final String emoji;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  const _PersonaRow({
    required this.emoji,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: selected ? LinearGradient(colors: gradient) : null,
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
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.24)
                      : theme.colorScheme.surface,
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: selected ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.92)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: Colors.white, size: 20)
              else if (enabled)
                Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stands in for the tutor's turn while a reply is generating — a bare
/// progress bar at the bottom of the screen read as "something might be
/// broken" during a slow (multi-second) model response; a bubble in the
/// same spot the reply will land makes the wait legible as "it's typing".
class _TypingBubble extends StatelessWidget {
  final String label;

  const _TypingBubble({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final AppSettings settings;

  const _MessageBubble({required this.message, required this.settings});

  @override
  Widget build(BuildContext context) {
    final align = message.fromUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final color = message.fromUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.text.isNotEmpty) Text(message.text),
              if (message.pinyin != null && message.pinyin!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    message.pinyin!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              // Only the tutor's turns: the learner's own message is
              // whatever they typed, which may not be Chinese at all.
              // Nothing to read aloud when the whole reply was removed.
              if (!message.fromUser && message.text.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: SpeakButton(text: message.text, size: 20),
                ),
              if (message.note != null) _FactNote(noteKey: message.note!),
            ],
          ),
        ),
        if (!message.fromUser &&
            message.grammarRecast != null &&
            message.grammarRecast!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: Colors.amber,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${settings.t('tryRecast')}: ${message.grammarRecast}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Says that the app took something out of the tutor's reply.
///
/// Silently deleting a sentence would leave the learner reading a reply
/// with a hole in it and no idea why — and quietly editing what the tutor
/// said is its own small dishonesty.
class _FactNote extends StatelessWidget {
  final String noteKey;

  const _FactNote({required this.noteKey});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 15, color: theme.colorScheme.outline),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              settings.t(noteKey),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
