import 'package:sqflite/sqflite.dart';

class HistoryEntry {
  final int id;
  final String query;
  final int? wordId;
  final String searchedAt;

  const HistoryEntry({
    required this.id,
    required this.query,
    this.wordId,
    required this.searchedAt,
  });
}

class HistoryRepository {
  final Database db;

  HistoryRepository(this.db);

  Future<List<HistoryEntry>> getRecent({int limit = 20}) async {
    final rows = await db.query(
      'search_history',
      orderBy: 'searched_at DESC',
      limit: limit,
    );
    return rows.map((r) => HistoryEntry(
      id: r['id'] as int,
      query: r['query'] as String,
      wordId: r['word_id'] as int?,
      searchedAt: r['searched_at'] as String,
    )).toList();
  }

  Future<void> add(String query, {int? wordId}) async {
    // Oxirgi qidiruv bilan bir xil bo'lsa, qo'shmaslik
    final last = await db.query(
      'search_history',
      orderBy: 'searched_at DESC',
      limit: 1,
    );
    if (last.isNotEmpty && last.first['query'] == query) return;

    await db.insert('search_history', {
      'query': query,
      'word_id': wordId,
    });

    // 100 tadan ortiq tarixni o'chirish
    await db.rawDelete('''
      DELETE FROM search_history
      WHERE id NOT IN (
        SELECT id FROM search_history ORDER BY searched_at DESC LIMIT 100
      )
    ''');
  }

  Future<void> clear() async {
    await db.delete('search_history');
  }
}
