enum SearchScope {
  channels,
  topics,
  all,
}

enum SearchResultMode {
  exhaustive, // e.g. "all", "list of all" - return full list without artificial caps
  ranked, // e.g. "top", "best", "popular" - rank by engagement/reputation
  trending, // e.g. "trending", "latest viral"
  recent, // e.g. "new", "recently added"
}

class AiSearchIntent {
  AiSearchIntent({
    required this.rawQuery,
    required this.cleanKeywords,
    this.detectedLanguage,
    this.detectedLanguageCode,
    this.detectedCategory,
    this.semanticSynonyms = const [],
    this.subdomains = const [],
    this.excludedTerms = const [],
    this.filters = const {},
    this.isConversational = false,
    this.scope = SearchScope.all,
    this.resultMode = SearchResultMode.ranked,
    this.confidence = 1.0,
    this.requiresCloudAi = false,
    this.explanation = '',
    this.broadenPrompt,
  });

  factory AiSearchIntent.fromMap(Map<String, dynamic> map) {
    return AiSearchIntent(
      rawQuery: map['rawQuery'] as String? ?? '',
      cleanKeywords: List<String>.from(map['cleanKeywords'] ?? []),
      detectedLanguage: map['detectedLanguage'] as String?,
      detectedLanguageCode: map['detectedLanguageCode'] as String?,
      detectedCategory: map['detectedCategory'] as String?,
      semanticSynonyms: List<String>.from(map['semanticSynonyms'] ?? []),
      subdomains: List<String>.from(map['subdomains'] ?? []),
      excludedTerms: List<String>.from(map['excludedTerms'] ?? []),
      filters: Map<String, dynamic>.from(map['filters'] ?? {}),
      isConversational: map['isConversational'] as bool? ?? false,
      scope: SearchScope.values.firstWhere(
        (e) => e.name == map['scope'],
        orElse: () => SearchScope.all,
      ),
      resultMode: SearchResultMode.values.firstWhere(
        (e) => e.name == map['resultMode'],
        orElse: () => SearchResultMode.ranked,
      ),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      requiresCloudAi: map['requiresCloudAi'] as bool? ?? false,
      explanation: map['explanation'] as String? ?? '',
      broadenPrompt: map['broadenPrompt'] as String?,
    );
  }

  final String rawQuery;
  final List<String> cleanKeywords;
  final String? detectedLanguage;
  final String? detectedLanguageCode;
  final String? detectedCategory;
  final List<String> semanticSynonyms;
  final List<String> subdomains;
  final List<String> excludedTerms;
  final Map<String, dynamic> filters;
  final bool isConversational;
  final SearchScope scope;
  final SearchResultMode resultMode;
  final double confidence;
  final bool requiresCloudAi;
  final String explanation;
  final String? broadenPrompt;

  Map<String, dynamic> toMap() => {
    'rawQuery': rawQuery,
    'cleanKeywords': cleanKeywords,
    'detectedLanguage': detectedLanguage,
    'detectedLanguageCode': detectedLanguageCode,
    'detectedCategory': detectedCategory,
    'semanticSynonyms': semanticSynonyms,
    'subdomains': subdomains,
    'excludedTerms': excludedTerms,
    'filters': filters,
    'isConversational': isConversational,
    'scope': scope.name,
    'resultMode': resultMode.name,
    'confidence': confidence,
    'requiresCloudAi': requiresCloudAi,
    'explanation': explanation,
    'broadenPrompt': broadenPrompt,
  };

  /// Convenience getter for category tokens or multi-category filtering
  List<String> get detectedCategories =>
      detectedCategory != null && detectedCategory!.trim().isNotEmpty
          ? [detectedCategory!.trim()]
          : const [];

  /// Returns all search tokens to check against titles, descriptions, and categories
  List<String> get allTokens {
    final tokens = <String>{
      ...cleanKeywords,
      ...semanticSynonyms,
      ...subdomains,
    };
    return tokens.where((t) => t.trim().isNotEmpty).toList();
  }

  /// True if there is a detected criteria (language, category, or semantic keywords)
  bool get hasCriteria =>
      (detectedLanguage != null && detectedLanguage!.isNotEmpty) ||
      (detectedCategory != null && detectedCategory!.isNotEmpty) ||
      allTokens.isNotEmpty;

  AiSearchIntent copyWith({
    String? rawQuery,
    List<String>? cleanKeywords,
    String? detectedLanguage,
    String? detectedLanguageCode,
    bool clearLanguage = false,
    String? detectedCategory,
    List<String>? semanticSynonyms,
    List<String>? subdomains,
    List<String>? excludedTerms,
    Map<String, dynamic>? filters,
    bool? isConversational,
    SearchScope? scope,
    SearchResultMode? resultMode,
    double? confidence,
    bool? requiresCloudAi,
    String? explanation,
    String? broadenPrompt,
  }) {
    return AiSearchIntent(
      rawQuery: rawQuery ?? this.rawQuery,
      cleanKeywords: cleanKeywords ?? this.cleanKeywords,
      detectedLanguage: clearLanguage
          ? null
          : (detectedLanguage ?? this.detectedLanguage),
      detectedLanguageCode: clearLanguage
          ? null
          : (detectedLanguageCode ?? this.detectedLanguageCode),
      detectedCategory: detectedCategory ?? this.detectedCategory,
      semanticSynonyms: semanticSynonyms ?? this.semanticSynonyms,
      subdomains: subdomains ?? this.subdomains,
      excludedTerms: excludedTerms ?? this.excludedTerms,
      filters: filters ?? this.filters,
      isConversational: isConversational ?? this.isConversational,
      scope: scope ?? this.scope,
      resultMode: resultMode ?? this.resultMode,
      confidence: confidence ?? this.confidence,
      requiresCloudAi: requiresCloudAi ?? this.requiresCloudAi,
      explanation: explanation ?? this.explanation,
      broadenPrompt: broadenPrompt ?? this.broadenPrompt,
    );
  }

  @override
  String toString() =>
      'AiSearchIntent(lang: $detectedLanguage($detectedLanguageCode), mode: ${resultMode.name}, conf: $confidence, tokens: $allTokens, explanation: "$explanation")';
}
