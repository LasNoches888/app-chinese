import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../models/dialogue.dart';
import '../services/speech_service.dart';

/// Listen-then-comprehend practice: plays a short two-speaker dialogue line
/// by line (revealing the transcript as each line is spoken so it can't be
/// read ahead of the audio), then asks one comprehension question.
class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen>
    with StopSpeechOnDispose {
  late Dialogue _dialogue;
  int _revealedLines = 0;
  bool _playing = false;
  int? _selectedOption;

  /// Bumped whenever playback should be abandoned — leaving the screen, or
  /// restarting with a new dialogue. A running [_playAll] loop compares
  /// against it and bails, so a stale loop can't keep speaking lines (or
  /// revealing them) over whatever replaced it.
  int _playbackGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _dialogue = context.read<AppRepositories>().dialogues.random();
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _playAll());
    }
  }

  bool _initialized = false;

  @override
  void dispose() {
    _playbackGeneration++;
    super.dispose();
  }

  Future<void> _playAll() async {
    final generation = ++_playbackGeneration;
    setState(() {
      _playing = true;
      _revealedLines = 0;
    });
    for (final line in _dialogue.lines) {
      if (!mounted || generation != _playbackGeneration) return;
      setState(() => _revealedLines++);
      await SpeechService.speak(line.hanzi, rate: 0.45);
      // speak() returns once playback *starts*, not once it finishes — a
      // fixed pause per line is a rough stand-in for "wait for it to end"
      // since flutter_tts's completion callback is already wired to
      // SpeechService.speaking, which a rapid loop here would race against.
      await Future<void>.delayed(
        Duration(milliseconds: 900 + line.hanzi.length * 260),
      );
    }
    if (mounted && generation == _playbackGeneration) {
      setState(() => _playing = false);
    }
  }

  void _pickOption(int index) {
    if (_selectedOption != null) return;
    setState(() => _selectedOption = index);
  }

  void _restart() {
    final repos = context.read<AppRepositories>();
    setState(() {
      _dialogue = repos.dialogues.random();
      _revealedLines = 0;
      _selectedOption = null;
    });
    _playAll();
  }

  Color? _optionColor(int index) {
    if (_selectedOption == null) return null;
    if (index == _dialogue.correctIndex) {
      return Colors.green.withValues(alpha: 0.25);
    }
    if (index == _selectedOption) return Colors.red.withValues(alpha: 0.25);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final showQuestion = !_playing && _revealedLines == _dialogue.lines.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('listeningTitle')),
        actions: [
          IconButton(
            icon: const Icon(Icons.replay),
            tooltip: settings.t('listeningReplay'),
            onPressed: _playing ? null : _playAll,
          ),
        ],
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (var i = 0; i < _revealedLines; i++)
              _LineBubble(line: _dialogue.lines[i]),
            if (showQuestion) ...[
              const SizedBox(height: 16),
              Text(
                _dialogue.question,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _dialogue.options.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _optionColor(i),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _pickOption(i),
                      child: Text(_dialogue.options[i]),
                    ),
                  ),
                ),
              if (_selectedOption != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _restart,
                    child: Text(settings.t('listeningNext')),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _LineBubble extends StatelessWidget {
  final DialogueLine line;

  const _LineBubble({required this.line});

  @override
  Widget build(BuildContext context) {
    final isA = line.speaker == 'A';
    return Align(
      alignment: isA ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isA
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line.hanzi),
            Text(
              line.pinyin,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              line.translationRu,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
