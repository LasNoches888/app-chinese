import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Opens (and migrates) the local SQLite database. Everything the app
/// needs to function for learning — words, decks, SRS history, XP/streak
/// state, achievements, chat history — lives here. No backend is required
/// for any of it; the backend is only ever consulted for `/chat`.
class AppDatabase {
  static const _dbName = 'app_chinese.db';
  static const _schemaVersion = 4;

  static Database? _instance;

  /// Opens the app's database, reusing one shared connection.
  ///
  /// [overridePath] opens a separate database at that path instead, and is
  /// deliberately not cached. Tests that need to *mutate* content (rather
  /// than just read it) use this: `flutter test` runs test files
  /// concurrently, and they'd otherwise all share the one on-disk
  /// app_chinese.db, so a file that clears a table can yank the data out
  /// from under an unrelated test mid-run.
  static Future<Database> open({String? overridePath}) async {
    if (overridePath == null && _instance != null) return _instance!;
    // Go through the *current* databaseFactory explicitly rather than the
    // bare top-level getDatabasesPath()/openDatabase() facade functions —
    // those don't reliably follow a reassigned databaseFactory (e.g.
    // sqflite_common_ffi in tests) and end up hitting a real platform
    // channel that has nothing to answer it.
    final path =
        overridePath ?? join(await databaseFactory.getDatabasesPath(), _dbName);
    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onCreate: _onCreate,
        // Future schema changes go here as `if (oldVersion < N) { ... }`
        // blocks so existing installs migrate forward without losing data.
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE user_stats ADD COLUMN streak_freezes INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (oldVersion < 3) {
            await db.execute(
              'ALTER TABLE user_stats ADD COLUMN daily_challenges_completed INTEGER NOT NULL DEFAULT 0',
            );
            await db.execute(
              'ALTER TABLE user_stats ADD COLUMN race_wins INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (oldVersion < 4) {
            // Study plans set milestones across listening and speaking,
            // not just vocabulary — which needs those to actually be
            // counted somewhere.
            await db.execute(
              'ALTER TABLE user_stats ADD COLUMN listening_completed INTEGER NOT NULL DEFAULT 0',
            );
            await db.execute(
              'ALTER TABLE user_stats ADD COLUMN pronunciation_completed INTEGER NOT NULL DEFAULT 0',
            );
          }
        },
      ),
    );
    if (overridePath == null) _instance = db;
    return db;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE decks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        topic TEXT NOT NULL,
        hsk_level INTEGER NOT NULL,
        word_count INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE words (
        id TEXT PRIMARY KEY,
        hanzi TEXT NOT NULL,
        pinyin TEXT NOT NULL,
        translation_ru TEXT NOT NULL,
        example_sentence TEXT,
        example_translation TEXT,
        hsk_level INTEGER NOT NULL,
        topic TEXT NOT NULL,
        deck_id TEXT NOT NULL,
        FOREIGN KEY (deck_id) REFERENCES decks(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE review_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id TEXT NOT NULL,
        reviewed_at INTEGER NOT NULL,
        was_correct INTEGER NOT NULL,
        exercise_type TEXT NOT NULL,
        repetitions INTEGER NOT NULL,
        ease_factor REAL NOT NULL,
        interval_days INTEGER NOT NULL,
        next_review_at INTEGER NOT NULL,
        FOREIGN KEY (word_id) REFERENCES words(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_review_word ON review_history(word_id, reviewed_at)',
    );
    await db.execute('''
      CREATE TABLE user_stats (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        total_xp INTEGER NOT NULL DEFAULT 0,
        current_streak INTEGER NOT NULL DEFAULT 0,
        longest_streak INTEGER NOT NULL DEFAULT 0,
        last_activity_date TEXT,
        hearts_current INTEGER NOT NULL DEFAULT 5,
        hearts_max INTEGER NOT NULL DEFAULT 5,
        hearts_updated_at INTEGER NOT NULL,
        daily_goal_xp INTEGER NOT NULL DEFAULT 20,
        xp_today INTEGER NOT NULL DEFAULT 0,
        xp_today_date TEXT,
        perfect_lessons_count INTEGER NOT NULL DEFAULT 0,
        streak_freezes INTEGER NOT NULL DEFAULT 0,
        daily_challenges_completed INTEGER NOT NULL DEFAULT 0,
        race_wins INTEGER NOT NULL DEFAULT 0,
        listening_completed INTEGER NOT NULL DEFAULT 0,
        pronunciation_completed INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE completed_lessons (
        deck_id TEXT PRIMARY KEY,
        completed_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE achievements_unlocked (
        code TEXT PRIMARY KEY,
        unlocked_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.insert('user_stats', {
      'id': 1,
      'hearts_updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
