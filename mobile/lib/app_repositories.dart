import 'package:sqflite/sqflite.dart';

import 'db/app_database.dart';
import 'repositories/achievements_repository.dart';
import 'repositories/chat_repository.dart';
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

  AppRepositories._(
    this.db,
    this.words,
    this.srs,
    this.stats,
    this.achievements,
    this.chat,
    this.strokeData,
  );

  static Future<AppRepositories> initialize() async {
    final db = await AppDatabase.open();
    final words = WordRepository(db);
    await words.seedIfNeeded();
    final srs = SrsRepository(db);
    final stats = StatsRepository(db);
    final achievements = AchievementsRepository(db, srs, words);
    final chat = ChatRepository(db);
    final strokeData = await StrokeDataRepository.load();
    return AppRepositories._(db, words, srs, stats, achievements, chat, strokeData);
  }
}
