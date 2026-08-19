import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../models/dialogue.dart';

/// Curated listening-practice dialogues, bundled offline like stroke data —
/// see [Dialogue] for why these are hand-written rather than generated.
class DialogueRepository {
  final List<Dialogue> _all;

  DialogueRepository._(this._all);

  static Future<DialogueRepository> load() async {
    final raw = await rootBundle.loadString('assets/seed/dialogues.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    final dialogues = decoded
        .map((e) => Dialogue.fromJson(e as Map<String, dynamic>))
        .toList();
    return DialogueRepository._(dialogues);
  }

  List<Dialogue> get all => List.unmodifiable(_all);

  Dialogue random() => _all[Random().nextInt(_all.length)];
}
