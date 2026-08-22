import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/app_settings.dart';
import '../app_repositories.dart';
import '../components/app_background.dart';
import '../components/speak_button.dart';
import '../models/dict_entry.dart';
import '../models/word.dart';
import '../services/speech_service.dart';
import 'word_detail_screen.dart';

/// Search across everything the app knows about a word.
///
/// Two sources, deliberately kept apart. The course words come first:
/// they carry hand-checked Russian, examples, stroke order and SRS
/// progress. Below them sits the full CC-CEDICT reference — 124k entries
/// whose Russian is machine-translated, which is why every one of them
/// shows its English original underneath.
class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen>
    with StopSpeechOnDispose {
  final TextEditingController _queryCtl = TextEditingController();
  List<Word>? _all;
  String _query = '';

  List<DictEntry> _entries = const [];
  bool _searchingDict = false;
  Timer? _debounce;

  /// Guards against an earlier, slower query overwriting a later one.
  int _searchGeneration = 0;

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
    _debounce?.cancel();
    _queryCtl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _entries = const [];
        _searchingDict = false;
      });
      return;
    }
    // The reference dictionary is a scan over 124k rows; running it on
    // every keystroke would search six times for a six-letter word.
    _debounce = Timer(const Duration(milliseconds: 220), _searchDictionary);
  }

  Future<void> _searchDictionary() async {
    final query = _query.trim();
    final generation = ++_searchGeneration;
    setState(() => _searchingDict = true);
    final results = await context.read<AppRepositories>().dictionary.search(
      query,
    );
    if (!mounted || generation != _searchGeneration) return;
    setState(() {
      _entries = results;
      _searchingDict = false;
    });
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

  /// Course words already shown above don't need repeating below.
  List<DictEntry> _referenceOnly(List<Word> courseHits) {
    final seen = courseHits.map((w) => w.hanzi).toSet();
    return _entries.where((e) => !seen.contains(e.simplified)).toList();
  }

  void _openEntry(DictEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _EntrySheet(entry: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = Theme.of(context);
    final all = _all;
    final courseHits = _filtered;
    final searching = _query.trim().isNotEmpty;
    final reference = _referenceOnly(courseHits);

    return Scaffold(
      appBar: AppBar(title: Text(settings.t('dictionaryTitle'))),
      body: AppBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _queryCtl,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: settings.t('dictionarySearchHint'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _queryCtl.clear();
                            _onQueryChanged('');
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
            else if (searching &&
                courseHits.isEmpty &&
                reference.isEmpty &&
                !_searchingDict)
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    if (courseHits.isNotEmpty) ...[
                      if (searching)
                        _SectionLabel(settings.t('dictionaryMyWords')),
                      for (final w in courseHits)
                        _WordCard(
                          word: w,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => WordDetailScreen(word: w),
                            ),
                          ),
                        ),
                    ],
                    if (!searching)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          settings.t('dictionaryTypeToSearch'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    if (searching && _searchingDict && reference.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (reference.isNotEmpty) ...[
                      _SectionLabel(settings.t('dictionaryFullDict')),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          settings.t('dictionaryMachineNote'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      for (final e in reference)
                        _EntryCard(entry: e, onTap: () => _openEntry(e)),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 6),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _WordCard extends StatelessWidget {
  final Word word;
  final VoidCallback onTap;

  const _WordCard({required this.word, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      title: Row(
        children: [
          Text(
            word.hanzi,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              word.pinyin,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Text(word.translationRu),
      trailing: SpeakButton(text: word.hanzi, size: 20),
      onTap: onTap,
    ),
  );
}

class _EntryCard extends StatelessWidget {
  final DictEntry entry;
  final VoidCallback onTap;

  const _EntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Row(
          children: [
            Text(
              entry.simplified,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                entry.pinyin,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.russian.isNotEmpty)
              Text(entry.russian, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(
              entry.english,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: SpeakButton(text: entry.simplified, size: 20),
        onTap: onTap,
      ),
    );
  }
}

/// The full text of one reference entry.
///
/// A sheet rather than a screen: there is nothing here to interact with
/// beyond reading it and hearing it, and these entries carry no examples,
/// stroke data or progress to warrant a page of their own.
class _EntrySheet extends StatelessWidget {
  final DictEntry entry;

  const _EntrySheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.simplified,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SpeakButton(text: entry.simplified, size: 30),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              entry.pinyin,
              style: theme.textTheme.titleMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
            if (entry.hasDistinctTraditional) ...[
              const SizedBox(height: 6),
              Text(
                '${settings.t('dictionaryTraditional')}: ${entry.traditional}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            if (entry.russian.isNotEmpty) ...[
              Text(entry.russian, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 12),
            ],
            Text(
              entry.english,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              settings.t('dictionaryMachineNote'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
