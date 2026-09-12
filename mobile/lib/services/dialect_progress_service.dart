import 'package:shared_preferences/shared_preferences.dart';

/// What a learner can finish inside one dialect's lesson list — kept to the
/// two things every dialect actually has (see `data/dialects.dart`), plus
/// practice for the one dialect that has a scripted dialogue.
enum DialectLessonKind { examples, culture, practice }

/// Tracks which dialect lessons a learner has already opened, so the
/// lessons list can show a real checkmark instead of a static "3 of 8"
/// that isn't backed by anything. Deliberately just a flag per
/// (dialect, lesson kind) in SharedPreferences rather than a new SQLite
/// table — this is enrichment content, not SRS-tracked vocabulary, so
/// there's nothing here that needs querying, joining, or surviving a
/// schema migration.
class DialectProgressService {
  DialectProgressService._();

  static const _key = 'dialect_progress_done';

  static Future<Set<String>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  static String _entryKey(String dialectId, DialectLessonKind kind) =>
      '$dialectId:${kind.name}';

  static Future<bool> isDone(String dialectId, DialectLessonKind kind) async {
    final done = await _load();
    return done.contains(_entryKey(dialectId, kind));
  }

  static Future<Set<DialectLessonKind>> doneKinds(String dialectId) async {
    final done = await _load();
    return {
      for (final kind in DialectLessonKind.values)
        if (done.contains(_entryKey(dialectId, kind))) kind,
    };
  }

  static Future<void> markDone(String dialectId, DialectLessonKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    final done = (prefs.getStringList(_key) ?? const []).toSet();
    done.add(_entryKey(dialectId, kind));
    await prefs.setStringList(_key, done.toList());
  }
}
