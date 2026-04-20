import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../../core/utils/transliterator.dart';
import '../models/search_result.dart';
import '../models/word.dart';

class WordRepository {
  final Database db;

  WordRepository(this.db);

  static final _apostrophePattern = RegExp(
    r"[\u02BB\u02BC`\u2018\u2019\u2032]",
  );
  static final _spacePattern = RegExp(r'\s+');
  static final _ftsReservedPattern = RegExp(r'["*+\-^(){}\[\]:]');
  static final _tokenPattern = RegExp(r"[a-z0-9\u0400-\u04FF']+");

  static const _sourcePriority = <String, int>{
    'common': 0,
    'kaikki': 1,
    'uzwordnet': 2,
    'herve': 3,
    'compact': 4,
    'vuizur': 5,
    'essential': 6,
    'nurullon': 7,
    'knightss27': 8,
    'kodchi': 9,
  };

  Future<List<SearchResult>> search(
    String query, {
    int limit = 50,
    String? targetLanguage,
  }) async {
    final plan = _SearchPlan.fromQuery(query);
    if (!plan.isValid) return [];

    try {
      final candidatesById = <int, _SearchCandidate>{};

      if (plan.tokens.length == 1) {
        final exactRows = await _runExactWordQuery(plan, limit: 40);
        for (final row in exactRows) {
          final candidate = candidatesById.putIfAbsent(
            row['id'] as int,
            () => _SearchCandidate.fromMap(row),
          );
          candidate.markHeadwordHit();
        }
      }

      final headwordRows = await _runFtsQuery(
        plan.buildHeadwordMatchQuery(),
        limit: 160,
      );
      for (final row in headwordRows) {
        final candidate = candidatesById.putIfAbsent(
          row['id'] as int,
          () => _SearchCandidate.fromMap(row),
        );
        candidate.markHeadwordHit();
      }

      final hybridQuery = plan.buildHybridMatchQuery(targetLanguage);
      if (hybridQuery != null) {
        final hybridRows = await _runFtsQuery(hybridQuery, limit: 140);
        for (final row in hybridRows) {
          final candidate = candidatesById.putIfAbsent(
            row['id'] as int,
            () => _SearchCandidate.fromMap(row),
          );
          candidate.markHeadwordHit();
          candidate.markDefinitionHit();
        }
      }

      final grouped = <String, List<_ScoredCandidate>>{};
      for (final candidate in candidatesById.values) {
        final scored = _scoreCandidate(candidate, plan, targetLanguage);
        if (scored == null) continue;

        final groupKey =
            '${_normalizeSearchText(candidate.word)}::'
            '${_normalizePosBucket(candidate.partOfSpeech)}';
        grouped.putIfAbsent(groupKey, () => []).add(scored);
      }

      final results =
          grouped.values.map((group) {
            group.sort(_compareScoredCandidates);
            final canonical = group.first;
            return SearchResult(
              wordId: canonical.candidate.id,
              word: canonical.candidate.word,
              wordCyrillic: canonical.candidate.wordCyrillic,
              partOfSpeech: canonical.candidate.partOfSpeech,
              firstDefinition: stripHtml(canonical.previewDefinition),
              isFavorite: canonical.candidate.isFavorite,
              matchKind: canonical.matchKind,
              score: canonical.score,
              duplicateCount: group.length,
              matchedTargetLanguage: canonical.matchedTargetLanguage,
            );
          }).toList()..sort((a, b) {
            // Tanlangan tilda ta'rif bor natijalar yuqoriga chiqadi
            if (targetLanguage != null) {
              final aHas = candidatesById[a.wordId]
                  ?.hasDefinitionInLanguage(targetLanguage) ?? false;
              final bHas = candidatesById[b.wordId]
                  ?.hasDefinitionInLanguage(targetLanguage) ?? false;
              if (aHas != bHas) return bHas ? 1 : -1;
            }

            final scoreOrder = b.score.compareTo(a.score);
            if (scoreOrder != 0) return scoreOrder;

            final matchOrder = a.matchKind.index.compareTo(b.matchKind.index);
            if (matchOrder != 0) return matchOrder;

            final sourceOrder = _compareSourcePriorityByWordId(
              candidatesById[a.wordId]?.source ?? '',
              candidatesById[b.wordId]?.source ?? '',
            );
            if (sourceOrder != 0) return sourceOrder;

            final wordOrder = a.word.length.compareTo(b.word.length);
            if (wordOrder != 0) return wordOrder;

            return a.wordId.compareTo(b.wordId);
          });

      final limitedResults = results.take(limit).toList(growable: false);

      // Tanlangan til rejimida Kiril kirish bilan bo'sh natija bo'lsa,
      // foydalanuvchi ehtimol o'zbek kirillida yozgan — avtomatik Lotinga
      // o'tkazib qayta qidiramiz (misol: "олтин" → "oltin").
      if (limitedResults.isEmpty &&
          targetLanguage != null &&
          UzbekTransliterator.isCyrillic(query)) {
        final latinQuery = UzbekTransliterator.toLatin(query);
        if (latinQuery.isNotEmpty && latinQuery != query) {
          final fallbackResults = await search(
            latinQuery,
            limit: limit,
            targetLanguage: null,
          );
          if (fallbackResults.isNotEmpty) return fallbackResults;
        }
      }

      if (limitedResults.isEmpty && plan.tokens.length > 1) {
        return _searchByTokenFallback(
          plan,
          limit: limit,
          targetLanguage: targetLanguage,
        );
      }

      return limitedResults;
    } on DatabaseException {
      return [];
    }
  }

