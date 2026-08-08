import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../api/app_strings.dart';
import '../models/vocab_card.dart';

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
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _grade(int quality) async {
    final card = _dueCards.first;
    await context.read<AppSettings>().client.reviewCard(cardId: card.id, quality: quality);
    setState(() {
      _dueCards.removeAt(0);
      _showAnswer = false;
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('flashcards')),
        actions: [
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
    if (_dueCards.isEmpty) {
      return Center(child: Text(settings.t('noCardsDue')));
    }

    final card = _dueCards.first;
    final reviewed = _initialDueCount - _dueCards.length;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            '$reviewed/$_initialDueCount ${settings.t('due')}',
            style: Theme.of(context).textTheme.bodySmall,
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

  Widget _gradeButton(String label, int quality, Color color) {
    return FilledButton(
      style: FilledButton.styleFrom(backgroundColor: color),
      onPressed: () => _grade(quality),
      child: Text(label),
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
