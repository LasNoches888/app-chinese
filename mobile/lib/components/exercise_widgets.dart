import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stroke_order_animator/stroke_order_animator.dart';

import '../api/app_settings.dart';
import '../models/exercise_question.dart';
import '../services/pinyin.dart';
import 'speak_button.dart';

/// Flashcard flip: tap to reveal, then self-report "know it" / "don't
/// know it" (spec 4.2.1) — no automatic right/wrong grading, the learner
/// judges themselves.
class FlipExerciseWidget extends StatefulWidget {
  final ExerciseQuestion question;
  final AppSettings settings;
  final void Function(bool knewIt) onAnswer;

  const FlipExerciseWidget({
    super.key,
    required this.question,
    required this.settings,
    required this.onAnswer,
  });

  @override
  State<FlipExerciseWidget> createState() => _FlipExerciseWidgetState();
}

class _FlipExerciseWidgetState extends State<FlipExerciseWidget> {
  bool _revealed = false;
  bool _answered = false;

  void _answer(bool knewIt) {
    if (_answered) return;
    _answered = true;
    widget.onAnswer(knewIt);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => setState(() => _revealed = !_revealed),
          child: Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        q.hanzi ?? '',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(width: 8),
                      SpeakButton(text: q.hanzi ?? '', size: 26),
                    ],
                  ),
                  if (_revealed) ...[
                    const SizedBox(height: 12),
                    Text(
                      q.pinyin ?? '',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      q.translation ?? '',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(widget.settings.t('tapToReveal')),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_revealed)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => _answer(false),
                child: Text(widget.settings.t('iDontKnow')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () => _answer(true),
                child: Text(widget.settings.t('iKnowIt')),
              ),
            ],
          ),
      ],
    );
  }
}

/// Multiple-choice: choose-translation (hanzi -> RU) and choose-hanzi
/// (RU -> hanzi), both driven by the same widget since only the prompt
/// and option set differ.
class ChoiceExerciseWidget extends StatefulWidget {
  final ExerciseQuestion question;
  final AppSettings settings;
  final void Function(bool correct) onAnswer;

  const ChoiceExerciseWidget({
    super.key,
    required this.question,
    required this.settings,
    required this.onAnswer,
  });

  @override
  State<ChoiceExerciseWidget> createState() => _ChoiceExerciseWidgetState();
}

class _ChoiceExerciseWidgetState extends State<ChoiceExerciseWidget> {
  String? _selected;
  Timer? _advanceTimer;

  void _select(String option) {
    if (_selected != null) return;
    setState(() => _selected = option);
    final correct = option == widget.question.correctOption;
    _advanceTimer = Timer(const Duration(milliseconds: 550), () {
      if (mounted) widget.onAnswer(correct);
    });
  }

  Color? _colorFor(String option) {
    if (_selected == null) return null;
    if (option == widget.question.correctOption) {
      return Colors.green.withValues(alpha: 0.25);
    }
    if (option == _selected) return Colors.red.withValues(alpha: 0.25);
    return null;
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final promptText = q.type == ExerciseType.chooseTranslation
        ? (q.hanzi ?? '')
        : (q.translation ?? '');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          q.type == ExerciseType.chooseTranslation
              ? widget.settings.t('chooseTranslationPrompt')
              : widget.settings.t('chooseHanziPrompt'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                promptText,
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
            ),
            // Only when the prompt itself is Chinese. In the reverse
            // exercise the prompt is the learner's own language, and the
            // Chinese answer is exactly what they're being asked to recall —
            // playing it here would give the answer away.
            if (q.type == ExerciseType.chooseTranslation) ...[
              const SizedBox(width: 8),
              SpeakButton(text: promptText, size: 26),
            ],
          ],
        ),
        // Once they've answered, the correct hanzi is on screen anyway, so
        // hearing it is the useful part rather than a giveaway.
        if (q.type == ExerciseType.chooseHanzi && _selected != null)
          SpeakButton(text: q.correctOption ?? '', size: 26),
        const SizedBox(height: 24),
        for (final option in q.options ?? const [])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: _colorFor(option),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _select(option),
                child: Text(option, style: const TextStyle(fontSize: 16)),
              ),
            ),
          ),
      ],
    );
  }
}

/// Sentence building: tap tiles (characters) in order to reconstruct the
/// example sentence. No drag-and-drop needed — sequential taps satisfy
/// the spec ("клики... без диктовки").
class BuildSentenceExerciseWidget extends StatefulWidget {
  final ExerciseQuestion question;
  final AppSettings settings;
  final void Function(bool correct) onAnswer;

  const BuildSentenceExerciseWidget({
    super.key,
    required this.question,
    required this.settings,
    required this.onAnswer,
  });

  @override
  State<BuildSentenceExerciseWidget> createState() =>
      _BuildSentenceExerciseWidgetState();
}

