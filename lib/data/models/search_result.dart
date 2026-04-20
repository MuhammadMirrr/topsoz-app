enum SearchMatchKind {
  exactHeadword,
  exactTransliteration,
  exactFoldedHeadword,
  prefixHeadword,
  compoundHeadword,
  foldedPrefix,
  definitionPhrase,
  definitionToken,
}

class SearchResult {
  final int wordId;
  final String word;
  final String wordCyrillic;
  final String partOfSpeech;
  final String firstDefinition;
  final bool isFavorite;
  final SearchMatchKind matchKind;
  final double score;
  final int duplicateCount;
  final String? matchedTargetLanguage;

  const SearchResult({
    required this.wordId,
    required this.word,
    this.wordCyrillic = '',
    this.partOfSpeech = '',
    this.firstDefinition = '',
    this.isFavorite = false,
    this.matchKind = SearchMatchKind.definitionToken,
    this.score = 0,
    this.duplicateCount = 1,
    this.matchedTargetLanguage,
  });
}
