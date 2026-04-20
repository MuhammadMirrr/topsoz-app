import 'package:sqflite/sqflite.dart';
import '../models/word.dart';

class FavoritesRepository {
  final Database db;

  FavoritesRepository(this.db);

  Future<List<Word>> getAll() async {
    final rows = await db.rawQuery('''
      SELECT w.*, 1 as is_favorite,
             (SELECT d.definition FROM definitions d WHERE d.word_id = w.id ORDER BY d.sort_order LIMIT 1) as first_definition
      FROM favorites f
      JOIN words w ON w.id = f.word_id
      ORDER BY f.created_at DESC
    ''');

    return rows.map((row) {
      final word = Word.fromMap(row);
      final firstDef = row['first_definition'] as String?;
      if (firstDef != null) {
        return word.copyWith(
          definitions: [Definition(id: 0, wordId: word.id, definition: firstDef)],
        );
      }
      return word;
    }).toList();
  }

  Future<bool> isFavorite(int wordId) async {
    final rows = await db.query(
      'favorites',
      where: 'word_id = ?',
      whereArgs: [wordId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> toggle(int wordId) async {
    await db.transaction((txn) async {
      final rows = await txn.query(
        'favorites',
        where: 'word_id = ?',
        whereArgs: [wordId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        await txn.delete('favorites', where: 'word_id = ?', whereArgs: [wordId]);
      } else {
        await txn.insert('favorites', {'word_id': wordId});
      }
    });
  }

  Future<void> remove(int wordId) async {
    await db.delete('favorites', where: 'word_id = ?', whereArgs: [wordId]);
  }

  /// Barcha sevimlilarni o'chirish
  Future<void> removeAll() async {
    await db.delete('favorites');
  }
}
