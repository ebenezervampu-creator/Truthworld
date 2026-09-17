import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';

class AiSearchService {
  AiSearchService._();
  static final AiSearchService instance = AiSearchService._();

  // In-memory query intent cache for instant re-lookup
  final Map<String, AiSearchIntent> _intentCache = {};

  /// Optional delegate hook for testing Cloud Function intent responses
  @visibleForTesting
  Future<AiSearchIntent?> Function(String query, SearchScope scope)?
  cloudAssistantHandler;

  // Circuit breaker state to prevent spamming failing Cloud Function
  DateTime? _cloudCooldownUntil;
  int _consecutiveCloudFailures = 0;
  static const int _kMaxConsecutiveFailuresBeforeTrip = 1;
  static const Duration _kCircuitBreakerCooldown = Duration(minutes: 3);

  /// Check if the cloud assistant circuit breaker is active (in cooldown)
  bool get isCloudAssistantInCooldown {
    if (_cloudCooldownUntil == null) return false;
    if (DateTime.now().isAfter(_cloudCooldownUntil!)) {
      _cloudCooldownUntil = null; // Half-open: probe next request
      return false;
    }
    return true;
  }

  /// Manually reset circuit breaker (useful for tests or network reconnection)
  @visibleForTesting
  void resetCircuitBreaker() {
    _cloudCooldownUntil = null;
    _consecutiveCloudFailures = 0;
  }

  /// Clear the query intent cache (useful between tests)
  @visibleForTesting
  void clearCache() {
    _intentCache.clear();
    resetCircuitBreaker();
  }

  static const double kConfidenceThreshold = 0.75;

  // Language mapping
  static const Map<String, List<String>> _languageMap = {
    'telugu': ['telugu', 'te'],
    'english': ['english', 'en'],
    'hindi': ['hindi', 'hi'],
    'tamil': ['tamil', 'ta'],
    'kannada': ['kannada', 'kn'],
    'malayalam': ['malayalam', 'ml'],
    'spanish': ['spanish', 'es'],
    'french': ['french', 'fr'],
    'german': ['german', 'de'],
  };

  static const Map<String, String> _languageCodeMap = {
    'telugu': 'te',
    'english': 'en',
    'hindi': 'hi',
    'tamil': 'ta',
    'kannada': 'kn',
    'malayalam': 'ml',
    'spanish': 'es',
    'french': 'fr',
    'german': 'de',
  };

  // Conversational filler words & phrases to strip
  static const Set<String> _fillerWords = {
    'i',
    'me',
    'my',
    'want',
    'all',
    'the',
    'list',
    'of',
    'channel',
    'channels',
    'topic',
    'topics',
    'video',
    'videos',
    'show',
    'shows',
    'then',
    'showing',
    'give',
    'find',
    'look',
    'looking',
    'for',
    'which',
    'that',
    'are',
    'is',
    'please',
    'get',
    'can',
    'you',
    'a',
    'an',
    'some',
    'from',
    'about',
    'in',
    'on',
    'with',
    'discuss',
    'discussing',
    'content',
    'creators',
    'creator',
    'preferably',
    'related',
    'to',
    'tell',
    'search',
    'etc',
    'and',
    'or',
    'but',
    'also',
    'like',
    'do',
    'does',
  };

