import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../models/word.dart';
import '../services/pronunciation_service.dart';
import '../services/speech_service.dart';

enum _Verdict { none, correct, tryAgain }

/// Speak-and-check practice: the learner hears a word, says it back, and
/// the on-device speech recognizer reports what it heard. See
/// [PronunciationService] for what this can and can't actually measure —
/// framed to the learner as "does this sound right" rather than a
/// precise tone score, since that's what it really is.
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
  Word? _current;
  bool? _speechAvailable;
  bool _listening = false;
  String _heard = '';
  _Verdict _verdict = _Verdict.none;
  int _correctCount = 0;
  int _attempts = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_allWords == null) _load();
  }

  Future<void> _load() async {
    final all = await context.read<AppRepositories>().words.getAllWords();
    final available = await PronunciationService.ensureInitialized();
    if (!mounted) return;
    setState(() {
      _allWords = all;
      _speechAvailable = available;
    });
    _nextWord();
  }

  void _nextWord() {
    if (_allWords == null || _allWords!.isEmpty) return;
    setState(() {
      _current = _allWords![_rng.nextInt(_allWords!.length)];
      _heard = '';
      _verdict = _Verdict.none;
    });
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await PronunciationService.stop();
      return;
    }
    setState(() {
      _listening = true;
      _heard = '';
      _verdict = _Verdict.none;
    });
    await PronunciationService.listen(
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _heard = text);
        if (isFinal) _evaluate();
      },
    );
  }

  Future<void> _evaluate() async {
    if (!mounted || _current == null) return;
    final correct =
        _heard.isNotEmpty &&
        PronunciationService.matches(_heard, _current!.hanzi);
    setState(() {
      _listening = false;
      _verdict = correct ? _Verdict.correct : _Verdict.tryAgain;
      _attempts += 1;
      if (correct) _correctCount += 1;
    });
    if (correct) {
      await context.read<AppRepositories>().stats.addXpAndRecordActivity(5);
      await Future<void>.delayed(const Duration(milliseconds: 900));
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
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        settings.t('pronunciationPrompt'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Spacer(),
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
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        word.translationRu,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () =>
                            SpeechService.speak(word.hanzi, rate: 0.35),
                        icon: const Icon(Icons.volume_up_outlined),
                        label: Text(settings.t('listen')),
                      ),
                      const Spacer(),
                      if (_heard.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '${settings.t('pronunciationHeard')}: $_heard',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      if (_verdict != _Verdict.none)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _verdict == _Verdict.correct
                                ? settings.t('pronunciationCorrect')
                                : settings.t('pronunciationTryAgain'),
                            style: TextStyle(
                              color: _verdict == _Verdict.correct
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: _toggleListening,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _listening
                                ? Colors.red
                                : Theme.of(context).colorScheme.primary,
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
