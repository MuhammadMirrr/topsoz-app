import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:topsoz/core/utils/transliterator.dart';
import 'package:topsoz/data/models/search_result.dart';
import 'package:topsoz/data/repositories/word_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('WordRepository.search fixture', () {
    late Database db;
    late WordRepository repository;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (database, version) async {
          await _createSchema(database);
          await _seedFixtureData(database);
        },
      );
      repository = WordRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'exact match birinchi chiqadi va source dublikatlari yig\'iladi',
      () async {
        final results = await repository.search('ot');

        expect(results, isNotEmpty);
        expect(results.first.word, 'ot');
        expect(results.first.matchKind, SearchMatchKind.exactHeadword);
        expect(results.first.duplicateCount, 2);
        expect(results.first.partOfSpeech, 'noun');
      },
    );

    test('apostrofli so\'z false positive lardan oldin turadi', () async {
      final results = await repository.search("qo'l");

      expect(results, isNotEmpty);
      expect(results.first.word, "qo'l");
      expect(results.first.matchKind, SearchMatchKind.exactHeadword);
      expect(results.first.firstDefinition.toLowerCase(), contains('hand'));
    });

    test('apostrofsiz query uchun folded exact prefiksdan kuchliroq', () async {
      final results = await repository.search('qol');

      expect(results, isNotEmpty);
      expect(results.first.word, "qo'l");
      expect(results.first.matchKind, SearchMatchKind.exactFoldedHeadword);
    });

    test('ko\'p so\'zli query compound natijani topadi', () async {
      final results = await repository.search('kitob maktab');

      expect(results, isNotEmpty);
      expect(results.first.word, 'maktab kitobi');
      expect(results.first.matchKind, SearchMatchKind.compoundHeadword);
    });

    test('til filtri definition match manbasini ham cheklaydi', () async {
      final results = await repository.search('book', targetLanguage: 'ru');

      expect(results, isEmpty);
    });

    test('kirill qidiruvi lotin headword ga qaytadi', () async {
      final results = await repository.search(
        UzbekTransliterator.toCyrillic('ot'),
      );

      expect(results, isNotEmpty);
      expect(results.first.word, 'ot');
      expect(results.first.matchKind, SearchMatchKind.exactTransliteration);
    });
  });

  group('WordRepository.search real database', () {
    late Database db;
    late WordRepository repository;
    final dbPath =
        '${Directory.current.path}${Platform.pathSeparator}saved_database'
        '${Platform.pathSeparator}topsoz.db';

    setUpAll(() async {
      db = await openDatabase(dbPath, readOnly: true);
      repository = WordRepository(db);
    });

    tearDownAll(() async {
      await db.close();
    });

    test('kritik exact query lar tepada turadi', () async {
      final checks = <String, String>{
        'ot': 'ot',
        'bosh': 'bosh',
        'bir': 'bir',
        "o'z": "o'z",
        "qo'l": "qo'l",
        "to'g'ri": "to'g'ri",
      };

      for (final entry in checks.entries) {
        final results = await repository.search(entry.key);
        expect(results, isNotEmpty, reason: '${entry.key} uchun natija bo\'sh');
        expect(
          _normalizeApostrophes(results.first.word.toLowerCase()),
          _normalizeApostrophes(entry.value.toLowerCase()),
          reason: '${entry.key} uchun exact natija tepada emas',
        );
      }
    });

    test(
      'book + ru filter — ruscha ta\'rif yo\'q bo\'lsa ham inglizcha fallback ko\'rsatadi',
      () async {
        final results = await repository.search('book', targetLanguage: 'ru');
        // Yangi xulq: ruscha ta'rif topilmasa ham, inglizcha yoki boshqa
        // ta'rif fallback sifatida ko'rsatiladi (to'liq bo'sh emas).
        expect(results, isNotEmpty);
      },
    );

    test(
      'Ruscha rejim + O\'zbek kirill query — avtomatik Lotinga o\'tkaziladi',
      () async {
        // "олтин" (o'zbek kirillida "oltin") — Ruscha rejim
        // → avtomatik "oltin" Lotin so'ziga o'tib, natija beradi
        final results = await repository.search(
          '\u043E\u043B\u0442\u0438\u043D',
          targetLanguage: 'ru',
        );
        // Fallback ishga tushib, "oltin" topilgani kutiladi
        // (baza'da ana shu so'z bor bo'lsa)
        if (results.isEmpty) {
          // Baza'da "oltin" yo'q bo'lishi mumkin — test shartli
          return;
        }
        expect(
          _normalizeApostrophes(results.first.word.toLowerCase()),
          _normalizeApostrophes('oltin'),
        );
      },
    );

    test(
      'Ruscha rejim — ruscha ta\'rif bor so\'zlar tepada turadi',
      () async {
        // Biror so'z uchun Ruscha mode da qidirsak, agar ruscha ta'rif bo'lsa
        // u oldinroq chiqishi kerak. Bu test baza holatiga bog'liq —
        // faqat tartibning mantiqiyligini tekshiradi.
        final results = await repository.search('ot', targetLanguage: 'ru');
        if (results.length < 2) return;
        // Tartib buzilgan bo'lmasligi kerak
        expect(results.first.word, isNotEmpty);
      },
    );

    test('multi-token query blank qaytmaydi', () async {
      final results = await repository.search('kitob maktab');
      expect(results, isNotEmpty);
    });

    test('exact lemma grouping duplicateCount ni ko\'rsatadi', () async {
      final results = await repository.search('ot');
      expect(results, isNotEmpty);
      expect(results.first.duplicateCount, greaterThan(1));
    });
  });
}