  Future<List<SearchResult>> _searchByTokenFallback(
    _SearchPlan plan, {
    required int limit,
    required String? targetLanguage,
  }) async {
    final aggregated = <int, _FallbackResult>{};

    for (final token in plan.tokens) {
      final tokenResults = await search(
        token.original,
        limit: math.max(limit, 20),
        targetLanguage: targetLanguage,
      );

      for (final result in tokenResults) {
        final current = aggregated[result.wordId];
        if (current == null) {
          aggregated[result.wordId] = _FallbackResult(
            result: result,
            matchCount: 1,
          );
          continue;
        }

        current.matchCount += 1;
        if (result.score > current.result.score) {
          current.result = result;
        }
      }
    }

    final fallbackResults = aggregated.values.toList()
      ..sort((left, right) {
        final matchOrder = right.matchCount.compareTo(left.matchCount);
        if (matchOrder != 0) return matchOrder;
        return right.result.score.compareTo(left.result.score);
      });

    return fallbackResults
        .map((entry) => entry.result)
        .take(limit)
        .toList(growable: false);
  }

  Future<List<Map<String, Object?>>> _runFtsQuery(
    String matchQuery, {
    required int limit,
  }) {
    return db.rawQuery(
      '''
        SELECT
          w.id,
          w.word,
          COALESCE(w.word_cyrillic, '') AS word_cyrillic,
          COALESCE(w.part_of_speech, '') AS part_of_speech,
          COALESCE(w.source, '') AS source,
          CASE WHEN fav.id IS NOT NULL THEN 1 ELSE 0 END AS is_favorite,
          COALESCE(words_fts.definitions_en, '') AS definitions_en,
          COALESCE(words_fts.definitions_ru, '') AS definitions_ru,
          COALESCE(words_fts.definitions_all, '') AS definitions_all,
          COALESCE((
            SELECT d.definition
            FROM definitions d
            WHERE d.word_id = w.id AND d.target_language = 'en'
            ORDER BY d.sort_order
            LIMIT 1
          ), '') AS first_def_en,
          COALESCE((
            SELECT d.definition
            FROM definitions d
            WHERE d.word_id = w.id AND d.target_language = 'ru'
            ORDER BY d.sort_order
            LIMIT 1
          ), '') AS first_def_ru,
          COALESCE((
            SELECT d.definition
            FROM definitions d
            WHERE d.word_id = w.id
            ORDER BY
              CASE d.target_language
                WHEN 'en' THEN 0
                WHEN 'ru' THEN 1
                WHEN 'uz' THEN 2
                ELSE 3
              END,
              d.sort_order
            LIMIT 1
          ), '') AS first_def_any
        FROM words_fts
        JOIN words w ON w.id = words_fts.rowid
        LEFT JOIN favorites fav ON fav.word_id = w.id
        WHERE words_fts MATCH ?
        LIMIT ?
      ''',
      [matchQuery, limit],
    );
  }

