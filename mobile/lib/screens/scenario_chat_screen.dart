import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../data/scenarios.dart';
import '../models/chat_message.dart';
import '../services/local_llm_service.dart';
import '../services/pinyin_annotator.dart';
import '../services/tutor_fact_checker.dart';
import '../services/system_prompt.dart';

/// A roleplay conversation, deliberately ephemeral: unlike the main tutor
/// chat, nothing here is written to ChatRepository. Persisting it would mix
/// scenario roleplay into the main Xiao Qiao conversation history the
/// learner sees when they go back to regular chat, which isn't what either
/// mode is for.
class ScenarioChatScreen extends StatefulWidget {
  final ChatScenario scenario;

  const ScenarioChatScreen({super.key, required this.scenario});

  @override
  State<ScenarioChatScreen> createState() => _ScenarioChatScreenState();
}

class _ScenarioChatScreenState extends State<ScenarioChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputCtl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // The shared LocalLlmService session is keyed to whichever system
    // prompt created it — if the learner already chatted with the regular
    // tutor this app run, that session (and its tutor persona) is still
    // live. Dropping it here forces a fresh session with this scenario's
    // roleplay prompt instead of silently ignoring it.
    LocalLlmService.resetSession();
    _messages.add(
      ChatMessage(fromUser: false, text: widget.scenario.openingLineZh),
    );
  }

  @override
  void dispose() {
    // Symmetric with initState: leaving the scenario must not leave its
    // roleplay persona active for the next normal tutor message.
    LocalLlmService.resetSession();
    _inputCtl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(ChatMessage(fromUser: true, text: text));
      _sending = true;
      _inputCtl.clear();
    });

    final settings = context.read<AppSettings>();
    final repos = context.read<AppRepositories>();
    final annotator = PinyinAnnotator(repos.dictionary, repos.words);
    try {
      final prompt = buildScenarioSystemPrompt(
        role: widget.scenario.role,
        topicHintRu: widget.scenario.topicHintRu,
        openingLineZh: widget.scenario.openingLineZh,
      );
      final raw = await LocalLlmService.sendMessage(
        LocalModelVariant.tutor,
        text,
        systemPrompt: prompt,
      );
      final json = LocalLlmService.extractReplyJson(raw);
      final reply = json != null
          ? ChatMessage.fromReplyJson(json)
          : ChatMessage(fromUser: false, text: raw);
      // Same reason as the main chat: the model's characters are worth
      // trusting, its transcription is not.
      final corrected = await annotator.correct(reply);
      final checked = await TutorFactChecker(repos.dictionary).check(corrected);
      if (!mounted) return;
      setState(() => _messages.add(checked.message));
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.scenario.emoji} ${widget.scenario.titleRu}'),
      ),
      body: AppBackground(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (ctx, i) => _ScenarioBubble(message: _messages[i]),
              ),
            ),
            if (_sending) const LinearProgressIndicator(),
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
                        enabled: !_sending,
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
                      onPressed: _sending ? null : _send,
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

class _ScenarioBubble extends StatelessWidget {
  final ChatMessage message;

  const _ScenarioBubble({required this.message});

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
            ],
          ),
        ),
      ],
    );
  }
}
