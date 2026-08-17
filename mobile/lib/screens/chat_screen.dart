import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../models/chat_message.dart';
import '../services/connectivity_service.dart';
import '../services/local_llm_service.dart';
import '../services/system_prompt.dart';
import 'settings_screen.dart';

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
    if (settings.chatMode == ChatMode.local) return LocalLlmService.isModelReady;
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
      final knownWords = (await repos.words.getWordsByIds(knownIds)).map((w) => w.hanzi).toList();
      final weakWords = (await repos.words.getWordsByIds(weakIds)).map((w) => w.hanzi).toList();

      final ChatMessage reply;
      if (settings.chatMode == ChatMode.local) {
        final prompt = buildTutorSystemPrompt(hskLevel: 1, knownWords: knownWords, weakWords: weakWords);
        final raw = await LocalLlmService.sendMessage(text, systemPrompt: prompt);
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
      setState(() => _messages.add(ChatMessage(fromUser: false, text: '${settings.t('error')}: $e')));
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
    final isLocal = settings.chatMode == ChatMode.local;
    final localReady = LocalLlmService.isModelReady;
    final canSend = _canSend(settings);
    final showBlockedBanner = isLocal ? !localReady : !_online;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('chatTitle')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Row(
                children: isLocal
                    ? [
                        Text(localReady ? '👋' : '🚪', style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text(settings.t('chatSourceLocal'), style: const TextStyle(fontSize: 12)),
                      ]
                    : [
                        const Text('🎓', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text(
                          _online ? settings.t('online') : settings.t('offline'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _online ? Icons.wifi : Icons.wifi_off,
                          size: 14,
                          color: _online ? Colors.green : Colors.red,
                        ),
                      ],
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _clearHistory),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          if (showBlockedBanner)
            Container(
              width: double.infinity,
              color: Colors.red.withValues(alpha: 0.12),
              padding: const EdgeInsets.all(10),
              child: Text(
                isLocal ? settings.t('localModelUnavailable') : settings.t('offlineBanner'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) => _MessageBubble(message: _messages[i], settings: settings),
            ),
          ),
          if (_sending) const LinearProgressIndicator(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final AppSettings settings;

  const _MessageBubble({required this.message, required this.settings});

  @override
  Widget build(BuildContext context) {
    final align = message.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
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
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
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
            ],
          ),
        ),
        if (!message.fromUser && message.grammarRecast != null && message.grammarRecast!.isNotEmpty)
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
                const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
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
