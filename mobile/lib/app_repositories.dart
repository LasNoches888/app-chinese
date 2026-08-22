import 'package:sqflite/sqflite.dart';

import 'db/app_database.dart';
import 'repositories/achievements_repository.dart';
import 'repositories/chat_repository.dart';
import 'repositories/dialogue_repository.dart';
import 'repositories/dictionary_repository.dart';
import 'repositories/reading_repository.dart';
import 'repositories/srs_repository.dart';
import 'repositories/stats_repository.dart';
import 'repositories/stroke_data_repository.dart';
import 'repositories/word_repository.dart';

/// Bundles every repository behind one object handed down via Provider,
/// so screens don't each open their own database connection.
class AppRepositories {
  final Database db;
  final WordRepository words;
  final SrsRepository srs;
  final StatsRepository stats;
  final AchievementsRepository achievements;
  final ChatRepository chat;
  final StrokeDataRepository strokeData;
  final DialogueRepository dialogues;
  final ReadingRepository reading;

  /// The 124k-entry reference dictionary. Unlike the others this opens
  /// its own database, and only on first search — unpacking 29 MB at
  /// startup would delay every launch for a screen most sessions never
  /// visit.
  final DictionaryRepository dictionary;

  AppRepositories._(
    this.db,
    this.words,
    this.srs,
    this.stats,
    this.achievements,
    this.chat,
    this.strokeData,
    this.dialogues,
    this.reading,
    this.dictionary,
  );

  /// [overridePath] opens an isolated database instead of the shared
  /// on-disk one — see [AppDatabase.open]. Tests pass an in-memory path so
  /// concurrently-running test files don't contend over a single SQLite
  /// file (seeding writes the whole bundled word bank, so two files racing
  /// on it deadlock rather than just interleaving).
  static Future<AppRepositories> initialize({String? overridePath}) async {
    final db = await AppDatabase.open(overridePath: overridePath);
    final words = WordRepository(db);
    await words.seedIfNeeded();
    final srs = SrsRepository(db);
    final stats = StatsRepository(db);
    final achievements = AchievementsRepository(db, srs, words);
    final chat = ChatRepository(db);
    final strokeData = await StrokeDataRepository.load();
    final dialogues = await DialogueRepository.load();
    final reading = await ReadingRepository.load();
    final dictionary = DictionaryRepository();
    return AppRepositories._(
      db,
      words,
      srs,
      stats,
      achievements,
      chat,
      strokeData,
      dialogues,
      reading,
      dictionary,
    );
  }
}
