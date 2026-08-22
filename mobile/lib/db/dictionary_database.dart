import 'dart:io';

import 'package:flutter/foundation.dart' show Uint8List, compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Opens the shipped reference dictionary.
///
/// The dictionary is 124k rows of read-only data that never changes
/// between releases, so it ships prebuilt rather than being seeded at
/// startup — inserting it row by row on a phone is a visible freeze, and
/// re-inserting identical data on every upgrade is pure waste.
///
/// The asset is gzipped because the raw file is ~29 MB of highly
/// compressible text; unpacking once on first launch costs a second and
/// saves more than half the download.
class DictionaryDatabase {
  /// Bump when the shipped data changes. The extracted copy is named
  /// after it, so a new release unpacks a fresh file instead of quietly
  /// serving the previous one.
  static const _version = 1;
  static const _assetPath = 'assets/dict/cedict.db.gz';

  static Database? _instance;
  static Future<Database>? _opening;

  /// Opens the dictionary, unpacking it from assets on first use.
  ///
  /// Concurrent callers share one unpack: the dictionary screen and a
  /// word detail page can both ask for it in the same frame, and two
  /// simultaneous writes of the same 29 MB file would race.
  static Future<Database> open() {
    if (_instance != null) return Future.value(_instance);
    return _opening ??= _open()
        .then((db) {
          _instance = db;
          return db;
        })
        .whenComplete(() => _opening = null);
  }

  static Future<Database> _open() async {
    final dir = await databaseFactory.getDatabasesPath();
    final path = join(dir, 'cedict_v$_version.db');
    final file = File(path);

    if (!file.existsSync()) {
      final data = await rootBundle.load(_assetPath);
      // 13 MB in, 29 MB out. On the main isolate that is a visible stall
      // on the frame it happens, so it goes to a worker.
      final bytes = await compute(_inflate, data.buffer.asUint8List());
      // Write beside the target and rename, so a launch interrupted
      // mid-unpack doesn't leave a truncated database that looks valid.
      final temp = File('$path.part');
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(path);
      await _removeStaleCopies(dir, keep: basename(path));
    }

    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: true),
    );
  }

  /// Deletes dictionaries left behind by earlier versions of the app —
  /// otherwise every data update permanently adds tens of megabytes to
  /// the install.
  static Future<void> _removeStaleCopies(
    String dir, {
    required String keep,
  }) async {
    final directory = Directory(dir);
    if (!directory.existsSync()) return;
    for (final entity in directory.listSync()) {
      final name = basename(entity.path);
      if (entity is File &&
          name.startsWith('cedict_v') &&
          name.endsWith('.db') &&
          name != keep) {
        try {
          await entity.delete();
        } on FileSystemException {
          // A stale copy we can't remove is wasted space, not a failure
          // worth blocking the dictionary over.
        }
      }
    }
  }
}

/// Top-level so it can run on a worker isolate.
List<int> _inflate(Uint8List compressed) => gzip.decode(compressed);
