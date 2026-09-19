import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/core/services/ai/search/ai_search_barrel.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';

/// Central coordinator and facade for AI-powered semantic search.
///
/// Dispatches query parsing between instant local intent parsing and Gemini Cloud fallback,
/// while delegating channel, topic, and search result relevance ranking to dedicated sub-engines.
class AiSearchService {
  AiSearchService._();
  static final AiSearchService instance = AiSearchService._();

  // In-memory query intent cache for instant re-lookup
  final Map<String, AiSearchIntent> _intentCache = {};

  final AiSearchCloudClient _cloudClient = AiSearchCloudClient();
  final AiSearchLocalParser _localParser = const AiSearchLocalParser();
  final AiSearchScoringEngine _scoringEngine = const AiSearchScoringEngine();

  /// Optional delegate hook for testing Cloud Function intent responses
  @visibleForTesting
  Future<AiSearchIntent?> Function(String query, SearchScope scope)?
  get cloudAssistantHandler => _cloudClient.cloudAssistantHandler;

  set cloudAssistantHandler(
    Future<AiSearchIntent?> Function(String query, SearchScope scope)? handler,
  ) {
    _cloudClient.cloudAssistantHandler = handler;
  }

  /// Check if the cloud assistant circuit breaker is active (in cooldown)
  bool get isCloudAssistantInCooldown =>
      _cloudClient.isCloudAssistantInCooldown;

  /// Manually reset circuit breaker (useful for tests or network reconnection)
  @visibleForTesting
  void resetCircuitBreaker() {
    _cloudClient.resetCircuitBreaker();
  }

  /// Clear the query intent cache (useful between tests)
  @visibleForTesting
  void clearCache() {
    _intentCache.clear();
    resetCircuitBreaker();
  }

  static const double kConfidenceThreshold = 0.75;

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
    final localIntent = _localParser.parseLocally(rawTrimmed, scope: scope);

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
      final cloudIntent = await _cloudClient.callGeminiAssistant(
        rawTrimmed,
        scope: scope,
      );
      if (cloudIntent != null) {
        _cloudClient.recordSuccess();
        _intentCache[cacheKey] = cloudIntent;
        return cloudIntent;
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'AiSearchService.determineIntent.geminiCloud',
      );
      _cloudClient.recordFailure();
    }

    // Fallback to local intent if cloud fails
    _intentCache[cacheKey] = localIntent;
    return localIntent;
  }

  /// Scores a channel against the parsed AI intent
  /// Returns 0.0 if not a match, or a positive relevance score.
  double scoreChannel(Channel channel, AiSearchIntent intent) =>
      _scoringEngine.scoreChannel(channel, intent);

  /// Scores a topic against the parsed AI intent
  double scoreTopic(Topic topic, AiSearchIntent intent) =>
      _scoringEngine.scoreTopic(topic, intent);

  /// Scores any SearchResult (video, channel, topic, playlist) against the parsed AI intent
  /// Returns 0.0 if not a match, or a positive relevance score.
  double scoreSearchResult(SearchResult item, AiSearchIntent intent) =>
      _scoringEngine.scoreSearchResult(item, intent);
}
