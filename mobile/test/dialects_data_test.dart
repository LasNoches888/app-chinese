import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_chinese/data/dialects.dart';

/// The dialect section is deliberately honest about what it can and can't
/// vouch for (see the doc comments in `data/dialects.dart`): only Mandarin
/// gets audio, and only Mandarin's examples are held to the "only
/// characters the course actually teaches" bar that the rest of the app's
/// content already meets — the other six dialects intentionally show
/// dialect-specific vocabulary (阿拉, 唔該, 涯...) that HSK1 never covers,
/// because that's the whole point of showing them.
void main() {
  group('kDialects', () {
    test('ids are unique', () {
      final ids = kDialects.map((d) => d.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every dialect has real content in every section', () {
      for (final d in kDialects) {
        expect(d.descriptionRu.trim(), isNotEmpty, reason: d.id);
        expect(d.featuresRu, isNotEmpty, reason: d.id);
        expect(d.examples, isNotEmpty, reason: d.id);
        expect(d.cultureTitleRu.trim(), isNotEmpty, reason: d.id);
        expect(d.cultureBodyRu.trim(), isNotEmpty, reason: d.id);
        expect(d.cultureVocab, isNotEmpty, reason: d.id);
        for (final e in [...d.examples, ...d.cultureVocab]) {
          expect(e.hanzi.trim(), isNotEmpty, reason: d.id);
          expect(e.ru.trim(), isNotEmpty, reason: d.id);
        }
      }
    });

    test('only Mandarin claims real audio', () {
      final withAudio = kDialects.where((d) => d.hasAudio).map((d) => d.id);
      expect(withAudio, ['mandarin']);
    });

    test('only Mandarin has a scripted practice dialogue', () {
      final withDialogue = kDialects.where((d) => d.dialogue != null).map((d) => d.id);
      expect(withDialogue, ['mandarin']);
    });

    test(
      "Mandarin's examples and dialogue only use characters the course teaches",
      () async {
        final taught = await _taughtCharacters();
        final mandarin = kDialects.firstWhere((d) => d.id == 'mandarin');
        for (final e in mandarin.examples) {
          final unknown = _unknownHanzi(e.hanzi, taught);
          expect(unknown, isEmpty, reason: e.hanzi);
        }
        for (final line in mandarin.dialogue!) {
          final unknown = _unknownHanzi(line.hanzi, taught);
          expect(unknown, isEmpty, reason: line.hanzi);
        }
      },
    );
  });

  group('kDialectCompareEntries', () {
    test('every row is fully filled in', () {
      expect(kDialectCompareEntries, isNotEmpty);
      for (final e in kDialectCompareEntries) {
        for (final field in [
          e.hanziMandarin,
          e.pinyin,
          e.hanziYue,
          e.jyutping,
          e.hanziMin,
          e.poj,
          e.ru,
          e.tipRu,
        ]) {
          expect(field.trim(), isNotEmpty);
        }
      }
    });
  });
}

Set<String> _unknownHanzi(String text, Set<String> taught) => text
    .split('')
    .where((c) => RegExp(r'[一-鿿]').hasMatch(c))
    .where((c) => !taught.contains(c))
    .toSet();

Future<Set<String>> _taughtCharacters() async {
  final raw = await File('assets/seed/words.json').readAsString();
  final words = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
  return {for (final w in words) ...(w['hanzi'] as String).split('')};
}