  Future<List<Map<String, Object?>>> _runExactWordQuery(
    _SearchPlan plan, {
    required int limit,
  }) {
    final clauses = <String>[];
    final args = <Object?>[];

    if (plan.exactLatinForms.isNotEmpty) {
      final placeholders = List.filled(
        plan.exactLatinForms.length,
        '?',
      ).join(', ');
      clauses.add('${_normalizedWordSql('w.word')} IN ($placeholders)');
      args.addAll(plan.exactLatinForms);
    }

    if (plan.exactCyrillicForms.isNotEmpty) {
      final placeholders = List.filled(
        plan.exactCyrillicForms.length,
        '?',
      ).join(', ');
      clauses.add(
        '${_normalizedWordSql('w.word_cyrillic')} IN ($placeholders)',
      );
      args.addAll(plan.exactCyrillicForms);
    }

    if (plan.foldedQueryForms.isNotEmpty) {
      final placeholders = List.filled(
        plan.foldedQueryForms.length,
        '?',
      ).join(', ');
      clauses.add('${_foldedWordSql('w.word')} IN ($placeholders)');
      args.addAll(plan.foldedQueryForms);
    }

    if (clauses.isEmpty) return Future.value(const []);

    return db.rawQuery(
      '''
        SELECT
          w.id,
          w.word,
          COALESCE(w.word_cyrillic, '') AS word_cyrillic,
          COALESCE(w.part_of_speech, '') AS part_of_speech,
          COALESCE(w.source, '') AS source,
          CASE WHEN fav.id IS NOT NULL THEN 1 ELSE 0 END AS is_favorite,
          COALESCE(words_fts.definitions_en, '') AS definitions_en,
          COALESCE(words_fts.definitions_ru, '') AS definitions_ru,
          COALESCE(words_fts.definitions_all, '') AS definitions_all,
          COALESCE((
            SELECT d.definition
            FROM definitions d
            WHERE d.word_id = w.id AND d.target_language = 'en'
            ORDER BY d.sort_order
            LIMIT 1
          ), '') AS first_def_en,
          COALESCE((
            SELECT d.definition
            FROM definitions d
            WHERE d.word_id = w.id AND d.target_language = 'ru'
            ORDER BY d.sort_order
            LIMIT 1
          ), '') AS first_def_ru,
          COALESCE((
            SELECT d.definition
            FROM definitions d
            WHERE d.word_id = w.id
            ORDER BY
              CASE d.target_language
                WHEN 'en' THEN 0
                WHEN 'ru' THEN 1
                WHEN 'uz' THEN 2
                ELSE 3
              END,
              d.sort_order
            LIMIT 1
          ), '') AS first_def_any
        FROM words w
        LEFT JOIN words_fts ON words_fts.rowid = w.id
        LEFT JOIN favorites fav ON fav.word_id = w.id
        WHERE ${clauses.join(' OR ')}
        LIMIT ?
      ''',
      [...args, limit],
    );
  }

  _ScoredCandidate? _scoreCandidate(
    _SearchCandidate candidate,
    _SearchPlan plan,
    String? targetLanguage,
  ) {
    final normalizedWord = _normalizeSearchText(candidate.word);
    final normalizedCyrillic = _normalizeSearchText(candidate.wordCyrillic);
    final foldedWord = _foldHeadword(candidate.word);

    SearchMatchKind? matchKind;
    String? matchedTargetLanguage;

    if (candidate.hasHeadwordHit) {
      if (normalizedWord == plan.normalizedQuery) {
        matchKind = SearchMatchKind.exactHeadword;
      } else if (normalizedCyrillic.isNotEmpty &&
          (normalizedCyrillic == plan.normalizedQuery ||
              plan.transliteratedForms.contains(normalizedWord))) {
        matchKind = SearchMatchKind.exactTransliteration;
      } else if (plan.foldedQueryForms.contains(foldedWord)) {
        matchKind = SearchMatchKind.exactFoldedHeadword;
      } else if (_matchesPrefixHeadword(candidate, plan)) {
        matchKind = SearchMatchKind.prefixHeadword;
      } else if (_matchesCompoundHeadword(candidate, plan)) {
        matchKind = SearchMatchKind.compoundHeadword;
      } else if (_matchesFoldedPrefix(candidate, plan)) {
        matchKind = SearchMatchKind.foldedPrefix;
      }
    }

    if (matchKind == null &&
        candidate.hasDefinitionHit &&
        plan.allowDefinitionMatches) {
      if (_matchesHybridTokens(candidate, plan, targetLanguage)) {
        matchKind = SearchMatchKind.compoundHeadword;
      } else {
        matchedTargetLanguage = _matchedDefinitionLanguage(
          candidate,
          plan,
          targetLanguage,
          exactPhrase: true,
        );
        if (matchedTargetLanguage != null) {
          matchKind = SearchMatchKind.definitionPhrase;
        } else {
          matchedTargetLanguage = _matchedDefinitionLanguage(
            candidate,
            plan,
            targetLanguage,
            exactPhrase: false,
          );
          if (matchedTargetLanguage != null) {
            matchKind = SearchMatchKind.definitionToken;
          }
        }
      }
    }

    if (matchKind == null) return null;

    final effectivePreview = candidate.preferredDefinition(
      targetLanguage: targetLanguage,
      matchedTargetLanguage: matchedTargetLanguage,
    );
    if (effectivePreview.isEmpty) return null;

    final score = _buildScore(
      candidate: candidate,
      plan: plan,
      matchKind: matchKind,
      matchedTargetLanguage: matchedTargetLanguage,
    );

    return _ScoredCandidate(
      candidate: candidate,
      matchKind: matchKind,
      score: score,
      previewDefinition: effectivePreview,
      matchedTargetLanguage: matchedTargetLanguage,
    );
  }

