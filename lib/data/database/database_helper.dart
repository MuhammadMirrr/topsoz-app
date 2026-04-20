import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  DatabaseHelper._();

  static const _databaseVersion = 2;
  static const _bundledDatabaseVersion = '2.0.0';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'topsoz.db');
    final file = File(dbPath);

    await Directory(dirname(dbPath)).create(recursive: true);

    if (!await file.exists()) {
      await _copyBundledDatabase(dbPath);
    } else {
      final localVersion = await _readDatabaseVersion(dbPath);
      if (localVersion != _bundledDatabaseVersion) {
        final backup = await _exportUserData(dbPath);
        await file.delete();
        await _copyBundledDatabase(dbPath);
        final migrated = await _openDatabase(dbPath);
        await _restoreUserData(migrated, backup);
        return migrated;
      }
    }

    return _openDatabase(dbPath);
  }

  Future<Database> _openDatabase(String dbPath) {
    return openDatabase(
      dbPath,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys=ON');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < _databaseVersion) {
          await db.execute('PRAGMA foreign_keys=ON');
        }
      },
    );
  }

  Future<void> _copyBundledDatabase(String dbPath) async {
    final data = await rootBundle.load('assets/db/topsoz.db');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await File(dbPath).writeAsBytes(bytes, flush: true);
  }

  Future<String?> _readDatabaseVersion(String dbPath) async {
    Database? db;
    try {
      db = await openDatabase(
        dbPath,
        readOnly: true,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys=ON');
        },
      );
      final result = await db.rawQuery(
        "SELECT value FROM meta WHERE key = 'version' LIMIT 1",
      );
      if (result.isEmpty) return null;
      return result.first['value'] as String?;
    } catch (e) {
      debugPrint('Baza versiyasini o‘qishda xatolik: $e');
      return null;
    } finally {
      await db?.close();
    }
  }

  Future<_DatabaseUserBackup> _exportUserData(String dbPath) async {
    Database? db;
    try {
      db = await openDatabase(
        dbPath,
        readOnly: true,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys=ON');
        },
      );

      final favoriteRows = await db.rawQuery('''
        SELECT
          w.word,
          w.language,
          w.part_of_speech,
          w.source,
          fav.created_at
        FROM favorites fav
        JOIN words w ON w.id = fav.word_id
        ORDER BY fav.created_at ASC
      ''');

      final historyRows = await db.rawQuery('''
        SELECT
          h.query,
          h.searched_at,
          w.word,
          w.language,
          w.part_of_speech,
          w.source
        FROM search_history h
        LEFT JOIN words w ON w.id = h.word_id
        ORDER BY h.searched_at ASC, h.id ASC
      ''');

      return _DatabaseUserBackup(
        favorites: favoriteRows
            .map((row) => _FavoriteBackup.fromMap(row))
            .toList(growable: false),
        history: historyRows
            .map((row) => _HistoryBackup.fromMap(row))
            .toList(growable: false),
      );
    } catch (e) {
      debugPrint('Foydalanuvchi ma’lumotlarini saqlashda xatolik: $e');
      return const _DatabaseUserBackup();
    } finally {
      await db?.close();
    }
  }

  Future<void> _restoreUserData(Database db, _DatabaseUserBackup backup) async {
    if (backup.isEmpty) return;

    await db.transaction((txn) async {
      for (final favorite in backup.favorites) {
        final wordId = await _findWordId(txn, favorite.signature);
        if (wordId == null) continue;
        await txn.insert('favorites', {
          'word_id': wordId,
          'created_at': favorite.createdAt,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      for (final history in backup.history) {
        final wordId = history.signature == null
            ? null
            : await _findWordId(txn, history.signature!);
        await txn.insert('search_history', {
          'query': history.query,
          'word_id': wordId,
          'searched_at': history.searchedAt,
        }, conflictAlgorithm: ConflictAlgorithm.abort);
      }
    });
  }

  Future<int?> _findWordId(
    DatabaseExecutor db,
    _WordSignature signature,
  ) async {
    final rows = await db.query(
      'words',
      columns: const ['id'],
      where: 'word = ? AND language = ? AND part_of_speech = ? AND source = ?',
      whereArgs: [
        signature.word,
        signature.language,
        signature.partOfSpeech,
        signature.source,
      ],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

class _DatabaseUserBackup {
  final List<_FavoriteBackup> favorites;
  final List<_HistoryBackup> history;

  const _DatabaseUserBackup({
    this.favorites = const [],
    this.history = const [],
  });

  bool get isEmpty => favorites.isEmpty && history.isEmpty;
}

class _WordSignature {
  final String word;
  final String language;
  final String partOfSpeech;
  final String source;

  const _WordSignature({
    required this.word,
    required this.language,
    required this.partOfSpeech,
    required this.source,
  });
}

class _FavoriteBackup {
  final _WordSignature signature;
  final String createdAt;

  const _FavoriteBackup({required this.signature, required this.createdAt});

  factory _FavoriteBackup.fromMap(Map<String, Object?> map) {
    return _FavoriteBackup(
      signature: _WordSignature(
        word: map['word'] as String? ?? '',
        language: map['language'] as String? ?? 'uz',
        partOfSpeech: map['part_of_speech'] as String? ?? '',
        source: map['source'] as String? ?? '',
      ),
      createdAt: map['created_at'] as String? ?? '',
    );
  }
}

class _HistoryBackup {
  final String query;
  final String searchedAt;
  final _WordSignature? signature;

  const _HistoryBackup({
    required this.query,
    required this.searchedAt,
    required this.signature,
  });

  factory _HistoryBackup.fromMap(Map<String, Object?> map) {
    final word = map['word'] as String?;
    return _HistoryBackup(
      query: map['query'] as String? ?? '',
      searchedAt: map['searched_at'] as String? ?? '',
      signature: word == null
          ? null
          : _WordSignature(
              word: word,
              language: map['language'] as String? ?? 'uz',
              partOfSpeech: map['part_of_speech'] as String? ?? '',
              source: map['source'] as String? ?? '',
            ),
    );
  }
}
