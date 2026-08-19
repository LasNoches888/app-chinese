import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../components/flip_tile.dart';

class _MemoryCard {
  final String wordId;
  final bool isHanziSide;
  final String text;

  const _MemoryCard({
    required this.wordId,
    required this.isHanziSide,
    required this.text,
  });
}

/// Classic pairs-matching game: flip two cards, keep them face up if they're
/// the same word's hanzi and translation, flip both back down otherwise.
/// A different interaction shape from every other exercise in the app
/// (spatial recall + tap-tap pairing) rather than another
/// read-a-prompt-pick-an-answer screen.
class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({super.key});

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  static const _pairCount = 6;

  List<_MemoryCard>? _cards;
  final Set<int> _faceUp = {};
  final Set<int> _matched = {};
  int _moves = 0;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cards == null) _load();
  }

  Future<void> _load() async {
    final all = await context.read<AppRepositories>().words.getAllWords();
    all.shuffle(Random());
    final chosen = all.take(_pairCount).toList();
    final cards = <_MemoryCard>[
      for (final w in chosen) ...[
        _MemoryCard(wordId: w.id, isHanziSide: true, text: w.hanzi),
        _MemoryCard(wordId: w.id, isHanziSide: false, text: w.translationRu),
      ],
    ]..shuffle(Random());
    if (!mounted) return;
    setState(() => _cards = cards);
  }

  Future<void> _tap(int index) async {
    if (_busy || _faceUp.contains(index) || _matched.contains(index)) return;
    setState(() => _faceUp.add(index));
    if (_faceUp.length < 2) return;

    _busy = true;
    _moves++;
    final indices = _faceUp.toList();
    final a = _cards![indices[0]];
    final b = _cards![indices[1]];
    final isMatch = a.wordId == b.wordId && a.isHanziSide != b.isHanziSide;

    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    setState(() {
      if (isMatch) {
        _matched.addAll(indices);
      }
      _faceUp.clear();
      _busy = false;
    });

    if (_matched.length == _cards!.length) await _finish();
  }

  Future<void> _finish() async {
    final settings = context.read<AppSettings>();
    // Perfect play takes exactly one move per pair; every extra move (a
    // mismatch) trims the reward, floored so a messy win still pays out.
    final extraMoves = (_moves - _pairCount).clamp(0, _pairCount * 2);
    final xp = (_pairCount * 2 - extraMoves).clamp(_pairCount, _pairCount * 2);
    await context.read<AppRepositories>().stats.addXpAndRecordActivity(xp);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(settings.t('memoryMatchDone')),
        content: Text('${settings.t('memoryMatchMoves')}: $_moves\n+$xp XP'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(settings.t('continueLabel')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final cards = _cards;
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('memoryMatchTitle')),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text('${settings.t('memoryMatchMoves')}: $_moves'),
            ),
          ),
        ],
      ),
      body: AppBackground(
        child: cards == null
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (ctx, i) {
                    final isUp = _faceUp.contains(i) || _matched.contains(i);
                    return FlipTile(
                      key: ValueKey(i),
                      faceUp: isUp,
                      onTap: () => _tap(i),
                      back: _CardFace(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: const Icon(Icons.help_outline, size: 28),
                      ),
                      front: _CardFace(
                        color: _matched.contains(i)
                            ? Colors.green.withValues(alpha: 0.25)
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        child: Text(
                          cards[i].text,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: cards[i].isHanziSide ? 22 : 13,
                            fontWeight: cards[i].isHanziSide
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final Color color;
  final Widget child;

  const _CardFace({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      child: child,
    );
  }
}
