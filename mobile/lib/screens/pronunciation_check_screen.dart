import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../models/word.dart';
import '../services/pronunciation_service.dart';
import '../services/speech_service.dart';

/// Speak-and-check practice: the learner hears a word, says it back, and
/// the app grades what the on-device recognizer heard — telling them
/// *which syllable* came out as a different character rather than just
/// "try again". See [PronunciationService] for what this can and can't
/// actually measure.
class PronunciationCheckScreen extends StatefulWidget {
  const PronunciationCheckScreen({super.key});

  @override
  State<PronunciationCheckScreen> createState() =>
      _PronunciationCheckScreenState();
}

class _PronunciationCheckScreenState extends State<PronunciationCheckScreen>
    with StopSpeechOnDispose {
  final _rng = Random();
  List<Word>? _allWords;

  /// Lets the grader tell a homophone or a tone slip apart from a
  /// genuinely wrong word — without a reading for what the recognizer
  /// returned, all it can say is "different characters".
  Map<String, String> _pinyinByHanzi = const {};
  Word? _current;
  bool? _speechAvailable;
  bool _listening = false;
  String _partial = '';
  PronunciationResult? _result;
  int _tries = 0;
  int _correctCount = 0;
  int _attempts = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_allWords == null) _load();
  }

  Future<void> _load() async {
    final repos = context.read<AppRepositories>();
    final all = await repos.words.getAllWords();
    // Weak words first — the ones the learner keeps getting wrong are the
    // ones worth hearing themselves say. Falls back to the full bank for
    // a fresh profile with no review history yet.
    final weakIds = (await repos.srs.getWeakWordIds()).toSet();
    final available = await PronunciationService.ensureInitialized();
    if (!mounted) return;
    final weak = all.where((w) => weakIds.contains(w.id)).toList();
    setState(() {
      _allWords = weak.length >= 5 ? weak : all;
      _pinyinByHanzi = {for (final w in all) w.hanzi: w.pinyin};
      _speechAvailable = available;
    });
    _nextWord();
  }

  void _nextWord() {
    final pool = _allWords;
    if (pool == null || pool.isEmpty) return;
    setState(() {
      _current = pool[_rng.nextInt(pool.length)];
      _partial = '';
      _result = null;
      _tries = 0;
    });
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await PronunciationService.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() {
      _listening = true;
      _partial = '';
      _result = null;
    });
    var graded = false;
    await PronunciationService.listen(
      onResult: (alternates, isFinal) {
        if (!mounted || graded) return;
        setState(() => _partial = alternates.isEmpty ? '' : alternates.first);
        // Don't sit through the trailing silence once the word has clearly
        // been said — the recognizer only finalizes after a pause, which
        // is most of the wait the learner feels.
        final conclusive = PronunciationService.isConclusive(
          alternates: alternates,
          targetHanzi: _current?.hanzi ?? '',
        );
        if (isFinal || conclusive) {
          graded = true;
          if (conclusive && !isFinal) PronunciationService.stop();
          _evaluate(alternates);
        }
      },
    );
  }

  Future<void> _evaluate(List<String> alternates) async {
    final word = _current;
    if (!mounted || word == null) return;
    final result = PronunciationService.grade(
      alternates: alternates,
      targetHanzi: word.hanzi,
      targetPinyin: word.pinyin,
      pinyinByHanzi: _pinyinByHanzi,
    );
    setState(() {
      _listening = false;
      _result = result;
      _tries += 1;
      _attempts += 1;
      if (result.isPass) _correctCount += 1;
    });
    if (result.isPass || result.grade == PronunciationGrade.closeExtraWords) {
      // Full credit for a clean read, a bit less when the recognizer also
      // picked up filler around it.
      final xp = result.isPass ? 5 : 3;
      await context.read<AppRepositories>().stats.addXpAndRecordActivity(xp);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) _nextWord();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final word = _current;
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('pronunciationTitle')),
        actions: [
          if (_attempts > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: Text('$_correctCount/$_attempts')),
            ),
        ],
      ),
      body: AppBackground(
        child: _speechAvailable == false
            ? _UnavailableView(settings: settings)
            : word == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    children: [
                      Text(
                        settings.t('pronunciationPrompt'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        word.hanzi,
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        word.pinyin,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        word.translationRu,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () =>
                            SpeechService.speak(word.hanzi, rate: 0.35),
                        icon: const Icon(Icons.volume_up_outlined),
                        label: Text(settings.t('listen')),
                      ),
                      const SizedBox(height: 16),
                      _FeedbackPanel(
                        settings: settings,
                        result: _result,
                        partial: _partial,
                        listening: _listening,
                        tries: _tries,
                        target: word,
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _toggleListening,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _listening
                                ? Colors.red
                                : Theme.of(context).colorScheme.primary,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (_listening
                                            ? Colors.red
                                            : Theme.of(
                                                context,
                                              ).colorScheme.primary)
                                        .withValues(alpha: 0.4),
                                blurRadius: _listening ? 26 : 12,
                                spreadRadius: _listening ? 5 : 0,
                              ),
                            ],
                          ),
                          child: Icon(
                            _listening ? Icons.stop : Icons.mic,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _listening
                            ? settings.t('pronunciationListening')
                            : settings.t('pronunciationTapToSpeak'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      TextButton(
                        onPressed: _nextWord,
                        child: Text(settings.t('pronunciationSkip')),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Shows what the recognizer heard and, when it's actionable, which
/// syllable to fix.
class _FeedbackPanel extends StatelessWidget {
  final AppSettings settings;
  final PronunciationResult? result;
  final String partial;
  final bool listening;
  final int tries;
  final Word target;

  const _FeedbackPanel({
    required this.settings,
    required this.result,
    required this.partial,
    required this.listening,
    required this.tries,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (listening) {
      return SizedBox(
        height: 72,
        child: Center(
          child: Text(
            partial.isEmpty ? '…' : partial,
            style: theme.textTheme.titleMedium,
          ),
        ),
      );
    }

    final r = result;
    if (r == null) return const SizedBox(height: 72);

    final (color, title) = switch (r.grade) {
      PronunciationGrade.correct => (
        Colors.green,
        settings.t('pronunciationCorrect'),
      ),
      PronunciationGrade.homophone => (
        Colors.green,
        settings.t('pronunciationHomophone'),
      ),
      PronunciationGrade.closeExtraWords => (
        Colors.lightGreen,
        settings.t('pronunciationCloseEnough'),
      ),
      PronunciationGrade.toneMiss => (
        Colors.orange,
        settings.t('pronunciationToneMiss'),
      ),
      PronunciationGrade.wrongWord => (
        Colors.orange,
        settings.t('pronunciationWrongWord'),
      ),
      PronunciationGrade.notHeard => (
        Colors.blueGrey,
        settings.t('pronunciationNotHeard'),
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          if (r.heard.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              r.heardPinyin.isEmpty
                  ? '${settings.t('pronunciationHeard')}: ${r.heard}'
                  : '${settings.t('pronunciationHeard')}: ${r.heard} [${r.heardPinyin}]',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
          // The actionable case: the syllables were right and only the
          // tone slipped, so say so in pinyin — "mǎ вместо mā" is a fix
          // the learner can act on, "wrong word" isn't.
          if (r.grade == PronunciationGrade.toneMiss &&
              r.heardPinyin.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${r.heardPinyin}  →  ${target.pinyin}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
          // Same syllable count but different characters is the closest
          // this can get to "your tone landed on another word" — worth
          // pointing at the exact syllable rather than a generic retry.
          if (r.mistakes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final m in r.mistakes)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${m.heard} → ${m.expected}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              settings.t('pronunciationToneHint'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
          // After a couple of misses, stop guessing and just show the
          // target pinyin broken out — repeating "try again" with no new
          // information is where people give up.
          if (tries >= 2 && !r.isPass) ...[
            const SizedBox(height: 10),
            Text(
              '${settings.t('pronunciationSayLike')}: ${target.pinyin}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnavailableView extends StatelessWidget {
  final AppSettings settings;

  const _UnavailableView({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_off_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              settings.t('pronunciationUnavailable'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