  bool _matchesPrefixHeadword(_SearchCandidate candidate, _SearchPlan plan) {
    if (plan.tokens.length != 1) return false;
    final token = plan.tokens.first;
    final wordTokens = _extractTokens(candidate.word);
    final cyrillicTokens = _extractTokens(candidate.wordCyrillic);
    final combinedTokens = [...wordTokens, ...cyrillicTokens];

    for (final textToken in combinedTokens) {
      if (token.headwordVariants.any(
        (variant) => textToken.startsWith(variant),
      )) {
        return true;
      }
    }
    return false;
  }

  bool _matchesCompoundHeadword(_SearchCandidate candidate, _SearchPlan plan) {
    final wordTokens = _extractTokens(candidate.word);
    final cyrillicTokens = _extractTokens(candidate.wordCyrillic);
    return _tokensCoverAll(wordTokens, plan.tokens, useFolded: false) ||
        _tokensCoverAll(cyrillicTokens, plan.tokens, useFolded: false);
  }

  bool _matchesFoldedPrefix(_SearchCandidate candidate, _SearchPlan plan) {
    final foldedTokens = _extractTokens(_foldHeadword(candidate.word));
    if (foldedTokens.isEmpty) return false;

    for (final token in plan.tokens) {
      if (token.foldedVariants.isEmpty) return false;

      final matched = foldedTokens.any(
        (textToken) => token.foldedVariants.any(textToken.startsWith),
      );
      if (!matched) return false;
    }
    return true;
  }

  bool _matchesHybridTokens(
    _SearchCandidate candidate,
    _SearchPlan plan,
    String? targetLanguage,
  ) {
    if (plan.tokens.length < 2) return false;

    final tokens = <String>[
      ..._extractTokens(candidate.word),
      ..._extractTokens(candidate.wordCyrillic),
      ..._extractTokens(candidate.definitionText(targetLanguage)),
    ];

    return _tokensCoverAll(tokens, plan.tokens, useFolded: true);
  }

  String? _matchedDefinitionLanguage(
    _SearchCandidate candidate,
    _SearchPlan plan,
    String? targetLanguage, {
    required bool exactPhrase,
  }) {
    final languages = targetLanguage == null
        ? const ['en', 'ru', 'all']
        : [targetLanguage];

    for (final language in languages) {
      final text = candidate.definitionText(language);
      if (text.isEmpty) continue;

      final matched = exactPhrase
          ? _matchesDefinitionPhrase(text, plan)
          : _tokensCoverAll(_extractTokens(text), plan.tokens, useFolded: true);
      if (matched) {
        return language == 'all' ? null : language;
      }
    }

    return null;
  }

  bool _matchesDefinitionPhrase(String text, _SearchPlan plan) {
    if (plan.tokens.length == 1) {
      return _extractTokens(text).contains(plan.tokens.first.original);
    }
    return text.contains(plan.normalizedQuery);
  }

  bool _tokensCoverAll(
    List<String> textTokens,
    List<_SearchToken> queryTokens, {
    required bool useFolded,
  }) {
    if (textTokens.isEmpty) return false;

    for (final queryToken in queryTokens) {
      final variants = useFolded
          ? queryToken.allDefinitionVariants
          : queryToken.headwordVariants;
      if (variants.isEmpty) return false;

      final matched = textTokens.any(
        (textToken) => variants.any(
          (variant) => textToken == variant || textToken.startsWith(variant),
        ),
      );
      if (!matched) return false;
    }

    return true;
  }

  double _buildScore({
    required _SearchCandidate candidate,
    required _SearchPlan plan,
    required SearchMatchKind matchKind,
    required String? matchedTargetLanguage,
  }) {
    final baseScore = switch (matchKind) {
      SearchMatchKind.exactHeadword => 1000.0,
      SearchMatchKind.exactTransliteration => 940.0,
      SearchMatchKind.exactFoldedHeadword => plan.hasApostrophe ? 790.0 : 860.0,
      SearchMatchKind.prefixHeadword => 820.0,
      SearchMatchKind.compoundHeadword => 760.0,
      SearchMatchKind.foldedPrefix => plan.hasApostrophe ? 640.0 : 700.0,
      SearchMatchKind.definitionPhrase => 560.0,
      SearchMatchKind.definitionToken => 500.0,
    };

    final sourceBoost = 12 - _sourcePriorityValue(candidate.source);
    final wordPenalty =
        math.max(
          0,
          _foldHeadword(candidate.word).length - plan.foldedQuery.length,
        ) /
        10;
    final partOfSpeechPenalty = candidate.partOfSpeech.isEmpty ? 2.5 : 0.0;
    final definitionText = matchedTargetLanguage == null
        ? ''
        : candidate.definitionText(matchedTargetLanguage);
    final definitionIndex = definitionText.contains(plan.tokens.first.original)
        ? definitionText.indexOf(plan.tokens.first.original)
        : -1;
    final definitionPenalty = definitionIndex < 0 ? 0.0 : definitionIndex / 100;

    return baseScore +
        sourceBoost -
        wordPenalty -
        partOfSpeechPenalty -
        definitionPenalty;
  }

