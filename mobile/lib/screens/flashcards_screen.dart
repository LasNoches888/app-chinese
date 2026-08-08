import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../api/app_strings.dart';
import '../models/deck.dart';
import '../models/vocab_card.dart';

enum _PracticeMode { flip, quiz }

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  List<VocabCard> _dueCards = [];
  int _initialDueCount = 0;
  bool _loading = true;
  bool _showAnswer = false;
  String? _error;
  int _hearts = 5;
  _PracticeMode _mode = _PracticeMode.flip;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cards = await context.read<AppSettings>().client.fetchDueCards();
      setState(() {
        _dueCards = cards;
        _initialDueCount = cards.length;
        _loading = false;
        _showAnswer = false;
        _hearts = 5;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _grade(int quality) async {
    final settings = context.read<AppSettings>();
    final card = _dueCards.first;
    await settings.client.reviewCard(cardId: card.id, quality: quality);
    final xp = quality >= 3 ? 10 : 2;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('+$xp ${settings.t('xpGained')}'), duration: const Duration(milliseconds: 900)),
    );
    setState(() {
      _dueCards.removeAt(0);
      _showAnswer = false;
      if (quality < 3) _hearts = (_hearts - 1).clamp(0, 5);
    });
  }

  Future<void> _showAddDialog() async {
    final settings = context.read<AppSettings>();
    final client = settings.client;
    final wordCtl = TextEditingController();
    final pinyinCtl = TextEditingController();
    final translationCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(settings.t('addWord')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: wordCtl, decoration: InputDecoration(labelText: settings.t('word'))),
            TextField(controller: pinyinCtl, decoration: InputDecoration(labelText: settings.t('pinyin'))),
            TextField(
              controller: translationCtl,
              decoration: InputDecoration(labelText: settings.t('translation')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(settings.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(settings.t('add'))),
        ],
      ),
    );
    if (ok == true && wordCtl.text.trim().isNotEmpty) {
      await client.addCard(
        word: wordCtl.text.trim(),
        pinyin: pinyinCtl.text.trim(),
        translation: translationCtl.text.trim(),
      );
      _refresh();
    }
  }

  Future<void> _showDeckPicker() async {
    final settings = context.read<AppSettings>();
    final client = settings.client;
    List<DeckSummary> decks;
    try {
      decks = await client.fetchDecks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${settings.t('error')}: $e')));
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(settings.t('themes'), style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final deck in decks)
              ListTile(
                title: Text(deck.name),
                subtitle: Text('${deck.wordCount} ${settings.t('wordsUnit')}'),
                trailing: FilledButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final added = await client.importDeck(deck.id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${settings.t('deckAdded')}: $added')),
                    );
                    _refresh();
                  },
                  child: Text(settings.t('addDeck')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('flashcards')),
        actions: [
          IconButton(icon: const Icon(Icons.category), onPressed: _showDeckPicker),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog),
        ],
      ),
      body: _buildBody(settings),
    );
  }

  Widget _buildBody(AppSettings settings) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('${settings.t('error')}: $_error', textAlign: TextAlign.center));
    }
    if (_hearts == 0) return _buildOutOfHearts(settings);
    if (_dueCards.isEmpty) {
      return Center(child: Text(settings.t('noCardsDue')));
    }
    return _mode == _PracticeMode.quiz ? _buildQuiz(settings) : _buildFlip(settings);
  }

  Widget _buildOutOfHearts(AppSettings settings) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_border, size: 64, color: Colors.red),
            const SizedBox(height: 12),
            Text(settings.t('outOfHearts'), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() => _hearts = 5),
              child: Text(settings.t('restart')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlip(AppSettings settings) {
    final card = _dueCards.first;
    final reviewed = _initialDueCount - _dueCards.length;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _TopBar(
            settings: settings,
            mode: _mode,
            onModeChanged: (m) => setState(() => _mode = m),
            hearts: _hearts,
            reviewed: reviewed,
            total: _initialDueCount,
          ),
          const Spacer(),
          _FlipCard(
            key: ValueKey(card.id),
            card: card,
            frontSide: settings.cardFrontSide,
            showBack: _showAnswer,
            onTap: () => setState(() => _showAnswer = !_showAnswer),
            tapHint: settings.t('tapToReveal'),
            onSwipeGood: _showAnswer ? () => _grade(4) : null,
            onSwipeAgain: _showAnswer ? () => _grade(0) : null,
          ),
          const Spacer(),
          if (_showAnswer) ...[
            Text(
              settings.t('swipeHint'),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _gradeButton(settings.t('again'), 0, Colors.red),
                _gradeButton(settings.t('hard'), 3, Colors.orange),
                _gradeButton(settings.t('good'), 4, Colors.green),
                _gradeButton(settings.t('easy'), 5, Colors.blue),
              ],
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuiz(AppSettings settings) {
    final card = _dueCards.first;
    final reviewed = _initialDueCount - _dueCards.length;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _TopBar(
            settings: settings,
            mode: _mode,
            onModeChanged: (m) => setState(() => _mode = m),
            hearts: _hearts,
            reviewed: reviewed,
            total: _initialDueCount,
          ),
          const SizedBox(height: 32),
          _QuizCard(
            key: ValueKey(card.id),
            card: card,
            pool: _dueCards,
            onAnswered: (correct) => _grade(correct ? 4 : 1),
          ),
        ],
      ),
    );
  }

  Widget _gradeButton(String label, int quality, Color color) {
    return FilledButton(
      style: FilledButton.styleFrom(backgroundColor: color),
      onPressed: () => _grade(quality),
      child: Text(label),
    );
  }
}

