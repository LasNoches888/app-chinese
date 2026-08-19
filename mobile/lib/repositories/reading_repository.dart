import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/reading_passage.dart';

/// Curated short reading passages, bundled offline. Coverage-based ranking
/// (matching against the learner's known words) happens in the screen,
/// which already has access to both the word bank and SRS state — this
/// repository just owns the passage text itself.
class ReadingRepository {
  final List<ReadingPassage> _all;

  ReadingRepository._(this._all);

  static Future<ReadingRepository> load() async {
    final raw = await rootBundle.loadString(
      'assets/seed/reading_passages.json',
    );
    final decoded = jsonDecode(raw) as List<dynamic>;
    final passages = decoded
        .map((e) => ReadingPassage.fromJson(e as Map<String, dynamic>))
        .toList();
    return ReadingRepository._(passages);
  }

  List<ReadingPassage> get all => List.unmodifiable(_all);
}