  static int _compareScoredCandidates(
    _ScoredCandidate left,
    _ScoredCandidate right,
  ) {
    final scoreOrder = right.score.compareTo(left.score);
    if (scoreOrder != 0) return scoreOrder;

    final sourceOrder = _compareSourcePriorityByWordId(
      left.candidate.source,
      right.candidate.source,
    );
    if (sourceOrder != 0) return sourceOrder;

    final posOrder =
        (right.candidate.partOfSpeech.isNotEmpty ? 1 : 0) -
        (left.candidate.partOfSpeech.isNotEmpty ? 1 : 0);
    if (posOrder != 0) return posOrder;

    final lengthOrder = left.candidate.word.length.compareTo(
      right.candidate.word.length,
    );
    if (lengthOrder != 0) return lengthOrder;

    return left.candidate.id.compareTo(right.candidate.id);
  }

  static int _compareSourcePriorityByWordId(String left, String right) {
    return _sourcePriorityValue(left).compareTo(_sourcePriorityValue(right));
  }

  static int _sourcePriorityValue(String source) {
    return _sourcePriority[source.toLowerCase()] ?? _sourcePriority.length;
  }

  static String _normalizeSearchText(String text) {
    final normalized = text.trim().replaceAll(_apostrophePattern, "'");
    return normalized.replaceAll(_spacePattern, ' ').toLowerCase();
  }

  static String _foldHeadword(String text) {
    return _normalizeSearchText(text).replaceAll("'", '');
  }

  static String _normalizedWordSql(String column) {
    return """
      LOWER(
        REPLACE(
          REPLACE(
            REPLACE(
              REPLACE(
                REPLACE(COALESCE($column, ''), CHAR(699), ''''),
                CHAR(700),
                ''''
              ),
              CHAR(96),
              ''''
            ),
            CHAR(8216),
            ''''
          ),
          CHAR(8217),
          ''''
        )
      )
    """;
  }

  static String _foldedWordSql(String column) {
    return "REPLACE(${_normalizedWordSql(column)}, '''', '')";
  }

  static List<String> _extractTokens(String text) {
    final normalized = _normalizeSearchText(text);
    return _tokenPattern
        .allMatches(normalized)
        .map((match) => match.group(0)!)
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }

  static String _normalizePosBucket(String partOfSpeech) {
    final normalized = _normalizeSearchText(partOfSpeech);
    if (normalized.isEmpty) return '';
    if (normalized.contains('noun') ||
        normalized == 'n' ||
        normalized.startsWith('n,')) {
      return 'noun';
    }
    if (normalized.contains('verb') || normalized.startsWith('v.')) {
      return 'verb';
    }
    if (normalized.contains('adj')) return 'adjective';
    if (normalized.contains('adv')) return 'adverb';
    if (normalized.contains('num')) return 'number';
    if (normalized.contains('pron') || normalized == 'pro') return 'pronoun';
    return normalized;
  }

  /// So'z tafsilotini olish.
  ///
  /// Bir xil so'zning turli manbalardan kelgan variantlari (POS bo'yicha mos
  /// keluvchi) avtomatik birlashtiriladi — barcha ta'riflar bitta ro'yxatda,
  /// har biriga manba belgisi bilan ko'rsatiladi.
  Future<Word?> getWord(int id) async {
    final rows = await db.rawQuery(
      '''
      SELECT w.*,
             CASE WHEN fav.id IS NOT NULL THEN 1 ELSE 0 END as is_favorite
      FROM words w
      LEFT JOIN favorites fav ON fav.word_id = w.id
      WHERE w.id = ?
    ''',
      [id],
    );

    if (rows.isEmpty) return null;

    final word = Word.fromMap(rows.first);
    final targetPosBucket = _normalizePosBucket(word.partOfSpeech);

    // Asosiy so'zning ta'riflari (manba belgisi asosiy so'z manbasidan)
    final defRows = await db.query(
      'definitions',
      where: 'word_id = ?',
      whereArgs: [id],
      orderBy: 'sort_order ASC',
    );
    final primaryDefinitions = defRows
        .map(
          (row) =>
              Definition.fromMap(row).copyWith(source: word.source),
        )
        .toList(growable: false);

    // Bir xil so'zning boshqa manbalaridagi variantlari (POS mos bo'lsa)
    final siblingRows = await db.rawQuery(
      '''
      SELECT
        w.id AS word_id,
        COALESCE(w.source, '') AS word_source,
        COALESCE(w.part_of_speech, '') AS part_of_speech
      FROM words w
      WHERE LOWER(w.word) = LOWER(?) AND w.id != ?
      ORDER BY w.source, w.part_of_speech, w.id
    ''',
      [word.word, word.id],
    );

    final matchingSiblingIds = <int, String>{};
    for (final row in siblingRows) {
      final pos = row['part_of_speech'] as String? ?? '';
      if (_normalizePosBucket(pos) != targetPosBucket) continue;
      matchingSiblingIds[row['word_id'] as int] =
          (row['word_source'] as String?) ?? '';
    }

    // Sibling ta'riflarini olish (manba belgisi bilan)
    final siblingDefinitions = <Definition>[];
    if (matchingSiblingIds.isNotEmpty) {
      final ids = matchingSiblingIds.keys.toList();
      final placeholders = List.filled(ids.length, '?').join(',');
      final siblingDefRows = await db.rawQuery(
        '''
        SELECT *
        FROM definitions
        WHERE word_id IN ($placeholders)
        ORDER BY word_id, sort_order ASC
        ''',
        ids,
      );
      for (final row in siblingDefRows) {
        final wordId = row['word_id'] as int;
        final sourceName = matchingSiblingIds[wordId] ?? '';
        siblingDefinitions.add(
          Definition.fromMap(row).copyWith(source: sourceName),
        );
      }
    }

    // Birlashtirish va dublikatlarni olib tashlash
    final mergedDefinitions = _mergeDefinitions([
      ...primaryDefinitions,
      ...siblingDefinitions,
    ]);

    return word.copyWith(definitions: mergedDefinitions);
  }

