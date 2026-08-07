import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../models/vocab_card.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  List<VocabCard> _dueCards = [];
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
    final client = context.read<AppSettings>().client;
    final wordCtl = TextEditingController();
    final pinyinCtl = TextEditingController();
    final translationCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add word'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: wordCtl, decoration: const InputDecoration(labelText: 'Word (汉字)')),
            TextField(controller: pinyinCtl, decoration: const InputDecoration(labelText: 'Pinyin')),
            TextField(controller: translationCtl, decoration: const InputDecoration(labelText: 'Translation')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('Error: $_error', textAlign: TextAlign.center));
    }
    if (_dueCards.isEmpty) {
      return const Center(child: Text('No cards due. 太好了! 🎉'));
    }

    final card = _dueCards.first;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('${_dueCards.length} due', style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _showAnswer = !_showAnswer),
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(card.word, style: Theme.of(context).textTheme.displaySmall),
                    if (_showAnswer) ...[
                      const SizedBox(height: 12),
                      Text(card.pinyin, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(card.translation, style: Theme.of(context).textTheme.bodyLarge),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text('Tap to reveal'),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          if (_showAnswer)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _gradeButton('Again', 0, Colors.red),
                _gradeButton('Hard', 3, Colors.orange),
                _gradeButton('Good', 4, Colors.green),
                _gradeButton('Easy', 5, Colors.blue),
              ],
            ),
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
