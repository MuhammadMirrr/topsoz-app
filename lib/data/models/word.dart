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
  final List<RelatedWordEntry> relatedEntries;
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
    this.relatedEntries = const [],
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
    List<RelatedWordEntry>? relatedEntries,
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
      relatedEntries: relatedEntries ?? this.relatedEntries,
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

  const Definition({
    required this.id,
    required this.wordId,
    required this.definition,
    this.targetLanguage = 'en',
    this.exampleSource = '',
    this.exampleTarget = '',
    this.sortOrder = 0,
  });

  factory Definition.fromMap(Map<String, dynamic> map) {
    return Definition(
      id: map['id'] as int,
      wordId: map['word_id'] as int,
      definition: map['definition'] as String? ?? '',
      targetLanguage: map['target_language'] as String? ?? 'en',
      exampleSource: map['example_source'] as String? ?? '',
      exampleTarget: map['example_target'] as String? ?? '',
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }
}

class RelatedWordEntry {
  final int id;
  final String source;
  final String partOfSpeech;
  final String firstDefinition;

  const RelatedWordEntry({
    required this.id,
    required this.source,
    this.partOfSpeech = '',
    this.firstDefinition = '',
  });
}