  /// Ta'riflarni manba bo'yicha birlashtiradi va dublikatlarni olib tashlaydi.
  ///
  /// Tartib:
  /// 1. Til bo'yicha (en → ru → uz → boshqa)
  /// 2. Manba prioriteti bo'yicha (kaikki, uzwordnet va h.k.)
  /// 3. sort_order bo'yicha
  ///
  /// Dublikatlar (case-insensitive bir xil ta'rif, bir tilda) birinchi
  /// ko'rilganicha qoldiriladi, lekin manba belgilari "kaikki, vuizur"
  /// kabi birlashtiriladi.
  List<Definition> _mergeDefinitions(List<Definition> all) {
    const langOrder = {'en': 0, 'ru': 1, 'uz': 2};

    final byKey = <String, _MergedDefinition>{};
    for (final def in all) {
      final normalized = _normalizeSearchText(def.definition);
      if (normalized.isEmpty) continue;

      final key = '${def.targetLanguage}::$normalized';
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = _MergedDefinition(
          definition: def,
          sources: {if (def.source.isNotEmpty) def.source},
        );
      } else if (def.source.isNotEmpty) {
        existing.sources.add(def.source);
      }
    }

    final merged = byKey.values.map((m) {
      final combinedSource = m.sources.isEmpty
          ? m.definition.source
          : (m.sources.toList()
                ..sort(
                  (a, b) =>
                      _sourcePriorityValue(a).compareTo(_sourcePriorityValue(b)),
                ))
              .join(', ');
      return m.definition.copyWith(source: combinedSource);
    }).toList();

    merged.sort((a, b) {
      final aLang = langOrder[a.targetLanguage] ?? 3;
      final bLang = langOrder[b.targetLanguage] ?? 3;
      if (aLang != bLang) return aLang.compareTo(bLang);

      final aFirstSource = a.source.split(',').first.trim();
      final bFirstSource = b.source.split(',').first.trim();
      final sourceOrder = _sourcePriorityValue(
        aFirstSource,
      ).compareTo(_sourcePriorityValue(bFirstSource));
      if (sourceOrder != 0) return sourceOrder;

      return a.sortOrder.compareTo(b.sortOrder);
    });

    return merged;
  }

  /// Tasodifiy so'z (kun so'zi)
  Future<Word?> getRandomWord() async {
    final rows = await db.rawQuery('''
      SELECT w.*,
             CASE WHEN fav.id IS NOT NULL THEN 1 ELSE 0 END as is_favorite
      FROM words w
      LEFT JOIN favorites fav ON fav.word_id = w.id
      JOIN definitions d ON d.word_id = w.id
      WHERE d.definition != '' AND w.word_cyrillic != ''
      ORDER BY RANDOM()
      LIMIT 1
    ''');

    if (rows.isEmpty) return null;

    final word = Word.fromMap(rows.first);
    final defRows = await db.query(
      'definitions',
      where: 'word_id = ?',
      whereArgs: [word.id],
      orderBy: 'sort_order ASC',
    );

    return word.copyWith(
      definitions: defRows.map((r) => Definition.fromMap(r)).toList(),
    );
  }
}

class _SearchPlan {
  final String normalizedQuery;
  final String foldedQuery;
  final bool hasApostrophe;
  final List<_SearchToken> tokens;

