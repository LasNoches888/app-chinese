import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import '../models/dialogue.dart';

/// Curated listening-practice dialogues, bundled offline like stroke data —
/// see [Dialogue] for why these are hand-written rather than generated.
class DialogueRepository {
  final List<Dialogue> _all;

  DialogueRepository._(this._all);

  /// Builds a repository over a fixed list, so selection behaviour can be
  /// tested against a known set rather than whatever ships in the assets.
  @visibleForTesting
  factory DialogueRepository.forTest(List<Dialogue> dialogues) =>
      DialogueRepository._(dialogues);

  static Future<DialogueRepository> load() async {
    final raw = await rootBundle.loadString('assets/seed/dialogues.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    final dialogues = decoded
        .map((e) => Dialogue.fromJson(e as Map<String, dynamic>))
        .toList();
    return DialogueRepository._(dialogues);
  }

  List<Dialogue> get all => List.unmodifiable(_all);

  /// A random dialogue, never the one identified by [excludingId] unless
  /// that's the only one there is — "next dialogue" handing back the
  /// exercise just finished reads as the button being broken.
  Dialogue random({String? excludingId}) {
    final pool = excludingId == null
        ? _all
        : _all.where((d) => d.id != excludingId).toList();
    final from = pool.isEmpty ? _all : pool;
    return from[Random().nextInt(from.length)];
  }
}
