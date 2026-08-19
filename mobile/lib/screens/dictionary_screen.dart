import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../components/speak_button.dart';
import '../models/word.dart';
import 'word_detail_screen.dart';

/// Searchable list of every word the app knows, matching on hanzi, pinyin
/// or the Russian translation.
///
/// Without this, the only way to reach a word is to wait for a lesson to
/// serve it — fine at 75 words, unusable at 260+.
class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final TextEditingController _queryCtl = TextEditingController();
  List<Word>? _all;
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_all == null) _load();
  }

  Future<void> _load() async {
    final words = await context.read<AppRepositories>().words.getAllWords();
    words.sort((a, b) {
      final byLevel = a.hskLevel.compareTo(b.hskLevel);
      return byLevel != 0 ? byLevel : a.pinyin.compareTo(b.pinyin);
    });
    if (!mounted) return;
    setState(() => _all = words);
  }

  @override
  void dispose() {
    _queryCtl.dispose();
    super.dispose();
  }

  /// Pinyin is stored with tone marks ("nǐ hǎo"), which nobody types on a
  /// phone — strip diacritics and spaces on both sides so "nihao", "ni hao"
  /// and "nǐhǎo" all match.
  static String _normalize(String s) {
    const marks = {
      'ā': 'a',
      'á': 'a',
      'ǎ': 'a',
      'à': 'a',
      'ē': 'e',
      'é': 'e',
      'ě': 'e',
      'è': 'e',
      'ī': 'i',
      'í': 'i',
      'ǐ': 'i',
      'ì': 'i',
      'ō': 'o',
      'ó': 'o',
      'ǒ': 'o',
      'ò': 'o',
      'ū': 'u',
      'ú': 'u',
      'ǔ': 'u',
      'ù': 'u',
      'ǖ': 'v',
      'ǘ': 'v',
      'ǚ': 'v',
      'ǜ': 'v',
      'ü': 'v',
    };
    final buffer = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      if (ch == ' ') continue;
      buffer.write(marks[ch] ?? ch);
    }
    return buffer.toString();
  }

  List<Word> get _filtered {
    final all = _all ?? const <Word>[];
    if (_query.trim().isEmpty) return all;
    final q = _normalize(_query);
    return all
        .where(
          (w) =>
              w.hanzi.contains(_query.trim()) ||
              _normalize(w.pinyin).contains(q) ||
              _normalize(w.translationRu).contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final all = _all;
    final results = _filtered;

    return Scaffold(
      appBar: AppBar(title: Text(settings.t('dictionaryTitle'))),
      body: AppBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _queryCtl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: settings.t('dictionarySearchHint'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _queryCtl.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              ),
            ),
            if (all == null)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (results.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/mascot/panda_02.png', height: 120),
                        const SizedBox(height: 12),
                        Text(settings.t('dictionaryNothingFound')),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: results.length,
                  itemBuilder: (ctx, i) {
                    final w = results[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Row(
                          children: [
                            Text(
                              w.hanzi,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                w.pinyin,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontStyle: FontStyle.italic),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(w.translationRu),
                        trailing: SpeakButton(text: w.hanzi, size: 20),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => WordDetailScreen(word: w),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