  const _SearchPlan({
    required this.normalizedQuery,
    required this.foldedQuery,
    required this.hasApostrophe,
    required this.tokens,
  });

  factory _SearchPlan.fromQuery(String rawQuery) {
    final normalized = WordRepository._normalizeSearchText(rawQuery);
    final tokens = normalized
        .split(' ')
        .map((token) => _SearchToken.fromToken(token))
        .where((token) => token.original.isNotEmpty)
        .toList(growable: false);

    return _SearchPlan(
      normalizedQuery: normalized,
      foldedQuery: normalized.replaceAll("'", ''),
      hasApostrophe: normalized.contains("'"),
      tokens: tokens,
    );
  }

  bool get isValid => normalizedQuery.isNotEmpty && tokens.isNotEmpty;

  bool get allowDefinitionMatches =>
      tokens.any((token) => token.original.length > 3);

  List<String> get transliteratedForms => tokens.length == 1
      ? tokens.first.headwordVariants
            .where((variant) => variant != normalizedQuery)
            .toSet()
            .toList(growable: false)
      : const [];

  List<String> get exactLatinForms => <String>{
    if (!UzbekTransliterator.isCyrillic(normalizedQuery)) normalizedQuery,
    ...transliteratedForms.where(
      (variant) => !UzbekTransliterator.isCyrillic(variant),
    ),
  }.toList(growable: false);

  List<String> get exactCyrillicForms => <String>{
    if (UzbekTransliterator.isCyrillic(normalizedQuery)) normalizedQuery,
    ...transliteratedForms.where(UzbekTransliterator.isCyrillic),
  }.toList(growable: false);

  List<String> get foldedQueryForms => [
    foldedQuery,
    ...tokens.expand((token) => token.foldedVariants),
  ].where((value) => value.isNotEmpty).toSet().toList(growable: false);

  String buildHeadwordMatchQuery() {
    final groups = tokens
        .map((token) {
          final variants = <String>{};

          for (final variant in token.headwordVariants) {
            final safe = _sanitizeFtsToken(variant);
            if (safe.isEmpty) continue;

            final column = UzbekTransliterator.isCyrillic(variant)
                ? 'word_cyrillic'
                : 'word';
            variants.add('$column:${_quotedPrefix(safe)}');
          }

          for (final variant in token.foldedVariants) {
            final safe = _sanitizeFtsToken(variant);
            if (safe.isEmpty) continue;
            variants.add('word_folded:${_quotedPrefix(safe)}');
          }

          if (variants.isEmpty) return '';
          return '(${variants.join(' OR ')})';
        })
        .where((group) => group.isNotEmpty)
        .toList(growable: false);

    return groups.join(' AND ');
  }

  String? buildHybridMatchQuery(String? targetLanguage) {
    if (!allowDefinitionMatches && tokens.length < 2) return null;

    final column = switch (targetLanguage) {
      'en' => 'definitions_en',
      'ru' => 'definitions_ru',
      _ => 'definitions_all',
    };

    final groups = tokens
        .map((token) {
          final variants = <String>{};
          for (final variant in token.headwordVariants) {
            final safe = _sanitizeFtsToken(variant);
            if (safe.isEmpty) continue;
            final headwordColumn = UzbekTransliterator.isCyrillic(variant)
                ? 'word_cyrillic'
                : 'word';
            variants.add('$headwordColumn:${_quotedPrefix(safe)}');
          }
          for (final variant in token.foldedVariants) {
            final safe = _sanitizeFtsToken(variant);
            if (safe.isEmpty) continue;
            variants.add('word_folded:${_quotedPrefix(safe)}');
          }
          for (final variant in token.allDefinitionVariants) {
            final safe = _sanitizeFtsToken(variant);
            if (safe.isEmpty) continue;
            variants.add('$column:${_quotedPrefix(safe)}');
          }
          if (variants.isEmpty) return '';
          return '(${variants.join(' OR ')})';
        })
        .where((group) => group.isNotEmpty)
        .toList(growable: false);

    if (groups.isEmpty) return null;
    return groups.join(' AND ');
  }

  static String _sanitizeFtsToken(String token) {
    return token.replaceAll(WordRepository._ftsReservedPattern, '');
  }

  static String _quotedPrefix(String token) => '"$token"*';
}

class _SearchToken {
  final String original;
  final List<String> headwordVariants;
  final List<String> foldedVariants;
  final List<String> allDefinitionVariants;

  const _SearchToken({
    required this.original,
    required this.headwordVariants,
    required this.foldedVariants,
    required this.allDefinitionVariants,
  });

