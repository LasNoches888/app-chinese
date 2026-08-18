import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stroke_order_animator/stroke_order_animator.dart';

import '../api/app_settings.dart';
import '../models/exercise_question.dart';

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
                  Text(
                    q.hanzi ?? '',
                    style: Theme.of(context).textTheme.displaySmall,
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
        Text(
          promptText,
          style: Theme.of(context).textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
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

  static const _toneMarks = {
    'ā': 'a1',
    'á': 'a2',
    'ǎ': 'a3',
    'à': 'a4',
    'ē': 'e1',
    'é': 'e2',
    'ě': 'e3',
    'è': 'e4',
    'ī': 'i1',
    'í': 'i2',
    'ǐ': 'i3',
    'ì': 'i4',
    'ō': 'o1',
    'ó': 'o2',
    'ǒ': 'o3',
    'ò': 'o4',
    'ū': 'u1',
    'ú': 'u2',
    'ǔ': 'u3',
    'ù': 'u4',
    'ǖ': 'v1',
    'ǘ': 'v2',
    'ǚ': 'v3',
    'ǜ': 'v4',
  };

  /// Normalizes both tone-mark and tone-number pinyin to a comparable
  /// plain form, stripping tone digits entirely so either notation (or no
  /// tones at all) is accepted.
  String _normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      final mapped = _toneMarks[ch];
      buffer.write(mapped != null ? mapped[0] : ch);
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'[0-9]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _check() {
    final correct =
        _normalize(_controller.text) ==
        _normalize(widget.question.correctPinyin ?? '');
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.settings.t('writeHanziPrompt'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(widget.question.translation ?? '', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: StrokeOrderAnimator(_controller, size: const Size(260, 260)),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _controller.animateHint,
          icon: const Icon(Icons.lightbulb_outline),
          label: Text(widget.settings.t('hint')),
        ),
      ],
    );
  }
}
