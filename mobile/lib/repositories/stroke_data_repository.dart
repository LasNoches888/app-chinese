import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Stroke-order data (strokes + medians per character) for the writing
/// exercise, sourced from Make Me a Hanzi (ARPHIC public license) and
/// pre-filtered at build time to just the characters used in
/// assets/seed/words.json — bundled fully offline, no network fetch.
class StrokeDataRepository {
  final Map<String, Map<String, dynamic>> _byCharacter;

  StrokeDataRepository._(this._byCharacter);

  static Future<StrokeDataRepository> load() async {
    final raw = await rootBundle.loadString('assets/seed/stroke_data.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final byCharacter = decoded.map(
      (key, value) => MapEntry(key, value as Map<String, dynamic>),
    );
    return StrokeDataRepository._(byCharacter);
  }

  bool hasStrokeData(String character) => _byCharacter.containsKey(character);

  Set<String> get availableCharacters => _byCharacter.keys.toSet();

  /// Raw JSON string for one character, ready to hand to
  /// stroke_order_animator's `StrokeOrder(json)` constructor.
  String? strokeOrderJson(String character) {
    final data = _byCharacter[character];
    if (data == null) return null;
    return jsonEncode(data);
  }
}
