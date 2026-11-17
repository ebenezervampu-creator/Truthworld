import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';

/// Client for calling Cloud Function `aiSearchAssistant` (backed by Gemini 3.5 Flash Lite)
/// with built-in circuit breaker resilience.
class AiSearchCloudClient {
  AiSearchCloudClient();

  /// Optional delegate hook for testing Cloud Function intent responses
  Future<AiSearchIntent?> Function(String query, SearchScope scope)?
  cloudAssistantHandler;

  // Circuit breaker state to prevent spamming failing Cloud Function
  DateTime? _cloudCooldownUntil;
  int _consecutiveCloudFailures = 0;
  static const int kMaxConsecutiveFailuresBeforeTrip = 1;
  static const Duration kCircuitBreakerCooldown = Duration(minutes: 3);

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
  void resetCircuitBreaker() {
    _cloudCooldownUntil = null;
    _consecutiveCloudFailures = 0;
  }

  /// Record successful cloud invocation
  void recordSuccess() {
    _consecutiveCloudFailures = 0;
  }

  /// Record cloud invocation failure and trip breaker if threshold is reached
  void recordFailure() {
    _consecutiveCloudFailures++;
    if (_consecutiveCloudFailures >= kMaxConsecutiveFailuresBeforeTrip) {
      _cloudCooldownUntil = DateTime.now().add(kCircuitBreakerCooldown);
    }
  }

  /// Calls Cloud Function `aiSearchAssistant` (backed by Gemini 3.5 Flash Lite)
  Future<AiSearchIntent?> callGeminiAssistant(
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
}