  // Comprehensive Semantic Knowledge Graph
  static final Map<String, Map<String, dynamic>> _semanticDomains = {
    'christian': {
      'category': 'religion',
      'domain': 'Christianity & Faith',
      'synonyms': [
        'christian',
        'christianity',
        'jesus',
        'bible',
        'church',
        'gospel',
        'pastor',
        'worship',
        'faith',
        'prayer',
        'christ',
        'devotional',
        'ministry',
        'scripture',
        'theology',
        'hymn',
        'praise',
      ],
      'subdomains': [
        'Bible Study',
        'Gospel & Worship',
        'Christian Theology',
        'Sermons & Preachers',
        'Church Ministries',
      ],
      'broaden': 'Christian channels across all languages',
    },
    'hindu': {
      'category': 'religion',
      'domain': 'Hinduism & Sanatana Dharma',
      'synonyms': [
        'hindu',
        'hinduism',
        'sanatana',
        'dharma',
        'vedas',
        'upanishads',
        'bhagavad gita',
        'temple',
        'puja',
        'mantra',
        'bhajan',
        'devotional',
        'spiritual',
        'sloka',
      ],
      'subdomains': [
        'Bhagavad Gita & Philosophy',
        'Vedas & Upanishads',
        'Temples & Pilgrimage',
        'Bhajans & Kirtans',
        'Spiritual Discourses',
      ],
      'broaden': 'Hindu devotional channels across all languages',
    },
    'muslim': {
      'category': 'religion',
      'domain': 'Islam & Faith',
      'synonyms': [
        'islam',
        'muslim',
        'quran',
        'allah',
        'hadith',
        'mosque',
        'islamic',
        'ramadan',
        'dua',
        'prophet',
        'deen',
      ],
      'subdomains': [
        'Quran Recitation',
        'Islamic Lectures',
        'Hadith & Sunnah',
        'History of Islam',
      ],
      'broaden': 'Islamic channels across all languages',
    },
    'atheist': {
      'category': 'philosophy',
      'domain': 'Atheism & Rationalism',
      'synonyms': [
        'atheist',
        'atheism',
        'rationalism',
        'secular',
        'freethought',
        'humanism',
        'agnostic',
        'skeptic',
        'critical thinking',
        'science debate',
      ],
      'subdomains': [
        'Rationalist Debates',
        'Secular Humanism',
        'Scientific Skepticism',
        'Philosophy of Religion',
      ],
      'broaden': 'Atheist and rationalist channels',
    },
    'science': {
      'category': 'science',
      'domain': 'Science & Space',
      'synonyms': [
        'science',
        'space',
        'astronomy',
        'astrophysics',
        'cosmology',
        'physics',
        'quantum',
        'biology',
        'chemistry',
        'universe',
        'nasa',
        'isro',
        'stem',
        'galaxy',
        'black hole',
      ],
      'subdomains': [
        'Astronomy',
        'Astrophysics',
        'Cosmology',
        'Black Holes',
        'Planetary Science',
        'Space Exploration',
        'NASA / ISRO',
      ],
      'broaden': 'All science & astronomy channels',
    },
    'space': {
      'category': 'science',
      'domain': 'Space & Astronomy',
      'synonyms': [
        'space',
        'astronomy',
        'astrophysics',
        'cosmology',
        'universe',
        'nasa',
        'isro',
        'galaxy',
        'black hole',
        'planets',
        'telescope',
      ],
      'subdomains': [
        'Astronomy',
        'Astrophysics',
        'Cosmology',
        'Black Holes',
        'Planetary Science',
        'Space Exploration',
      ],
      'broaden': 'All space exploration channels',
    },
    'ai': {
      'category': 'technology',
      'domain': 'AI & Robotics',
      'synonyms': [
        'ai',
        'artificial intelligence',
        'machine learning',
        'deep learning',
        'robotics',
        'tech',
        'automation',
        'neural networks',
        'llm',
        'generative ai',
      ],
      'subdomains': [
        'Artificial Intelligence',
        'Machine Learning',
        'Autonomous Agents',
        'Robotics & Hardware',
        'Future of AI',
      ],
      'broaden': 'All AI and technology channels',
    },
    'technology': {
      'category': 'technology',
      'domain': 'Technology & Coding',
      'synonyms': [
        'tech',
        'technology',
        'coding',
        'programming',
        'software',
        'developer',
        'flutter',
        'python',
        'gadgets',
        'computer',
        'web dev',
      ],
      'subdomains': [
        'Software Development',
        'Gadgets & Mobile Tech',
        'Web Development',
        'Cybersecurity',
      ],
      'broaden': 'All technology channels',
    },
    'case study': {
      'category': 'business & finance',
      'domain': 'Business & Case Studies',
      'synonyms': [
        'case study',
        'case studies',
        'business',
        'analysis',
        'breakdown',
        'company',
        'strategy',
        'finance',
        'startup',
        'market analysis',
      ],
      'subdomains': [
        'Company Breakdowns',
        'Startup Case Studies',
        'Business Strategies',
        'Financial Analyses',
      ],
      'broaden': 'All business & case study channels',
    },
    'business': {
      'category': 'business & finance',
      'domain': 'Business & Finance',
      'synonyms': [
        'business',
        'finance',
        'economics',
        'startup',
        'investing',
        'stock market',
        'wealth',
        'entrepreneurship',
        'crypto',
      ],
      'subdomains': [
        'Stock Market & Trading',
        'Startups & Venture',
        'Personal Finance',
        'Global Economics',
      ],
      'broaden': 'All finance and business channels',
    },
    'news': {
      'category': 'news',
      'domain': 'News & Geopolitics',
      'synonyms': [
        'news',
        'politics',
        'geopolitics',
        'current affairs',
        'world',
        'diplomacy',
        'government',
        'elections',
        'debates',
      ],
      'subdomains': [
        'World News',
        'National Politics',
        'Geopolitics & Defense',
        'Current Affairs Debates',
      ],
      'broaden': 'All news & analysis channels',
    },
    'health': {
      'category': 'health & fitness',
      'domain': 'Health & Fitness',
      'synonyms': [
        'health',
        'fitness',
        'workout',
        'nutrition',
        'diet',
        'exercise',
        'gym',
        'wellness',
        'mental health',
        'yoga',
      ],
      'subdomains': [
        'Workouts & Gym',
        'Nutrition & Diets',
        'Mental Wellness',
        'Yoga & Meditation',
      ],
      'broaden': 'All health & fitness channels',
    },
  };