class _BuildSentenceExerciseWidgetState
    extends State<BuildSentenceExerciseWidget> {
  late List<String> _remaining;
  final List<String> _selected = [];
  bool _checked = false;
  bool _correct = false;
  Timer? _advanceTimer;

  @override
  void initState() {
    super.initState();
    _remaining = List.of(widget.question.tiles ?? const []);
  }

  void _pick(int index) {
    if (_checked) return;
    setState(() {
      _selected.add(_remaining[index]);
      _remaining.removeAt(index);
    });
  }

  void _unpick(int index) {
    if (_checked) return;
    setState(() {
      _remaining.add(_selected[index]);
      _selected.removeAt(index);
    });
  }

  void _check() {
    final correctOrder = widget.question.correctOrder ?? const [];
    final isCorrect = _selected.join() == correctOrder.join();
    setState(() {
      _checked = true;
      _correct = isCorrect;
    });
    _advanceTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) widget.onAnswer(isCorrect);
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.settings.t('buildSentencePrompt'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        if (widget.question.sentenceTranslation != null)
          Text(
            widget.question.sentenceTranslation!,
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 16),
        Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: _checked
                  ? (_correct ? Colors.green : Colors.red)
                  : Theme.of(context).colorScheme.outlineVariant,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _selected.length; i++)
                ActionChip(
                  label: Text(
                    _selected[i],
                    style: const TextStyle(fontSize: 20),
                  ),
                  onPressed: () => _unpick(i),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < _remaining.length; i++)
              OutlinedButton(
                onPressed: () => _pick(i),
                child: Text(
                  _remaining[i],
                  style: const TextStyle(fontSize: 20),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: (_remaining.isEmpty && !_checked) ? _check : null,
          child: Text(widget.settings.t('check')),
        ),
      ],
    );
  }
}

/// Typed pinyin input. Accepts tone-number notation ("ni3 hao3") or plain
/// pinyin without tones — either is graded correct, so learners aren't
/// blocked by an input method that can't produce diacritics.
class TypePinyinExerciseWidget extends StatefulWidget {
  final ExerciseQuestion question;
  final AppSettings settings;
  final void Function(bool correct) onAnswer;

  const TypePinyinExerciseWidget({
    super.key,
    required this.question,
    required this.settings,
    required this.onAnswer,
  });

  @override
  State<TypePinyinExerciseWidget> createState() =>
      _TypePinyinExerciseWidgetState();
}

class _TypePinyinExerciseWidgetState extends State<TypePinyinExerciseWidget> {
  final _controller = TextEditingController();
  bool _checked = false;
  bool _correct = false;
  Timer? _advanceTimer;

  void _check() {
    // Tones aren't required here — this exercise is about recalling the
    // syllables, and the tone drill/pronunciation check are where tones
    // are actually graded.
    final correct = Pinyin.sameIgnoringTones(
      _controller.text,
      widget.question.correctPinyin ?? '',
    );
    setState(() {
      _checked = true;
      _correct = correct;
    });
    _advanceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) widget.onAnswer(correct);
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.settings.t('typePinyinPrompt'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Text(
          widget.question.hanzi ?? '',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        // Deliberately only offered after checking: the pinyin *is* the
        // answer here, so hearing it read aloud beforehand would turn the
        // exercise into a dictation.
        if (_checked) SpeakButton(text: widget.question.hanzi ?? '', size: 26),
        const SizedBox(height: 20),
        TextField(
          controller: _controller,
          enabled: !_checked,
          textAlign: TextAlign.center,
          autofocus: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: widget.settings.t('typePinyinHint'),
          ),
          onSubmitted: (_) => _check(),
        ),
        if (_checked && !_correct) ...[
          const SizedBox(height: 8),
          Text(
            '${widget.settings.t('correctAnswerIs')}: ${widget.question.correctPinyin}',
            style: const TextStyle(color: Colors.red),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _checked ? null : _check,
          child: Text(widget.settings.t('check')),
        ),
      ],
    );
  }
}

/// Hanzi writing practice: trace the character's strokes in the correct
/// order. Stroke data (assets/seed/stroke_data.json, sourced from Make Me
/// a Hanzi) is bundled offline — [strokeOrderJson] is looked up by the
/// caller and handed in directly.
class WriteHanziExerciseWidget extends StatefulWidget {
  final ExerciseQuestion question;
  final AppSettings settings;
  final String strokeOrderJson;
  final void Function(bool correct) onAnswer;

  const WriteHanziExerciseWidget({
    super.key,
    required this.question,
    required this.settings,
    required this.strokeOrderJson,
    required this.onAnswer,
  });

  @override
  State<WriteHanziExerciseWidget> createState() =>
      _WriteHanziExerciseWidgetState();
}

class _WriteHanziExerciseWidgetState extends State<WriteHanziExerciseWidget>
    with TickerProviderStateMixin {
  late final StrokeOrderAnimationController _controller;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _controller = StrokeOrderAnimationController(
      StrokeOrder(widget.strokeOrderJson),
      this,
      onQuizCompleteCallback: (summary) {
        if (_answered || !mounted) return;
        _answered = true;
        // Up to 2 slips is still a pass — tracing exactly right first try
        // on every stroke is a high bar on a phone touchscreen.
        widget.onAnswer(summary.nTotalMistakes <= 2);
      },
    );
    _controller.startQuiz();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.settings.t('writeHanziPrompt'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(widget.question.translation ?? '', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        // Live stroke progress. Without it the canvas gives no feedback at
        // all until the character is finished — a stroke that didn't
        // register looked identical to one the learner hadn't drawn yet,
        // which is exactly the "it doesn't work" complaint.
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final total = _controller.strokeOrder.nStrokes;
            final done = _controller.currentStroke.clamp(0, total);
            return Column(
              children: [
                Text(
                  '${widget.settings.t('writeStrokeProgress')} $done / $total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    minHeight: 6,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: StrokeOrderAnimator(_controller, size: const Size(260, 260)),
        ),
        const SizedBox(height: 8),
        Text(
          widget.settings.t('writeHanziTip'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _controller.animateHint,
              icon: const Icon(Icons.lightbulb_outline),
              label: Text(widget.settings.t('hint')),
            ),
            TextButton.icon(
              // Restarting the quiz is the escape hatch when a stroke goes
              // badly wrong halfway through a complex character.
              onPressed: () {
                _controller.stopQuiz();
                _controller.startQuiz();
              },
              icon: const Icon(Icons.refresh),
              label: Text(widget.settings.t('writeRestart')),
            ),
          ],
        ),
      ],
    );
  }
}
