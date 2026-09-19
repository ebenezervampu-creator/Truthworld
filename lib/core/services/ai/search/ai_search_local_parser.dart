import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/core/services/ai/search/ai_search_knowledge_graph.dart';

/// Instant, deterministic local natural language intent parser.
class AiSearchLocalParser {
  const AiSearchLocalParser();

  /// Parses user natural language query into an [AiSearchIntent] instantly at 0ms latency.
  AiSearchIntent parseLocally(
    String query, {
    SearchScope scope = SearchScope.all,
  }) {
    final lowerQuery = query.toLowerCase().trim();

    // 1. Detect Result Mode (Exhaustive vs Ranked vs Trending vs Recent)
    var resultMode = SearchResultMode.ranked;
    if (lowerQuery.contains('all') ||
        lowerQuery.contains('list of') ||
        lowerQuery.contains('full list') ||
        lowerQuery.contains('every') ||
        lowerQuery.contains('complete list')) {
      resultMode = SearchResultMode.exhaustive;
    } else if (lowerQuery.contains('trending') ||
        lowerQuery.contains('viral') ||
        lowerQuery.contains('rising')) {
      resultMode = SearchResultMode.trending;
    } else if (lowerQuery.contains('new') ||
        lowerQuery.contains('recent') ||
        lowerQuery.contains('latest')) {
      resultMode = SearchResultMode.recent;
    }

    // 2. Detect Negations / Exclusions ("rather than X", "not X", "except X", "without X")
    final excludedTerms = <String>[];
    var sanitizedForNegation = lowerQuery;

    final negationPatterns = [
      RegExp(r'rather than\s+([^,]+)'),
      RegExp(r'instead of\s+([^,]+)'),
      RegExp(r'except\s+([^,]+)'),
      RegExp(r'excluding\s+([^,]+)'),
      RegExp(r'without\s+([^,]+)'),
    ];

    for (final pattern in negationPatterns) {
      final match = pattern.firstMatch(sanitizedForNegation);
      if (match != null && match.groupCount >= 1) {
        final excludedRaw = match.group(1)?.trim() ?? '';
        if (excludedRaw.isNotEmpty) {
          excludedTerms.add(excludedRaw);
          final parts = excludedRaw
              .split(RegExp(r'\s+'))
              .where((w) => !AiSearchKnowledgeGraph.fillerWords.contains(w));
          for (final p in parts) {
            if (!excludedTerms.contains(p)) {
              excludedTerms.add(p);
            }
          }
        }
        sanitizedForNegation = sanitizedForNegation.replaceFirst(pattern, '');
      }
    }

    // 3. Detect Language
    String? detectedLang;
    String? detectedLangCode;

    for (final entry in AiSearchKnowledgeGraph.languageMap.entries) {
      for (final alias in entry.value) {
        final regex = RegExp(r'\b' + RegExp.escape(alias) + r'\b');
        if (regex.hasMatch(sanitizedForNegation)) {
          detectedLang = entry.key;
          detectedLangCode = AiSearchKnowledgeGraph.languageCodeMap[entry.key];
          sanitizedForNegation = sanitizedForNegation.replaceFirst(regex, ' ');
          break;
        }
      }
      if (detectedLang != null) break;
    }

    // 4. Match Semantic Domains & Subdomains
    String? detectedCat;
    final semanticSynonyms = <String>{};
    final subdomains = <String>[];
    String? broadenPrompt;
    var domainMatched = false;

    for (final entry in AiSearchKnowledgeGraph.semanticDomains.entries) {
      final key = entry.key;
      final info = entry.value;
      final synList = (info['synonyms'] as List<String>?) ?? [];

      // Check if query contains this domain key or synonyms with word boundaries
      var matchesDomain = false;
      final keyRegex = RegExp(r'\b' + RegExp.escape(key) + r'\b');
      if (keyRegex.hasMatch(sanitizedForNegation)) {
        matchesDomain = true;
      } else {
        for (final syn in synList) {
          final synRegex = RegExp(r'\b' + RegExp.escape(syn) + r'\b');
          if (synRegex.hasMatch(sanitizedForNegation)) {
            matchesDomain = true;
            break;
          }
        }
      }

      if (matchesDomain) {
        domainMatched = true;
        detectedCat = info['category'] as String?;
        semanticSynonyms.addAll(synList);
        subdomains.addAll((info['subdomains'] as List<String>?) ?? []);
        broadenPrompt = info['broaden'] as String?;
        break;
      }
    }

    // 5. Clean Keywords & Filler Word Stripping
    final tokens = sanitizedForNegation
        .split(RegExp(r'[\s,\.\?!;:]+'))
        .map((t) => t.trim())
        .where(
          (t) =>
              t.isNotEmpty && !AiSearchKnowledgeGraph.fillerWords.contains(t),
        )
        .toList();

    // Check if query was conversational
    final isConversational = lowerQuery
        .split(RegExp(r'\s+'))
        .any(
          (w) => const {
            'want',
            'list',
            'channels',
            'topics',
            'show',
            'showing',
            'give',
            'find',
          }.contains(w),
        );

    // 6. Calculate Confidence
    var confidence = 0.60;
    if (detectedLang != null && domainMatched) {
      confidence = 0.95;
    } else if (domainMatched) {
      confidence = 0.88;
    } else if (detectedLang != null) {
      confidence = 0.80;
    } else if (tokens.isEmpty) {
      confidence = 0.0;
    } else if (!isConversational && tokens.length <= 5) {
      // Direct, clean keyword search without conversational ambiguity
      confidence = 0.85;
    }

    // Complexity flags (e.g., long nuanced clauses)
    final requiresCloudAi =
        (lowerQuery.length > 80 && !domainMatched) ||
        (tokens.length > 6 && !domainMatched);

    // 7. Human-friendly Explanation
    var explanation = '';
    final langName = detectedLang != null
        ? '${detectedLang[0].toUpperCase()}${detectedLang.substring(1)}'
        : '';

    if (detectedLang != null && domainMatched) {
      final domainName =
          AiSearchKnowledgeGraph.semanticDomains.entries
              .firstWhere(
                (e) => e.value['category'] == detectedCat,
                orElse: () => const MapEntry('', {}),
              )
              .value['domain'] ??
          detectedCat;
      explanation = resultMode == SearchResultMode.exhaustive
          ? 'Showing all $langName $domainName channels'
          : 'Showing top $langName $domainName channels';
    } else if (domainMatched) {
      explanation = resultMode == SearchResultMode.exhaustive
          ? 'Showing all channels matching $detectedCat'
          : 'Showing top channels matching $detectedCat';
    } else if (detectedLang != null) {
      explanation = 'Showing $langName channels';
    } else if (tokens.isNotEmpty) {
      explanation = 'Searching for "${tokens.join(' ')}"';
    }

    return AiSearchIntent(
      rawQuery: query,
      cleanKeywords: tokens,
      detectedLanguage: detectedLang,
      detectedLanguageCode: detectedLangCode,
      detectedCategory: detectedCat,
      semanticSynonyms: semanticSynonyms.toList(),
      subdomains: subdomains,
      excludedTerms: excludedTerms,
      isConversational: isConversational,
      scope: scope,
      resultMode: resultMode,
      confidence: confidence,
      requiresCloudAi: requiresCloudAi,
      explanation: explanation,
      broadenPrompt: broadenPrompt,
    );
  }
}