class _TopBar extends StatelessWidget {
  final AppSettings settings;
  final _PracticeMode mode;
  final ValueChanged<_PracticeMode> onModeChanged;
  final int hearts;
  final int reviewed;
  final int total;

  const _TopBar({
    required this.settings,
    required this.mode,
    required this.onModeChanged,
    required this.hearts,
    required this.reviewed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < hearts ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red,
                  size: 20,
                ),
              ),
            ),
            SegmentedButton<_PracticeMode>(
              segments: [
                ButtonSegment(value: _PracticeMode.flip, label: Text(settings.t('flashcardsMode'))),
                ButtonSegment(value: _PracticeMode.quiz, label: Text(settings.t('quizMode'))),
              ],
              selected: {mode},
              onSelectionChanged: (s) => onModeChanged(s.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('$reviewed/$total ${settings.t('due')}', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _QuizCard extends StatefulWidget {
  final VocabCard card;
  final List<VocabCard> pool;
  final ValueChanged<bool> onAnswered;

  const _QuizCard({super.key, required this.card, required this.pool, required this.onAnswered});

  @override
  State<_QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<_QuizCard> {
  late final List<String> _options;
  String? _selected;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _options = _buildOptions();
  }

  List<String> _buildOptions() {
    final others = widget.pool
        .where((c) => c.id != widget.card.id)
        .map((c) => c.translation)
        .toSet()
        .toList()
      ..shuffle();
    final options = <String>{widget.card.translation, ...others.take(3)}.toList();
    options.shuffle();
    return options;
  }

  void _select(String option) {
    if (_answered) return;
    setState(() {
      _selected = option;
      _answered = true;
    });
    final correct = option == widget.card.translation;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) widget.onAnswered(correct);
    });
  }

  Color? _colorFor(String option) {
    if (!_answered) return null;
    if (option == widget.card.translation) return Colors.green.withValues(alpha: 0.35);
    if (option == _selected) return Colors.red.withValues(alpha: 0.35);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(widget.card.word, style: Theme.of(context).textTheme.displaySmall),
          ),
        ),
        const SizedBox(height: 24),
        for (final option in _options)
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
                child: Text(option),
              ),
            ),
          ),
      ],
    );
  }
}

class _FlipCard extends StatefulWidget {
  final VocabCard card;
  final CardFrontSide frontSide;
  final bool showBack;
  final VoidCallback onTap;
  final String tapHint;
  final VoidCallback? onSwipeGood;
  final VoidCallback? onSwipeAgain;

  const _FlipCard({
    super.key,
    required this.card,
    required this.frontSide,
    required this.showBack,
    required this.onTap,
    required this.tapHint,
    this.onSwipeGood,
    this.onSwipeAgain,
  });

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragDx = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    if (widget.showBack) _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant _FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showBack != oldWidget.showBack) {
      widget.showBack ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hanziFirst = widget.frontSide == CardFrontSide.hanzi;
    final frontFace = hanziFirst ? _hanziFace() : _translationFace();
    final backFace = hanziFirst ? _translationFace(withPinyin: true) : _hanziFace(withPinyin: true);

    return GestureDetector(
      onTap: widget.onTap,
      onHorizontalDragUpdate: (details) => setState(() => _dragDx += details.delta.dx),
      onHorizontalDragEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond.dx;
        if (_dragDx > 80 || velocity > 600) {
          widget.onSwipeGood?.call();
        } else if (_dragDx < -80 || velocity < -600) {
          widget.onSwipeAgain?.call();
        }
        setState(() => _dragDx = 0);
      },
      child: Transform.translate(
        offset: Offset(_dragDx * 0.3, 0),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final angle = _controller.value * pi;
            final isBack = _controller.value >= 0.5;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(isBack ? angle - pi : angle),
              child: isBack ? backFace : frontFace,
            );
          },
        ),
      ),
    );
  }

  Widget _hanziFace({bool withPinyin = false}) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.card.word, style: Theme.of(context).textTheme.displaySmall),
            if (withPinyin) ...[
              const SizedBox(height: 8),
              Text(widget.card.pinyin, style: Theme.of(context).textTheme.titleMedium),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(widget.tapHint),
              ),
          ],
        ),
      ),
    );
  }

  Widget _translationFace({bool withPinyin = false}) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.card.translation, style: Theme.of(context).textTheme.headlineSmall),
            if (withPinyin) ...[
              const SizedBox(height: 8),
              Text(widget.card.pinyin, style: Theme.of(context).textTheme.titleMedium),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(widget.tapHint),
              ),
          ],
        ),
      ),
    );
  }
}