  /// Parses user natural language query with Instant Local Intent Parser
  /// and falls back to Cloud Gemini only for ambiguous / low-confidence queries.
  Future<AiSearchIntent> parseQuery(
    String query, {
    SearchScope scope = SearchScope.all,
  }) async {
    final rawTrimmed = query.trim();
    if (rawTrimmed.isEmpty) {
      return AiSearchIntent(
        rawQuery: '',
        cleanKeywords: [],
        scope: scope,
      );
    }

    final cacheKey = '$rawTrimmed:${scope.name}'.toLowerCase();
    if (_intentCache.containsKey(cacheKey)) {
      return _intentCache[cacheKey]!;
    }

    // Step 1: Instant Local Intent Parsing
    final localIntent = _parseLocally(rawTrimmed, scope: scope);

    // Step 2: Confidence & Complexity Check
    // If local confidence is high, OR if cloud assistant is cooling down after a failure,
    // immediately serve the deterministic local intent at 0ms latency.
    if ((localIntent.confidence >= kConfidenceThreshold &&
            !localIntent.requiresCloudAi) ||
        isCloudAssistantInCooldown) {
      _intentCache[cacheKey] = localIntent;
      return localIntent;
    }

    // Step 3: Complex / Ambiguous Query -> Gemini Cloud Function Fallback
    try {
      final cloudIntent = await _callGeminiAssistant(rawTrimmed, scope: scope);
      if (cloudIntent != null) {
        _consecutiveCloudFailures = 0;
        _intentCache[cacheKey] = cloudIntent;
        return cloudIntent;
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AiSearchService.determineIntent.geminiCloud',
      );
      _consecutiveCloudFailures++;
      if (_consecutiveCloudFailures >= _kMaxConsecutiveFailuresBeforeTrip) {
        _cloudCooldownUntil = DateTime.now().add(_kCircuitBreakerCooldown);
      }
    }

    // Fallback to local intent if cloud fails
    _intentCache[cacheKey] = localIntent;
    return localIntent;
  }

