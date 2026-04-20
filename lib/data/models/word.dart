/// HTML teglarni olib tashlaydi, entitylarni dekod qiladi.
///
/// Ba'zi manbalar (masalan vuizur) xom HTML bilan keladi:
/// `<i>noun</i><br><ol><li>oblast, province</li></ol>`
/// Bu funksiya teglarni olib, ro'yxat elementlarini `•` ga, `<br>` ni
/// yangi qatorga aylantiradi. Xavfsizlik fallbackidir — asosiy tozalash
/// build-time da (tools/build_database.py) amalga oshiriladi.
String stripHtml(String text) {
  if (text.isEmpty) return text;
  if (!text.contains('<') && !text.contains('&')) return text;

  var result = text;

  // Ro'yxat va qator uzilishlarini belgilash (tegdan oldin)
  result = result.replaceAllMapped(
    RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false),
    (_) => '\n',
  );
  result = result.replaceAllMapped(
    RegExp(r'<\s*li\s*[^>]*>', caseSensitive: false),
    (_) => '\n• ',
  );
  result = result.replaceAllMapped(
    RegExp(r'<\s*/\s*(p|div|ol|ul|li)\s*>', caseSensitive: false),
    (_) => '\n',
  );

  // Qolgan barcha teglarni olib tashlash
  result = result.replaceAll(RegExp(r'<[^>]+>'), '');

  // HTML entitylarni dekod qilish (eng ko'p uchraydiganlar)
  result = result
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ');

  // Raqamli entitylar (&#123;, &#x1F;)
  result = result.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final code = int.tryParse(m.group(1)!);
    return code == null ? m.group(0)! : String.fromCharCode(code);
  });
  result = result.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
    final code = int.tryParse(m.group(1)!, radix: 16);
    return code == null ? m.group(0)! : String.fromCharCode(code);
  });

  // Bir nechta bo'sh qatorlarni siqish
  result = result.replaceAll(RegExp(r'\n\s*\n+'), '\n');

  // Bosh/oxirgi bo'shliqlarni tozalash
  return result.trim();
}

class Word {
  final int id;
  final String word;
  final String wordCyrillic;
  final String language;
  final String partOfSpeech;
  final String pronunciation;
  final String etymology;
  final String source;
  final List<Definition> definitions;
  final bool isFavorite;

  const Word({
    required this.id,
    required this.word,
    this.wordCyrillic = '',
    this.language = 'uz',
    this.partOfSpeech = '',
    this.pronunciation = '',
    this.etymology = '',
    this.source = '',
    this.definitions = const [],
    this.isFavorite = false,
  });

  Word copyWith({
    int? id,
    String? word,
    String? wordCyrillic,
    String? language,
    String? partOfSpeech,
    String? pronunciation,
    String? etymology,
    String? source,
    List<Definition>? definitions,
    bool? isFavorite,
  }) {
    return Word(
      id: id ?? this.id,
      word: word ?? this.word,
      wordCyrillic: wordCyrillic ?? this.wordCyrillic,
      language: language ?? this.language,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      pronunciation: pronunciation ?? this.pronunciation,
      etymology: etymology ?? this.etymology,
      source: source ?? this.source,
      definitions: definitions ?? this.definitions,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int,
      word: map['word'] as String? ?? '',
      wordCyrillic: map['word_cyrillic'] as String? ?? '',
      language: map['language'] as String? ?? 'uz',
      partOfSpeech: map['part_of_speech'] as String? ?? '',
      pronunciation: map['pronunciation'] as String? ?? '',
      etymology: map['etymology'] as String? ?? '',
      source: map['source'] as String? ?? '',
      isFavorite: (map['is_favorite'] as int?) == 1,
    );
  }
}

class Definition {
  final int id;
  final int wordId;
  final String definition;
  final String targetLanguage;
  final String exampleSource;
  final String exampleTarget;
  final int sortOrder;

  /// Ta'rif olingan manba nomi (kaikki, vuizur va h.k.).
  /// Birlashtirilgan ro'yxatda manba belgisini ko'rsatish uchun.
  final String source;

  const Definition({
    required this.id,
    required this.wordId,
    required this.definition,
    this.targetLanguage = 'en',
    this.exampleSource = '',
    this.exampleTarget = '',
    this.sortOrder = 0,
    this.source = '',
  });

  Definition copyWith({String? source}) {
    return Definition(
      id: id,
      wordId: wordId,
      definition: definition,
      targetLanguage: targetLanguage,
      exampleSource: exampleSource,
      exampleTarget: exampleTarget,
      sortOrder: sortOrder,
      source: source ?? this.source,
    );
  }

  factory Definition.fromMap(Map<String, dynamic> map) {
    return Definition(
      id: map['id'] as int,
      wordId: map['word_id'] as int,
      definition: stripHtml(map['definition'] as String? ?? ''),
      targetLanguage: map['target_language'] as String? ?? 'en',
      exampleSource: stripHtml(map['example_source'] as String? ?? ''),
      exampleTarget: stripHtml(map['example_target'] as String? ?? ''),
      sortOrder: map['sort_order'] as int? ?? 0,
      source: map['source'] as String? ?? '',
    );
  }
}