  factory _SearchToken.fromToken(String token) {
    final original = _SearchPlan._sanitizeFtsToken(token);
    if (original.isEmpty) {
      return const _SearchToken(
        original: '',
        headwordVariants: [],
        foldedVariants: [],
        allDefinitionVariants: [],
      );
    }

    final transliterated = UzbekTransliterator.isCyrillic(original)
        ? WordRepository._normalizeSearchText(
            UzbekTransliterator.toLatin(original),
          )
        : WordRepository._normalizeSearchText(
            UzbekTransliterator.toCyrillic(original),
          );

    final headwordVariants = <String>{
      original,
      if (transliterated.isNotEmpty) transliterated,
    }.toList(growable: false);

    final foldedVariants = <String>{
      original.replaceAll("'", ''),
      transliterated.replaceAll("'", ''),
    }.where((value) => value.isNotEmpty).toList(growable: false);

    final definitionVariants = <String>{
      original,
      original.replaceAll("'", ''),
    }.where((value) => value.isNotEmpty).toList(growable: false);

    return _SearchToken(
      original: original,
      headwordVariants: headwordVariants,
      foldedVariants: foldedVariants,
      allDefinitionVariants: definitionVariants,
    );
  }
}

class _SearchCandidate {
  final int id;
  final String word;
  final String wordCyrillic;
  final String partOfSpeech;
  final String source;
  final bool isFavorite;
  final String definitionsEn;
  final String definitionsRu;
  final String definitionsAll;
  final String firstDefinitionEn;
  final String firstDefinitionRu;
  final String firstDefinitionAny;

  bool hasHeadwordHit = false;
  bool hasDefinitionHit = false;

  _SearchCandidate({
    required this.id,
    required this.word,
    required this.wordCyrillic,
    required this.partOfSpeech,
    required this.source,
    required this.isFavorite,
    required this.definitionsEn,
    required this.definitionsRu,
    required this.definitionsAll,
    required this.firstDefinitionEn,
    required this.firstDefinitionRu,
    required this.firstDefinitionAny,
  });

  factory _SearchCandidate.fromMap(Map<String, Object?> row) {
    return _SearchCandidate(
      id: row['id'] as int,
      word: row['word'] as String? ?? '',
      wordCyrillic: row['word_cyrillic'] as String? ?? '',
      partOfSpeech: row['part_of_speech'] as String? ?? '',
      source: row['source'] as String? ?? '',
      isFavorite: (row['is_favorite'] as int?) == 1,
      definitionsEn: row['definitions_en'] as String? ?? '',
      definitionsRu: row['definitions_ru'] as String? ?? '',
      definitionsAll: row['definitions_all'] as String? ?? '',
      firstDefinitionEn: row['first_def_en'] as String? ?? '',
      firstDefinitionRu: row['first_def_ru'] as String? ?? '',
      firstDefinitionAny: row['first_def_any'] as String? ?? '',
    );
  }

  void markHeadwordHit() {
    hasHeadwordHit = true;
  }

  void markDefinitionHit() {
    hasDefinitionHit = true;
  }

  String definitionText(String? language) {
    return switch (language) {
      'en' => definitionsEn,
      'ru' => definitionsRu,
      _ => definitionsAll,
    };
  }

  String preferredDefinition({
    required String? targetLanguage,
    String? matchedTargetLanguage,
  }) {
    if (targetLanguage == 'en' && firstDefinitionEn.isNotEmpty) {
      return firstDefinitionEn;
    }
    if (targetLanguage == 'ru' && firstDefinitionRu.isNotEmpty) {
      return firstDefinitionRu;
    }
    if (matchedTargetLanguage == 'en' && firstDefinitionEn.isNotEmpty) {
      return firstDefinitionEn;
    }
    if (matchedTargetLanguage == 'ru' && firstDefinitionRu.isNotEmpty) {
      return firstDefinitionRu;
    }
    if (firstDefinitionAny.isNotEmpty) return firstDefinitionAny;
    if (firstDefinitionEn.isNotEmpty) return firstDefinitionEn;
    return firstDefinitionRu;
  }

  /// Tanlangan tilda ta'rif mavjudmi (saralash uchun).
  bool hasDefinitionInLanguage(String language) {
    return switch (language) {
      'en' => firstDefinitionEn.isNotEmpty,
      'ru' => firstDefinitionRu.isNotEmpty,
      _ => firstDefinitionAny.isNotEmpty,
    };
  }
}

class _ScoredCandidate {
  final _SearchCandidate candidate;
  final SearchMatchKind matchKind;
  final double score;
  final String previewDefinition;
  final String? matchedTargetLanguage;

  const _ScoredCandidate({
    required this.candidate,
    required this.matchKind,
    required this.score,
    required this.previewDefinition,
    required this.matchedTargetLanguage,
  });
}

class _FallbackResult {
  SearchResult result;
  int matchCount;

  _FallbackResult({required this.result, required this.matchCount});
}

class _MergedDefinition {
  final Definition definition;
  final Set<String> sources;

  _MergedDefinition({required this.definition, required this.sources});
}