  /// Instant, deterministic local intent parser
  AiSearchIntent _parseLocally(
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
              .where((w) => !_fillerWords.contains(w));
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

    for (final entry in _languageMap.entries) {
      for (final alias in entry.value) {
        final regex = RegExp(r'\b' + RegExp.escape(alias) + r'\b');
        if (regex.hasMatch(sanitizedForNegation)) {
          detectedLang = entry.key;
          detectedLangCode = _languageCodeMap[entry.key];
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

    for (final entry in _semanticDomains.entries) {
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
        .where((t) => t.isNotEmpty && !_fillerWords.contains(t))
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
          _semanticDomains.entries
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

  /// Calls Cloud Function `aiSearchAssistant` (backed by Gemini 2.5 Flash)
  Future<AiSearchIntent?> _callGeminiAssistant(
    String query, {
    SearchScope scope = SearchScope.all,
  }) async {
    if (cloudAssistantHandler != null) {
      return cloudAssistantHandler!(query, scope);
    }

    final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
        .httpsCallable(
          'aiSearchAssistant',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 4)),
        );

    final res = await callable.call({
      'query': query,
      'scope': scope.name,
    });

    final rawData = res.data;
    if (rawData == null || rawData is! Map) return null;
    final data = Map<String, dynamic>.from(rawData);
    if (data.isEmpty) return null;

    final cleanKw =
        (data['cleanKeywords'] as Iterable?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    final synList =
        (data['semanticSynonyms'] as Iterable?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    final subList =
        (data['subdomains'] as Iterable?)?.map((e) => e.toString()).toList() ??
        <String>[];
    final excList =
        (data['excludedTerms'] as Iterable?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    return AiSearchIntent.fromMap({
      'rawQuery': query,
      'cleanKeywords': cleanKw,
      'detectedLanguage': data['detectedLanguage']?.toString(),
      'detectedLanguageCode': data['detectedLanguageCode']?.toString(),
      'detectedCategory': data['detectedCategory']?.toString(),
      'semanticSynonyms': synList,
      'subdomains': subList,
      'excludedTerms': excList,
      'isConversational': data['isConversational'] as bool? ?? true,
      'scope': scope.name,
      'resultMode': data['resultMode']?.toString() ?? 'ranked',
      'confidence': (data['confidence'] as num?)?.toDouble() ?? 0.95,
      'requiresCloudAi': false,
      'explanation': data['explanation']?.toString() ?? '',
      'broadenPrompt': data['broadenPrompt']?.toString(),
    });
  }

  // ==========================================================================
  // CHANNEL SCORING & RELEVANCE RANKING
  // ==========================================================================

  /// Scores a channel against the parsed AI intent
  /// Returns 0.0 if not a match, or a positive relevance score.
  double scoreChannel(Channel channel, AiSearchIntent intent) {
    // Check exclusions first
    final lowerName = channel.name.toLowerCase();
    final lowerHandle = channel.handle.toLowerCase();
    final lowerDesc = channel.description.toLowerCase();
    final lowerCat = channel.category.toLowerCase();
    final lowerCats = channel.categories.map((c) => c.toLowerCase()).toList();
    final channelLang = channel.language.toLowerCase().trim();

    for (final excluded in intent.excludedTerms) {
      final exc = excluded.toLowerCase();
      if (lowerName.contains(exc) ||
          lowerHandle.contains(exc) ||
          lowerDesc.contains(exc)) {
        return 0.0;
      }
    }

    var score = 0.0;

    // 1. Language matching
    if (intent.detectedLanguage != null &&
        intent.detectedLanguage!.isNotEmpty) {
      final lang = intent.detectedLanguage!.toLowerCase();
      final langCode = intent.detectedLanguageCode?.toLowerCase() ?? '';

      final isLangMatch =
          channelLang == lang ||
          channelLang == langCode ||
          (channelLang.contains(lang) || channelLang.contains(langCode)) ||
          lowerName.contains(lang) ||
          lowerDesc.contains(lang);

      if (isLangMatch) {
        score += 50.0;
      } else {
        // Strict language filter: if query explicitly specified a language,
        // channels that don't match the language are excluded
        return 0.0;
      }
    }

    // 2. Semantic concepts & keywords
    final allTokens = intent.allTokens;
    var matchCount = 0;

    for (final token in allTokens) {
      final tok = token.toLowerCase();
      if (tok.length < 3) continue;
      final regex = RegExp(r'\b' + RegExp.escape(tok) + r'\b');

      if (regex.hasMatch(lowerName)) {
        score += 35.0;
        matchCount++;
      } else if (regex.hasMatch(lowerHandle)) {
        score += 25.0;
        matchCount++;
      } else if (lowerCat == tok || lowerCats.contains(tok)) {
        score += 30.0;
        matchCount++;
      } else if (regex.hasMatch(lowerDesc)) {
        score += 15.0;
        matchCount++;
      }
    }

    // If query has semantic tokens but none matched, channel is not relevant
    if (allTokens.isNotEmpty && matchCount == 0) {
      return 0.0;
    }

    // 3. Category match boost
    if (intent.detectedCategory != null &&
        intent.detectedCategory!.isNotEmpty) {
      final cat = intent.detectedCategory!.toLowerCase();
      if (lowerCat == cat || lowerCats.contains(cat)) {
        score += 25.0;
      }
    }

    // 4. Result Mode Adjustments (Decoupled: Quality 15%, Activity 10%, Audience 5%)
    if (intent.resultMode == SearchResultMode.ranked) {
      // Quality signal (verified badge / trust)
      if (channel.isVerified) score += 15.0;
      // Activity signal (catalog size / consistency)
      score += (channel.videoCount > 0
          ? (channel.videoCount.toDouble() / 100.0).clamp(0.0, 10.0)
          : 0.0);
      // Audience size (popularity)
      score += (channel.subscriberCount > 0
          ? (channel.subscriberCount.toDouble() / 50000.0).clamp(0.0, 5.0)
          : 0.0);
    }

    return score > 0 ? score : 0.0;
  }

  // ==========================================================================
  // TOPIC SCORING & RELEVANCE RANKING
  // ==========================================================================

  /// Scores a topic against the parsed AI intent
  double scoreTopic(Topic topic, AiSearchIntent intent) {
    final lowerTitle = topic.title.toLowerCase();
    final lowerSlug = topic.slug.toLowerCase();
    final lowerDesc = topic.description.toLowerCase();
    final lowerCat = topic.category.toLowerCase();
    final lowerTags = topic.tags.map((t) => t.toLowerCase()).toList();

    for (final excluded in intent.excludedTerms) {
      final exc = excluded.toLowerCase();
      if (lowerTitle.contains(exc) || lowerDesc.contains(exc)) {
        return 0.0;
      }
    }

    var score = 0.0;
    final allTokens = intent.allTokens;
    var matchCount = 0;

    // Subdomains match is highest relevance
    for (final sub in intent.subdomains) {
      final lowerSub = sub.toLowerCase();
      if (lowerTitle.contains(lowerSub) || lowerSlug.contains(lowerSub)) {
        score += 45.0;
        matchCount++;
      }
    }

    for (final token in allTokens) {
      final tok = token.toLowerCase();
      if (tok.length < 3) continue;
      final regex = RegExp(r'\b' + RegExp.escape(tok) + r'\b');

      if (regex.hasMatch(lowerTitle)) {
        score += 35.0;
        matchCount++;
      } else if (regex.hasMatch(lowerSlug)) {
        score += 30.0;
        matchCount++;
      } else if (lowerCat == tok || lowerCat.contains(tok)) {
        score += 25.0;
        matchCount++;
      } else if (lowerTags.any((t) => t == tok || regex.hasMatch(t))) {
        score += 20.0;
        matchCount++;
      } else if (regex.hasMatch(lowerDesc)) {
        score += 15.0;
        matchCount++;
      }
    }

    if (allTokens.isNotEmpty && matchCount == 0) {
      return 0.0;
    }

    if (intent.detectedCategory != null &&
        intent.detectedCategory!.isNotEmpty) {
      if (lowerCat == intent.detectedCategory!.toLowerCase()) {
        score += 20.0;
      }
    }

    if (intent.resultMode == SearchResultMode.ranked) {
      score += (topic.videoCount.toDouble() * 2.0).clamp(0.0, 30.0);
      score += topic.trendingScore.clamp(0.0, 20.0);
    }

    return score > 0 ? score : 0.0;
  }

  // ==========================================================================
  // SEARCH RESULT SCORING & RELEVANCE RANKING
  // ==========================================================================

  /// Scores any SearchResult (video, channel, topic, playlist) against the parsed AI intent
  /// Returns 0.0 if not a match, or a positive relevance score.
  double scoreSearchResult(SearchResult item, AiSearchIntent intent) {
    final lowerTitle = item.title.toLowerCase();
    final lowerChannel = item.channelName.toLowerCase();
    final lowerCat = (item.category ?? '').toLowerCase();
    final itemLang = (item.language ?? '').toLowerCase().trim();

    // 1. Check exclusions first (negation handling)
    for (final excluded in intent.excludedTerms) {
      final exc = excluded.toLowerCase();
      if (lowerTitle.contains(exc) ||
          lowerChannel.contains(exc) ||
          lowerCat.contains(exc)) {
        return 0.0;
      }
    }

    var score = 0.0;

    // 2. Language matching
    if (intent.detectedLanguage != null &&
        intent.detectedLanguage!.isNotEmpty) {
      final lang = intent.detectedLanguage!.toLowerCase();
      final langCode = intent.detectedLanguageCode?.toLowerCase() ?? '';

      final isExplicitMatch =
          itemLang == lang ||
          itemLang == langCode ||
          (itemLang.isNotEmpty &&
              (itemLang.contains(lang) || itemLang.contains(langCode))) ||
          lowerTitle.contains(lang) ||
          lowerChannel.contains(lang);

      if (isExplicitMatch) {
        score += 50.0;
      } else {
        // Strict language filter: if query explicitly specified a language,
        // results that don't match the language are excluded
        return 0.0;
      }
    }

    // 3. Subdomains match (highest relevance boost)
    for (final sub in intent.subdomains) {
      final lowerSub = sub.toLowerCase();
      if (lowerTitle.contains(lowerSub) || lowerChannel.contains(lowerSub)) {
        score += 40.0;
      }
    }

    // 4. Semantic concepts & keywords
    final allTokens = intent.allTokens;
    var matchCount = 0;

    for (final token in allTokens) {
      final tok = token.toLowerCase();
      if (tok.length < 3) continue;
      final regex = RegExp(r'\b' + RegExp.escape(tok) + r'\b');

      if (regex.hasMatch(lowerTitle)) {
        score += 35.0;
        matchCount++;
      } else if (regex.hasMatch(lowerChannel)) {
        score += 25.0;
        matchCount++;
      } else if (lowerCat.isNotEmpty &&
          (lowerCat == tok || regex.hasMatch(lowerCat))) {
        score += 20.0;
        matchCount++;
      } else if (lowerTitle.contains(tok)) {
        score += 15.0;
        matchCount++;
      }
    }

    // If query has semantic tokens but none matched, item is not relevant
    if (allTokens.isNotEmpty && matchCount == 0) {
      return 0.0;
    }

    // 5. Category match boost
    if (intent.detectedCategory != null &&
        intent.detectedCategory!.isNotEmpty) {
      final cat = intent.detectedCategory!.toLowerCase();
      if (lowerCat == cat || lowerCat.contains(cat)) {
        score += 25.0;
      }
    }

    // 6. Result Mode Adjustments (Decoupled signals for ranked mode)
    if (intent.resultMode == SearchResultMode.ranked) {
      // Views / Popularity Boost (Log scale)
      if (item.views > 0) {
        score += (item.views.toString().length * 2.0).clamp(0.0, 15.0);
      }
      // Content-type prominence if strong match
      if (score >= 40.0) {
        if (item.type == ResultType.channel) {
          score += 15.0;
        } else if (item.type == ResultType.topic) {
          score += 10.0;
        }
      }
      // Freshness boost (for videos in the last 30 days)
      final daysOld = DateTime.now().difference(item.createdAt.toDate()).inDays;
      if (daysOld >= 0 && daysOld < 30) {
        score += (30 - daysOld) * 0.2;
      }
    }

    return score > 0 ? score : 0.0;
  }
}
