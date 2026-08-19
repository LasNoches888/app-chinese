import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stroke_order_animator/stroke_order_animator.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../components/speak_button.dart';
import '../models/word.dart';
import '../repositories/srs_repository.dart';
import '../services/speech_service.dart';
import '../services/srs_service.dart';

/// Everything the app knows about one word in a single place: audio,
/// example sentence, per-character stroke-order playback, and where the
/// word currently sits in the learner's review schedule.
///
/// The stroke animation previously only existed inside the writing
/// exercise, so a learner could never simply look up how a character is
/// written without waiting for it to come up in a lesson.
class WordDetailScreen extends StatefulWidget {
  final Word word;

  const WordDetailScreen({super.key, required this.word});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen>
    with TickerProviderStateMixin, StopSpeechOnDispose {
  WordSrsState? _srsState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_srsState == null) _loadState();
  }

  Future<void> _loadState() async {
    final state = await context.read<AppRepositories>().srs.getState(
      widget.word.id,
    );
    if (!mounted) return;
    setState(() => _srsState = state);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final word = widget.word;
    final strokeData = context.read<AppRepositories>().strokeData;
    final chars = word.hanzi.split('').where(strokeData.hasStrokeData).toList();

    return Scaffold(
      appBar: AppBar(title: Text(word.hanzi)),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      word.hanzi,
                      style: Theme.of(context).textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          word.pinyin,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SpeakButton(text: word.hanzi, size: 26),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.translationRu,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        Chip(
                          label: Text('HSK ${word.hskLevel}'),
                          visualDensity: VisualDensity.compact,
                        ),
                        _StatusChip(state: _srsState, settings: settings),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (word.exampleSentence != null &&
                word.exampleSentence!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                settings.t('wordExample'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              word.exampleSentence!,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (word.exampleTranslation != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(word.exampleTranslation!),
                              ),
                          ],
                        ),
                      ),
                      SpeakButton(text: word.exampleSentence!),
                    ],
                  ),
                ),
              ),
            ],
            if (chars.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                settings.t('wordStrokeOrder'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final ch in chars)
                _StrokeCard(
                  key: ValueKey(ch),
                  strokeOrderJson: strokeData.strokeOrderJson(ch)!,
                  vsync: this,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final WordSrsState? state;
  final AppSettings settings;

  const _StatusChip({required this.state, required this.settings});

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s == null) {
      return const Chip(
        label: SizedBox(
          width: 40,
          height: 12,
          child: LinearProgressIndicator(),
        ),
        visualDensity: VisualDensity.compact,
      );
    }
    final (label, color) = switch (s) {
      _ when SrsService.isLearned(s.repetitions) => (
        settings.t('wordStatusLearned'),
        Colors.green,
      ),
      _ when s.repetitions > 0 => (
        settings.t('wordStatusLearning'),
        Colors.orange,
      ),
      _ => (settings.t('wordStatusNew'), Colors.blueGrey),
    };
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.18),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Replays one character's stroke order on demand. Each card owns its own
/// controller because the animator drives a single character at a time.
class _StrokeCard extends StatefulWidget {
  final String strokeOrderJson;
  final TickerProvider vsync;

  const _StrokeCard({
    super.key,
    required this.strokeOrderJson,
    required this.vsync,
  });

  @override
  State<_StrokeCard> createState() => _StrokeCardState();
}

class _StrokeCardState extends State<_StrokeCard> {
  late final StrokeOrderAnimationController _controller =
      StrokeOrderAnimationController(
        StrokeOrder(widget.strokeOrderJson),
        widget.vsync,
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SizedBox(height: 180, child: StrokeOrderAnimator(_controller)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: _controller.startAnimation,
                ),
                IconButton(
                  icon: const Icon(Icons.replay),
                  onPressed: () {
                    _controller.stopAnimation();
                    _controller.startAnimation();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