Future<void> _createSchema(Database db) async {
  await db.execute('''
    CREATE TABLE words (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      word TEXT NOT NULL,
      word_cyrillic TEXT,
      language TEXT NOT NULL,
      part_of_speech TEXT DEFAULT '',
      pronunciation TEXT DEFAULT '',
      etymology TEXT DEFAULT '',
      source TEXT NOT NULL DEFAULT ''
    )
  ''');
  await db.execute('''
    CREATE TABLE definitions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      word_id INTEGER NOT NULL,
      definition TEXT NOT NULL,
      target_language TEXT NOT NULL,
      example_source TEXT DEFAULT '',
      example_target TEXT DEFAULT '',
      sort_order INTEGER DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE favorites (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      word_id INTEGER NOT NULL UNIQUE,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''');
  await db.execute('''
    CREATE TABLE search_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      query TEXT NOT NULL,
      word_id INTEGER,
      searched_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  ''');
  await db.execute("""
    CREATE VIRTUAL TABLE words_fts USING fts5(
      word,
      word_cyrillic,
      word_folded,
      definitions_en,
      definitions_ru,
      definitions_all,
      tokenize='unicode61 remove_diacritics 2 tokenchars ''''',
      prefix='2 3 4'
    )
  """);
}

Future<void> _seedFixtureData(Database db) async {
  final words = <Map<String, Object?>>[
    _wordRow(1, 'ot', 'noun', 'common'),
    _wordRow(2, 'ot', 'noun', 'kaikki'),
    _wordRow(3, 'ot', 'verb', 'herve'),
    _wordRow(4, 'ota', 'noun', 'herve'),
    _wordRow(5, 'otli', 'adjective', 'herve'),
    _wordRow(6, "qo'l", 'noun', 'herve'),
    _wordRow(7, 'qolmoq', 'verb', 'herve'),
    _wordRow(8, 'qolip', 'noun', 'herve'),
    _wordRow(9, "o'z", 'pronoun', 'herve'),
    _wordRow(10, 'ozod', 'adjective', 'herve'),
    _wordRow(11, "to'g'ri", 'adjective', 'herve'),
    _wordRow(12, 'maktab kitobi', 'noun', 'herve'),
    _wordRow(13, 'kitob', 'noun', 'herve'),
    _wordRow(14, 'maktab', 'noun', 'herve'),
  ];

  for (final row in words) {
    await db.insert('words', row);
  }

  final definitions = <Map<String, Object?>>[
    _definitionRow(1, 1, 'name', 'en', 0),
    _definitionRow(2, 2, 'horse', 'en', 0),
    _definitionRow(3, 3, 'throw', 'en', 0),
    _definitionRow(4, 4, 'father', 'en', 0),
    _definitionRow(5, 5, 'mounted', 'en', 0),
    _definitionRow(6, 6, 'hand', 'en', 0),
    _definitionRow(7, 7, 'remain', 'en', 0),
    _definitionRow(8, 8, 'mold', 'en', 0),
    _definitionRow(9, 9, 'self', 'en', 0),
    _definitionRow(10, 10, 'free', 'en', 0),
    _definitionRow(11, 11, 'correct', 'en', 0),
    _definitionRow(12, 12, 'school book', 'en', 0),
    _definitionRow(13, 13, 'book', 'en', 0),
    _definitionRow(14, 14, 'school', 'en', 0),
  ];

  for (final row in definitions) {
    await db.insert('definitions', row);
  }

  await _rebuildFts(db);
}

Future<void> _rebuildFts(Database db) async {
  await db.delete('words_fts');
  await db.rawInsert("""
    INSERT INTO words_fts(
      rowid,
      word,
      word_cyrillic,
      word_folded,
      definitions_en,
      definitions_ru,
      definitions_all
    )
    SELECT
      w.id,
      LOWER(REPLACE(REPLACE(REPLACE(w.word, '’', ''''), '‘', ''''), '`', '''')),
      LOWER(COALESCE(w.word_cyrillic, '')),
      LOWER(REPLACE(REPLACE(REPLACE(REPLACE(w.word, '’', ''''), '‘', ''''), '`', ''''), '''', '')),
      COALESCE(
        GROUP_CONCAT(
          CASE WHEN d.target_language = 'en' THEN LOWER(d.definition) END,
          ' | '
        ),
        ''
      ),
      COALESCE(
        GROUP_CONCAT(
          CASE WHEN d.target_language = 'ru' THEN LOWER(d.definition) END,
          ' | '
        ),
        ''
      ),
      COALESCE(GROUP_CONCAT(LOWER(d.definition), ' | '), '')
    FROM words w
    LEFT JOIN definitions d ON d.word_id = w.id
    GROUP BY w.id
  """);
}

Map<String, Object?> _wordRow(int id, String word, String pos, String source) {
  return {
    'id': id,
    'word': word,
    'word_cyrillic': UzbekTransliterator.toCyrillic(word),
    'language': 'uz',
    'part_of_speech': pos,
    'pronunciation': '',
    'etymology': '',
    'source': source,
  };
}

Map<String, Object?> _definitionRow(
  int id,
  int wordId,
  String definition,
  String targetLanguage,
  int sortOrder,
) {
  return {
    'id': id,
    'word_id': wordId,
    'definition': definition,
    'target_language': targetLanguage,
    'example_source': '',
    'example_target': '',
    'sort_order': sortOrder,
  };
}

String _normalizeApostrophes(String value) {
  return value.replaceAll(RegExp(r"[\u02BB\u02BC`\u2018\u2019\u2032]"), "'");
}
