import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../models/dialogue.dart';
import '../services/speech_service.dart';

/// Listen-then-comprehend practice.
///
/// The transcript stays hidden until the learner has answered (or
/// explicitly gives up and taps "show the transcript"): revealing each
/// line — hanzi, pinyin *and* the Russian translation — as it played, the
/// way this screen used to, turned the whole exercise into reading with
/// audio in the background. You could answer every question without
/// hearing a thing.
class ListeningScreen extends StatefulWidget {
  /// A specific dialogue to practice; null picks a random one, which is
  /// what the "random dialogue" entry in the picker does.
  final Dialogue? dialogue;

  const ListeningScreen({super.key, this.dialogue});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen>
    with StopSpeechOnDispose {
  late Dialogue _dialogue;
  bool _initialized = false;
  bool _playing = false;
  int _replays = 0;
  int? _selectedOption;
  bool _revealed = false;

  /// Whether the dialogue has played through at least once. The answer
  /// options stay locked until it has: showing the question up front is
  /// useful (you know what to listen for), but leaving it *answerable*
  /// during playback let you tap straight through without hearing
  /// anything — and made a stray tap end the exercise.
  bool _heardOnce = false;

  /// Bumped whenever playback should be abandoned — leaving the screen, or
  /// restarting with a new dialogue. A running [_playAll] loop compares
  /// against it and bails, so a stale loop can't keep speaking lines over
  /// whatever replaced it.
  int _playbackGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _dialogue =
          widget.dialogue ?? context.read<AppRepositories>().dialogues.random();
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _playAll());
    }
  }

  @override
  void dispose() {
    _playbackGeneration++;
    super.dispose();
  }

  Future<void> _playAll() async {
    // Autoplay is scheduled from a post-frame callback, so the screen can
    // already be gone by the time it runs (open listening, immediately
    // press back) — setState on a dead State throws.
    if (!mounted) return;
    final generation = ++_playbackGeneration;
    setState(() {
      _playing = true;
      _replays++;
    });
    for (final line in _dialogue.lines) {
      if (!mounted || generation != _playbackGeneration) return;
      // Both speakers used one identical voice, which made a two-person
      // exchange genuinely hard to follow now that the transcript is
      // hidden — you couldn't tell where A stopped and B started.
      await SpeechService.speak(
        line.hanzi,
        rate: 0.45,
        pitch: line.speaker == 'A' ? 0.92 : 1.12,
      );
      // speak() returns once playback *starts*, not once it finishes — a
      // fixed pause per line is a rough stand-in for "wait for it to end"
      // since flutter_tts's completion callback is already wired to
      // SpeechService.speaking, which a rapid loop here would race against.
      await Future<void>.delayed(
        Duration(milliseconds: 900 + line.hanzi.length * 260),
      );
    }
    if (mounted && generation == _playbackGeneration) {
      setState(() {
        _playing = false;
        _heardOnce = true;
      });
    }
  }

  Future<void> _pickOption(int index) async {
    if (_selectedOption != null) return;
    setState(() {
      _selectedOption = index;
      _revealed = true;
    });
    if (index == _dialogue.correctIndex) {
      // Listening awarded nothing at all before — the one practice mode
      // that didn't count toward XP or the daily streak.
      await context.read<AppRepositories>().stats.addXpAndRecordActivity(8);
    }
  }

  void _restart() {
    final repos = context.read<AppRepositories>();
    setState(() {
      _dialogue = repos.dialogues.random(excludingId: _dialogue.id);
      _selectedOption = null;
      _revealed = false;
      _replays = 0;
      _heardOnce = false;
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
    final answered = _selectedOption != null;
    // Peeking at the transcript also unlocks answering — someone who
    // chose to read it shouldn't be stuck unable to continue.
    final canAnswer = _heardOnce || _revealed;

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
            _PlayerCard(
              playing: _playing,
              replays: _replays,
              lineCount: _dialogue.lines.length,
              settings: settings,
              onPlay: _playing ? null : _playAll,
            ),
            const SizedBox(height: 20),
            if (!_revealed) ...[
              _HiddenTranscript(settings: settings),
              const SizedBox(height: 16),
            ] else
              for (final line in _dialogue.lines) _LineBubble(line: line),
            const SizedBox(height: 8),
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
                    onPressed: (answered || !canAnswer)
                        ? null
                        : () => _pickOption(i),
                    child: Text(_dialogue.options[i]),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (answered) ...[
              Text(
                _selectedOption == _dialogue.correctIndex
                    ? '${settings.t('listeningCorrect')}  +8 XP'
                    : settings.t('listeningWrong'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _selectedOption == _dialogue.correctIndex
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _restart,
                  child: Text(settings.t('listeningNext')),
                ),
              ),
            ] else
              // Peeking is allowed but deliberately separate from
              // answering, so "I gave up and read it" never looks like a
              // comprehension win.
              TextButton.icon(
                onPressed: () => setState(() => _revealed = true),
                icon: const Icon(Icons.visibility_outlined),
                label: Text(settings.t('listeningShowText')),
              ),
          ],
        ),
      ),
    );
  }
}

/// The play control — the main affordance now that there's nothing to read
/// while the audio runs.
class _PlayerCard extends StatelessWidget {
  final bool playing;
  final int replays;
  final int lineCount;
  final AppSettings settings;
  final VoidCallback? onPlay;

  const _PlayerCard({
    required this.playing,
    required this.replays,
    required this.lineCount,
    required this.settings,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.14),
            theme.colorScheme.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onPlay,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: playing
                    ? theme.colorScheme.primary.withValues(alpha: 0.55)
                    : theme.colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    blurRadius: playing ? 24 : 12,
                    spreadRadius: playing ? 4 : 0,
                  ),
                ],
              ),
              child: Icon(
                playing ? Icons.graphic_eq : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            playing
                ? settings.t('listeningPlaying')
                : settings.t('listeningTapPlay'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '$lineCount ${settings.t('listeningLines')} · '
            '${settings.t('listeningReplaysUsed').replaceFirst('{count}', '$replays')}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _HiddenTranscript extends StatelessWidget {
  final AppSettings settings;

  const _HiddenTranscript({required this.settings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.visibility_off_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            settings.t('listeningHiddenHint'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
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
