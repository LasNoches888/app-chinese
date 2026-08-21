import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../components/speak_button.dart';
import '../models/chat_message.dart';
import '../services/connectivity_service.dart';
import '../services/local_llm_service.dart';
import '../services/persona.dart';
import '../services/system_prompt.dart';
import 'settings_screen.dart';

const _accentGreen = Color(0xFF23C58F);

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
      final weakWords = (await repos.words.getWordsByIds(
        weakIds,
      )).map((w) => w.hanzi).toList();

      final ChatMessage reply;
      final variant = localVariantFor(settings.chatMode);
      if (variant != null) {
        final prompt = variant == LocalModelVariant.friend
            ? buildFriendSystemPrompt(
                hskLevel: 1,
                knownWords: knownWords,
                weakWords: weakWords,
              )
            : buildTutorSystemPrompt(
                hskLevel: 1,
                knownWords: knownWords,
                weakWords: weakWords,
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
      final saved = await repos.chat.addAssistantMessage(reply);
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
          // Just a small emoji badge, not a text label — a full status label
          // here made the actions row wide enough to overflow the AppBar on
          // narrow phones and push the settings button off-screen entirely.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(
              child: Text(switch (variant) {
                null => '🎓',
                LocalModelVariant.friend => localReady ? '👋' : '🚪',
                LocalModelVariant.tutor => localReady ? '📖' : '📕',
              }, style: const TextStyle(fontSize: 18)),
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
        child: Column(
          children: [
            if (showBlockedBanner)
              Builder(
                builder: (context) {
                  // Loading cached weights is a normal, short-lived state —
                  // showing it in alarming red as "model unavailable" would
                  // read like something is broken.
                  final isWakingUp =
                      variant != null &&
                      modelStatus == LocalModelStatus.loading;
                  final color = isWakingUp ? _accentGreen : Colors.red;
                  final personaLabel = variant == null
                      ? ''
                      : personaName(settings, variant);
                  return Container(
                    width: double.infinity,
                    color: color.withValues(alpha: 0.12),
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      isWakingUp
                          ? settings
                                .t('personaWakingUp')
                                .replaceFirst('{name}', personaLabel)
                          : variant != null
                          ? settings
                                .t('personaUnavailable')
                                .replaceFirst('{name}', personaLabel)
                          : settings.t('offlineBanner'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: color),
                    ),
                  );
                },
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (ctx, i) => i < _messages.length
                    ? _MessageBubble(message: _messages[i], settings: settings)
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
              Text(message.text),
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
              if (!message.fromUser)
                Align(
                  alignment: Alignment.centerLeft,
                  child: SpeakButton(text: message.text, size: 20),
                ),
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
