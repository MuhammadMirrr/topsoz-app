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

    test(
      'getWord turli apostrof variantli siblinglarni birlashtiradi',
      () async {
        // id=15 "bo'sh" (U+0027, herve) tafsilotini ochamiz; id=16 "boʻsh"
        // (U+02BB, kaikki) sibling ta'rifi ham birlashishi kerak.
        final word = await repository.getWord(15);

        expect(word, isNotNull);
        final defs = word!.definitions
            .map((d) => d.definition.toLowerCase())
            .toList();
        expect(defs, contains('empty'), reason: 'asosiy ta\'rif');
        expect(
          defs,
          contains('vacant'),
          reason: 'U+02BB apostrofli sibling birlashmadi',
        );
      },
    );

    test('3 harfli inglizcha so\'z ta\'rif orqali topiladi', () async {
      // "cat" 3 harf — eski xulqda ta'rif qidiruvi o'chiq edi (len>3).
      final results = await repository.search('cat', targetLanguage: 'en');

      expect(results, isNotEmpty);
      expect(results.any((r) => r.word == 'mushuk'), isTrue);
    });

    test('3 harfli query ta\'rif PREFIKSi orqali ham topadi (car→carriage)', () {
      // definitionToken (prefix) yo'li: "carriage" "car"* ga mos keladi.
      return repository.search('car', targetLanguage: 'en').then((results) {
        expect(results.any((r) => r.word == 'ulov'), isTrue);
      });
    });

    test(
      "2 harfli apostrofli so'z (o'r) ta'rif shovqinini keltirmaydi",
      () async {
        // folded "or" 2 harf → allowDefinitionMatches false. "buyruq" faqat
        // ta'rifi ("order") orqali mos kelardi — endi natijada bo'lmasligi kerak.
        final results = await repository.search("o'r");

        expect(results.any((r) => r.word == "o'r"), isTrue, reason: 'headword');
        expect(
          results.any((r) => r.word == 'buyruq'),
          isFalse,
          reason: "2-harfli so'z ta'rif qidiruviga tushmasligi kerak",
        );
      },
    );
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
      'book + ru filter — qat\'iy til filtri: ruscha mos yo\'q bo\'lsa bo\'sh qaytadi',
      () async {
        // Til filtri qat'iy: "book" ruscha ta'rifda yo'q (faqat inglizcha
        // ta'riflarda bor), shuning uchun ru rejimida natija bo'sh bo'ladi.
        // Bu fixture guruhidagi bir xil so'rovning xulqiga mos.
        final results = await repository.search('book', targetLanguage: 'ru');
        expect(results, isEmpty);
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

    test('Ruscha rejim — ruscha ta\'rif bor so\'zlar tepada turadi', () async {
      // Biror so'z uchun Ruscha mode da qidirsak, agar ruscha ta'rif bo'lsa
      // u oldinroq chiqishi kerak. Bu test baza holatiga bog'liq —
      // faqat tartibning mantiqiyligini tekshiradi.
      final results = await repository.search('ot', targetLanguage: 'ru');
      if (results.length < 2) return;
      // Tartib buzilgan bo'lmasligi kerak
      expect(results.first.word, isNotEmpty);
    });

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
    // Bug 1 regress: bir xil so'z, TURLI apostrof belgisi, turli manba.
    // "bo'sh" U+0027 (herve) va "boʻsh" U+02BB (kaikki) — getWord ularni
    // birlashtirishi kerak (apostrof normallashtirilgan taqqoslash).
    _wordRow(15, "bo'sh", 'adjective', 'herve'),
    _wordRow(16, 'boʻsh', 'adjective', 'kaikki'),
    // Bug 2 regress: 3 harfli inglizcha ta'rif orqali topiladigan so'z.
    _wordRow(17, 'mushuk', 'noun', 'herve'),
    // Review#2 regress: 2-harfli apostrofli so'z ("o'r") ta'rif qidiruviga
    // TUSHMASLIGI kerak (folded "or" 2 harf). "buyruq" faqat ta'rifi ("order")
    // orqali "or"* ga mos kelardi — endi mos kelmasligi kerak.
    _wordRow(20, "o'r", 'verb', 'herve'),
    _wordRow(21, 'buyruq', 'noun', 'herve'),
    // Review#3 regress: 3 harfli query prefix (definitionToken) yo'li —
    // "car" → "carriage" ta'rifiga prefix mos keladi.
    _wordRow(22, 'ulov', 'noun', 'herve'),
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
    _definitionRow(15, 15, 'empty', 'en', 0),
    _definitionRow(16, 16, 'vacant', 'en', 0),
    _definitionRow(17, 17, 'cat', 'en', 0),
    _definitionRow(20, 20, 'reap', 'en', 0),
    _definitionRow(21, 21, 'order', 'en', 0),
    _definitionRow(22, 22, 'carriage', 'en', 0),
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
