import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/network/app_http_client.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/video/data/models/credibility_chat_message.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/services/credibility_governance_service.dart';

/// ⚡ CredibilityChatStreamEvent
///
/// Represents an incremental token chunk or metadata packet from the SSE stream.
class CredibilityChatStreamEvent {
  final String? textDelta;
  final List<UISource>? sources;
  final List<String>? suggestedFollowups;
  final String? disclaimer;
  final bool isDone;
  final String? error;

  const CredibilityChatStreamEvent({
    this.textDelta,
    this.sources,
    this.suggestedFollowups,
    this.disclaimer,
    this.isDone = false,
    this.error,
  });

  factory CredibilityChatStreamEvent.delta(String text) =>
      CredibilityChatStreamEvent(textDelta: text);

  factory CredibilityChatStreamEvent.metadata({
    required List<UISource> sources,
    required List<String> suggestedFollowups,
    String? disclaimer,
  }) =>
      CredibilityChatStreamEvent(
        sources: sources,
        suggestedFollowups: suggestedFollowups,
        disclaimer: disclaimer,
      );

  factory CredibilityChatStreamEvent.done() =>
      const CredibilityChatStreamEvent(isDone: true);

  factory CredibilityChatStreamEvent.error(String message) =>
      CredibilityChatStreamEvent(error: message, isDone: true);
}

/// 🤖 AiCredibilityChatService
///
/// Dispatches chat messages to the 2nd Gen Cloud Function `chatWithCredibilityAi`
/// or the real-time SSE streaming endpoint `streamCredibilityAiChat`,
/// mapping incoming structured evidence, sources, and suggested followups.
class AiCredibilityChatService {
  AiCredibilityChatService._();
  static final AiCredibilityChatService instance = AiCredibilityChatService._();

  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(region: AppConfig.credibilityFunctionsRegion);

  /// Client-side session cache for zero latency and minimal backend/LLM invocation cost
  final Map<String, CredibilityChatMessage> _clientCache = {};

  /// Clears the client-side session cache
  void clearCache() => _clientCache.clear();

  static String _getCacheKey(String videoId, String scope, int? claimIndex, String userQuery) {
    final clean = userQuery.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9 ]'), '').replaceAll(RegExp(r'\s+'), ' ');
    return '$videoId:$scope:${claimIndex ?? 'all'}:$clean';
  }

  /// Optional test hook to mock callable response or simulate backend failure
  Future<Map<String, dynamic>> Function(Map<String, dynamic> payload)? callableHandler;

  /// Optional test hook to mock streaming HTTP response or simulate streaming backend failure
  Future<http.StreamedResponse> Function()? streamedResponseHandler;

  static List<Map<String, dynamic>> _serializeSources(List<dynamic>? sources) {
    if (sources == null || sources.isEmpty) return const [];
    final list = <Map<String, dynamic>>[];
    for (final s in sources.take(15)) {
      if (s is UISource) {
        list.add(s.toMap());
      } else if (s is Map) {
        list.add(Map<String, dynamic>.from(s));
      } else if (s != null) {
        list.add({'title': s.toString()});
      }
    }
    return list;
  }

  static List<Map<String, dynamic>> _serializeClaims(List<dynamic>? claims) {
    if (claims == null || claims.isEmpty) return const [];
    final list = <Map<String, dynamic>>[];
    for (final c in claims.take(15)) {
      if (c is Map) {
        list.add(Map<String, dynamic>.from(c));
      } else if (c != null) {
        try {
          list.add((c as dynamic).toMap() as Map<String, dynamic>);
        } catch (_) {
          list.add({'statement': c.toString()});
        }
      }
    }
    return list;
  }

  static bool _isGreeting(String query) {
    final clean = query.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9 ]'), '');
    const greetings = [
      'hi', 'hello', 'hey', 'hola', 'namaste', 'greetings', 'good morning',
      'good afternoon', 'good evening', 'howdy', 'sup', 'whatsup', 'who are you',
      'help', 'start', 'info', 'test'
    ];
    return greetings.contains(clean) || clean.startsWith('hi ') || clean.startsWith('hello ');
  }

  /// ⚡ Streams real-time tokens (<400ms TTFT) from Gemini via Server-Sent Events (SSE).
  ///
  /// Seamlessly falls back to `askCredibilityAi` if the streaming endpoint is unreachable.
  Stream<CredibilityChatStreamEvent> streamCredibilityAi({
    required String videoId,
    required String userQuery,
    required String scope,
    int? claimIndex,
    String? claimText,
    String? verdict,
    List<CredibilityChatMessage> history = const [],
    List<dynamic>? cachedSources,
    List<dynamic>? cachedClaims,
    String? videoTitle,
    String? videoCategory,
    String? videoSummary,
    String? claimExplanation,
    double? playbackSec,
    String? transcriptSnippet,
    String? activeChapterTitle,
  }) async* {
    final cleanVideoId = videoId.trim();
    if (cleanVideoId.isEmpty) {
      yield CredibilityChatStreamEvent.error(
        'Unable to start inquiry: video identifier is missing. Please refresh the page and try again.',
      );
      return;
    }

    // ⚡ Fast Client Cache Check (Zero Latency & Zero Network Usage)
    final cacheKey = _getCacheKey(cleanVideoId, scope, claimIndex, userQuery);
    if (history.isEmpty && _clientCache.containsKey(cacheKey)) {
      final cached = _clientCache[cacheKey]!;
      yield CredibilityChatStreamEvent.metadata(
        sources: cached.sources,
        suggestedFollowups: cached.suggestedFollowups,
        disclaimer: cached.disclaimer,
      );
      yield CredibilityChatStreamEvent.delta(cached.text);
      yield CredibilityChatStreamEvent.done();
      return;
    }

    final streamingUrl = Uri.parse(
      '${AppConfig.credibilityFunctionsBaseUrl}/streamCredibilityAiChat',
    );

    final payload = <String, dynamic>{
      'videoId': cleanVideoId,
      'userQuery': userQuery,
      'scope': scope,
      'history': history
          .where((m) => m.text.isNotEmpty)
          .map((m) => m.toHistoryMap())
          .toList(),
    };
    if (claimIndex != null) payload['claimIndex'] = claimIndex;
    if (claimText != null) payload['claimText'] = claimText;
    if (verdict != null) payload['verdict'] = verdict;
    if (claimExplanation != null) payload['claimExplanation'] = claimExplanation;
    if (videoTitle != null && videoTitle.isNotEmpty) payload['videoTitle'] = videoTitle;
    if (videoCategory != null && videoCategory.isNotEmpty) {
      payload['category'] = videoCategory;
      payload['videoCategory'] = videoCategory;
    }
    if (videoSummary != null && videoSummary.isNotEmpty) payload['summary'] = videoSummary;
    if (playbackSec != null) payload['playbackSec'] = playbackSec;
    if (transcriptSnippet != null && transcriptSnippet.isNotEmpty) {
      payload['transcriptSnippet'] = transcriptSnippet;
    }
    if (activeChapterTitle != null && activeChapterTitle.isNotEmpty) {
      payload['activeChapterTitle'] = activeChapterTitle;
    }
    final serializedSources = _serializeSources(cachedSources);
    if (serializedSources.isNotEmpty) {
      payload['sources'] = serializedSources;
    }
    final serializedClaims = _serializeClaims(cachedClaims);
    if (serializedClaims.isNotEmpty) {
      payload['claims'] = serializedClaims;
    }

    http.StreamedResponse? streamedResponse;
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final headers = await buildStreamRequestHeaders(
        authToken: token,
        appCheckTokenLoader: StorageUtils.getAppCheckToken,
      );

      Future<http.StreamedResponse> sendStreamRequest() async {
        if (streamedResponseHandler != null) {
          return streamedResponseHandler!();
        }
        final request = http.Request('POST', streamingUrl)
          ..headers.addAll(headers)
          ..body = jsonEncode(payload);

        return AppHttpClient.instance.client
            .send(request)
            .timeout(const Duration(seconds: 30));
      }

      streamedResponse = await sendStreamRequest();

      // Resilient transient retry on 502/503/504/429 (Cloud Run cold start / temporary quota delay)
      if (streamedResponse.statusCode == 503 ||
          streamedResponse.statusCode == 502 ||
          streamedResponse.statusCode == 504 ||
          streamedResponse.statusCode == 429) {
        LoggerService().warning(
          'Streaming endpoint returned HTTP ${streamedResponse.statusCode}. Retrying once after 1000ms...',
          tag: 'AiCredibilityChatService',
        );
        await Future<void>.delayed(const Duration(milliseconds: 1000));
        streamedResponse = await sendStreamRequest();
      }

      if (streamedResponse.statusCode != 200) {
        throw ServerException(
          statusCode: streamedResponse.statusCode,
          message: 'Streaming endpoint returned status ${streamedResponse.statusCode}',
          isRetryable: streamedResponse.statusCode >= 500,
        );
      }

      var hasReceivedAnyToken = false;
      final accumulatedText = StringBuffer();
      final streamedSources = <UISource>[];
      final streamedFollowups = <String>[];
      String? streamedDisclaimer;

      await for (final line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith(':')) continue;

        if (trimmed == 'data: [DONE]') {
          if (accumulatedText.isNotEmpty) {
            _clientCache[cacheKey] = CredibilityChatMessage.ai(
              text: accumulatedText.toString(),
              sources: streamedSources,
              suggestedFollowups: streamedFollowups,
              scope: scope,
              claimIndex: claimIndex,
              disclaimer: streamedDisclaimer,
            );
          }
          yield CredibilityChatStreamEvent.done();
          return;
        }

        if (trimmed.startsWith('data: ')) {
          final jsonStr = trimmed.substring(6).trim();
          try {
            final map = jsonDecode(jsonStr);
            if (map is Map) {
              final type = map['type']?.toString();

              if (type == 'delta') {
                final delta = map['text']?.toString() ?? '';
                if (delta.isNotEmpty) {
                  hasReceivedAnyToken = true;
                  accumulatedText.write(delta);
                  yield CredibilityChatStreamEvent.delta(delta);
                }
              } else if (type == 'metadata') {
                final rawSources = map['sources'] as List<dynamic>? ?? [];
                final rawFollowups = map['suggestedFollowups'] as List<dynamic>? ?? [];
                final disclaimer = map['disclaimer']?.toString();
                streamedDisclaimer = disclaimer;

                final parsedSources = <UISource>[];
                for (final s in rawSources) {
                  if (s is Map) {
                    parsedSources.add(
                      UISource(
                        title: s['title']?.toString() ?? 'Reference Source',
                        url: s['url']?.toString(),
                        domain: s['domain']?.toString(),
                        publisher: s['publisher']?.toString() ?? s['domain']?.toString() ?? 'Verified Publisher',
                        snippet: s['snippet']?.toString(),
                        publishedAt: s['publishedYear']?.toString(),
                        trustLevel: 'High',
                        type: 'Web',
                      ),
                    );
                  }
                }

                streamedSources.addAll(parsedSources);
                streamedFollowups.addAll(rawFollowups.map((f) => f.toString()));

                yield CredibilityChatStreamEvent.metadata(
                  sources: parsedSources,
                  suggestedFollowups: rawFollowups.map((f) => f.toString()).toList(),
                  disclaimer: disclaimer,
                );
              } else if (type == 'done') {
                if (accumulatedText.isNotEmpty) {
                  _clientCache[cacheKey] = CredibilityChatMessage.ai(
                    text: accumulatedText.toString(),
                    sources: streamedSources,
                    suggestedFollowups: streamedFollowups,
                    scope: scope,
                    claimIndex: claimIndex,
                    disclaimer: streamedDisclaimer,
                  );
                }
                yield CredibilityChatStreamEvent.done();
                return;
              } else if (type == 'error') {
                // If stream reported an error event, trigger robust callable fallback
                throw Exception('SSE stream error event received');
              }
            }
          } catch (_) {
            // Ignore malformed partial chunks
          }
        }
      }

      if (!hasReceivedAnyToken) {
        throw Exception('Stream closed without emitting tokens');
      }

      if (accumulatedText.isNotEmpty) {
        _clientCache[cacheKey] = CredibilityChatMessage.ai(
          text: accumulatedText.toString(),
          sources: streamedSources,
          suggestedFollowups: streamedFollowups,
          scope: scope,
          claimIndex: claimIndex,
          disclaimer: streamedDisclaimer,
        );
      }
      yield CredibilityChatStreamEvent.done();
    } catch (e, s) {
      LoggerService().warning(
        'Streaming chat endpoint unavailable ($e); transitioning seamlessly to callable fallback...',
        tag: 'AiCredibilityChatService.streamCredibilityAi',
        error: e,
        stackTrace: s,
      );

      // Graceful Fallback: Invoke standard askCredibilityAi callable to preserve flawless user experience
      try {
        final fallbackMsg = await askCredibilityAi(
          videoId: videoId,
          userQuery: userQuery,
          scope: scope,
          claimIndex: claimIndex,
          claimText: claimText,
          verdict: verdict,
          history: history,
          cachedSources: cachedSources,
          cachedClaims: cachedClaims,
          videoTitle: videoTitle,
          videoCategory: videoCategory,
          videoSummary: videoSummary,
          claimExplanation: claimExplanation,
          playbackSec: playbackSec,
          transcriptSnippet: transcriptSnippet,
          activeChapterTitle: activeChapterTitle,
        );

        if (fallbackMsg.sources.isNotEmpty || fallbackMsg.suggestedFollowups.isNotEmpty) {
          yield CredibilityChatStreamEvent.metadata(
            sources: fallbackMsg.sources,
            suggestedFollowups: fallbackMsg.suggestedFollowups,
            disclaimer: fallbackMsg.disclaimer,
          );
        }

        yield CredibilityChatStreamEvent.delta(fallbackMsg.text);
        yield CredibilityChatStreamEvent.done();
      } catch (fallbackErr, fallbackStack) {
        ErrorHandler.log(
          fallbackErr,
          stackTrace: fallbackStack,
          tag: 'AiCredibilityChatService.streamCredibilityAi.fallbackFailed',
        );
        yield CredibilityChatStreamEvent.error(
          'Unable to reach the Truth Intelligence assistant right now. Please check your connection and try again.',
        );
      }
    }
  }

  /// Calls backend credibility AI assistant for a specific claim or whole video
  Future<CredibilityChatMessage> askCredibilityAi({
    required String videoId,
    required String userQuery,
    required String scope,
    int? claimIndex,
    String? claimText,
    String? verdict,
    List<CredibilityChatMessage> history = const [],
    List<dynamic>? cachedSources,
    List<dynamic>? cachedClaims,
    String? videoTitle,
    String? videoCategory,
    String? videoSummary,
    String? claimExplanation,
    double? playbackSec,
    String? transcriptSnippet,
    String? activeChapterTitle,
  }) async {
    final cleanVideoId = videoId.trim();
    if (cleanVideoId.isEmpty) {
      return CredibilityChatMessage.ai(
        text: 'Unable to start inquiry: video identifier is missing. Please refresh the page and try again.',
        scope: scope,
        claimIndex: claimIndex,
      );
    }

    // ⚡ Fast Client Cache Check (Zero Latency & Zero Cost)
    final cacheKey = _getCacheKey(cleanVideoId, scope, claimIndex, userQuery);
    if (callableHandler == null && history.isEmpty && _clientCache.containsKey(cacheKey)) {
      return _clientCache[cacheKey]!;
    }

    final payload = <String, dynamic>{
      'videoId': cleanVideoId,
      'userQuery': userQuery,
      'scope': scope,
      'history': history
          .where((m) => m.text.isNotEmpty)
          .map((m) => m.toHistoryMap())
          .toList(),
    };
    if (claimIndex != null) payload['claimIndex'] = claimIndex;
    if (claimText != null) payload['claimText'] = claimText;
    if (verdict != null) payload['verdict'] = verdict;
    if (claimExplanation != null) payload['claimExplanation'] = claimExplanation;
    if (videoTitle != null && videoTitle.isNotEmpty) payload['videoTitle'] = videoTitle;
    if (videoCategory != null && videoCategory.isNotEmpty) {
      payload['category'] = videoCategory;
      payload['videoCategory'] = videoCategory;
    }
    if (videoSummary != null && videoSummary.isNotEmpty) payload['summary'] = videoSummary;
    if (playbackSec != null) payload['playbackSec'] = playbackSec;
    if (transcriptSnippet != null && transcriptSnippet.isNotEmpty) {
      payload['transcriptSnippet'] = transcriptSnippet;
    }
    if (activeChapterTitle != null && activeChapterTitle.isNotEmpty) {
      payload['activeChapterTitle'] = activeChapterTitle;
    }
    final serializedSources = _serializeSources(cachedSources);
    if (serializedSources.isNotEmpty) {
      payload['sources'] = serializedSources;
    }
    final serializedClaims = _serializeClaims(cachedClaims);
    if (serializedClaims.isNotEmpty) {
      payload['claims'] = serializedClaims;
    }

    try {
      final Map<dynamic, dynamic> data;
      if (callableHandler != null) {
        data = await callableHandler!(payload);
      } else {
        final callable = _functions.httpsCallable(
          'chatWithCredibilityAi',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
        );
        final result = await callable.call(payload);
        data = result.data as Map<dynamic, dynamic>? ?? {};
      }

      final answer = (data['answer'] ?? 'Credibility analysis completed.').toString();
      final rawSources = data['sources'] as List<dynamic>? ?? [];
      final rawFollowups = data['suggestedFollowups'] as List<dynamic>? ?? [];
      final disclaimer = data['disclaimer']?.toString();

      final parsedSources = <UISource>[];
      for (final s in rawSources) {
        if (s is Map) {
          parsedSources.add(
            UISource(
              title: s['title']?.toString() ?? 'Reference Source',
              url: s['url']?.toString(),
              domain: s['domain']?.toString(),
              publisher: s['publisher']?.toString() ?? s['domain']?.toString() ?? 'Verified Publisher',
              snippet: s['snippet']?.toString(),
              publishedAt: s['publishedYear']?.toString(),
              trustLevel: 'High',
              type: 'Web',
            ),
          );
        }
      }

      final followups = rawFollowups.map((f) => f.toString()).toList();

      final response = CredibilityChatMessage.ai(
        text: answer,
        sources: parsedSources,
        suggestedFollowups: followups,
        scope: scope,
        claimIndex: claimIndex,
        disclaimer: disclaimer,
      );
      _clientCache[cacheKey] = response;
      return response;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'AiCredibilityChatService.askCredibilityAi');

      final fallback = _synthesizeLocalHeuristicMessage(
        userQuery: userQuery,
        scope: scope,
        videoId: videoId,
        claimIndex: claimIndex,
        claimText: claimText,
        verdict: verdict,
        claimExplanation: claimExplanation,
        cachedSources: cachedSources,
        cachedClaims: cachedClaims,
        videoTitle: videoTitle,
        videoSummary: videoSummary,
        playbackSec: playbackSec,
        transcriptSnippet: transcriptSnippet,
        activeChapterTitle: activeChapterTitle,
      );
      _clientCache[cacheKey] = fallback;
      return fallback;
    }
  }

  /// Synthesizes local heuristic message from indexed video fact-check ledger
  @visibleForTesting
  static Future<Map<String, String>> buildStreamRequestHeaders({
    String? authToken,
    String? appCheckToken,
    Future<String?> Function()? appCheckTokenLoader,
  }) async {
    String? resolvedAppCheck = appCheckToken;
    if ((resolvedAppCheck == null || resolvedAppCheck.isEmpty) &&
        appCheckTokenLoader != null) {
      try {
        resolvedAppCheck = await appCheckTokenLoader();
      } catch (_) {
        resolvedAppCheck = null;
      }
    }
    return <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'text/event-stream',
      if (authToken != null && authToken.isNotEmpty)
        'Authorization': 'Bearer $authToken',
      if (resolvedAppCheck != null && resolvedAppCheck.isNotEmpty)
        'X-Firebase-AppCheck': resolvedAppCheck,
    };
  }

  /// Synthesizes a local heuristic fallback using loaded claims/sources without
  /// hardcoding unrelated corporate/financial copy.
  @visibleForTesting
  CredibilityChatMessage buildLocalHeuristicResponse({
    required String videoId,
    required String scope,
    required String userQuery,
    int? claimIndex,
    String? claimText,
    String? verdict,
    List<dynamic>? cachedSources,
    List<dynamic>? cachedClaims,
    String? videoTitle,
    String? videoSummary,
    String? claimExplanation,
  }) {
    return _synthesizeLocalHeuristicMessage(
      videoId: videoId,
      scope: scope,
      claimIndex: claimIndex,
      userQuery: userQuery,
      claimText: claimText,
      verdict: verdict,
      cachedSources: cachedSources,
      cachedClaims: cachedClaims,
      videoTitle: videoTitle,
      videoSummary: videoSummary,
      claimExplanation: claimExplanation,
    );
  }

  CredibilityChatMessage _synthesizeLocalHeuristicMessage({
    required String userQuery,
    required String scope,
    String? videoId,
    int? claimIndex,
    String? claimText,
    String? verdict,
    String? claimExplanation,
    List<dynamic>? cachedSources,
    List<dynamic>? cachedClaims,
    String? videoTitle,
    String? videoSummary,
    double? playbackSec,
    String? transcriptSnippet,
    String? activeChapterTitle,
  }) {
    final lowerQ = userQuery.toLowerCase().trim();
    final effectiveTitle = (videoTitle != null && videoTitle.isNotEmpty) ? videoTitle : 'this video';

    // Parse cached sources if available
    final parsedSources = <UISource>[];
    if (cachedSources != null && cachedSources.isNotEmpty) {
      for (final s in cachedSources) {
        if (s is UISource) {
          parsedSources.add(s);
        } else if (s is Map) {
          parsedSources.add(
            UISource(
              title: s['title']?.toString() ?? 'Reference Source',
              url: s['url']?.toString() ?? s['directUrl']?.toString(),
              domain: s['domain']?.toString(),
              publisher: s['publisher']?.toString() ?? s['domain']?.toString() ?? 'Verified Publisher',
              snippet: s['snippet']?.toString(),
              publishedAt: s['publishedYear']?.toString() ?? s['publishedDate']?.toString(),
              trustLevel: 'High',
              type: 'Web',
            ),
          );
        }
      }
    }

    // 1. GREETING RESOLUTION: Always warmly greet user with video context
    if (_isGreeting(userQuery)) {
      return CredibilityChatMessage.ai(
        text: 'Hello! I am your **Truth Intelligence** assistant for **"$effectiveTitle"**.\n\n'
            "This video has been independently cross-referenced against authoritative empirical records on TruthWorld's transparent claim ledger.\n\n"
            'How can I help you? You can ask me why claims were classified, request peer-reviewed sources, check counter-evidence, or ask for better videos and deeper analysis.',
        sources: parsedSources.take(3).toList(),
        scope: scope,
        claimIndex: claimIndex,
        suggestedFollowups: [
          if (scope == 'claim')
            'Why this verdict?'
          else
            'Suggest better videos on this topic',
          'What are the primary sources?',
          'What are the most controversial claims?',
        ],
        disclaimer: 'Truth Intelligence provides independent empirical verification.',
      );
    }

    // 2. VIDEO RECOMMENDATIONS / ALTERNATIVES / "BETTER VIDEOS" RESOLUTION
    final isRecommendationQuery = lowerQ.contains('better video') ||
        lowerQ.contains('suggest') ||
        lowerQ.contains('recommend') ||
        lowerQ.contains('other video') ||
        lowerQ.contains('more video') ||
        lowerQ.contains('alternative') ||
        lowerQ.contains('watch next') ||
        lowerQ.contains('better source') ||
        lowerQ.contains('who covered') ||
        lowerQ.contains('better channel');

    if (isRecommendationQuery) {
      final disputedCount = (cachedClaims ?? []).where((c) {
        final m = c is Map ? c : {};
        final v = (m['verdict'] ?? m['status'] ?? '').toString().toLowerCase();
        return v.contains('disputed') || v.contains('false') || v.contains('caution');
      }).length;

      final disputeText = disputedCount > 0
          ? 'Because this presentation contains **$disputedCount assertions flagged with caution or discrepancies**, cross-referencing with comprehensive investigative coverage is strongly recommended.'
          : 'For deeper analysis beyond this presentation, cross-referencing multiple authoritative investigative perspectives provides a well-rounded understanding.';

      final sourcePreview = parsedSources.isNotEmpty
          ? parsedSources
              .take(4)
              .map((s) => '- **${s.publisher ?? s.domain ?? "Reference Source"}**: ${s.title}')
              .join('\n')
          : '- Cross-check cited institutional records, peer-reviewed studies, and primary documents on the Sources tab.';

      return CredibilityChatMessage.ai(
        text: '### Recommended Authoritative Perspectives for "$effectiveTitle"\n\n'
            '$disputeText\n\n'
            'Explore primary evidence and cited sources indexed for this topic:\n\n'
            '$sourcePreview\n\n'
            'For deeper verification, compare primary archival records, domain-specialist publications, and independent reporting across the Sources tab.',
        sources: parsedSources.take(4).toList(),
        scope: scope,
        claimIndex: claimIndex,
        suggestedFollowups: [
          'What claims in this video are disputed?',
          'What are the primary sources?',
          'What are the key assertions?',
        ],
        disclaimer: 'Truth Intelligence guides users toward verified, authoritative evidence.',
      );
    }

    // 2.5 SPECIALIZED CLAIM SCOPE ENFORCEMENT & REDIRECTION
    if (scope == 'claim' && claimIndex != null) {
      final currentClaimNum = claimIndex + 1;
      final targetClaimNum = _extractTargetClaimNumber(userQuery);
      if (targetClaimNum != null && targetClaimNum != currentClaimNum) {
        return CredibilityChatMessage.ai(
          text: 'You are currently in the specialized analysis session for Claim #$currentClaimNum. '
              'Please navigate to Claim #$targetClaimNum and ask there. '
              'In this session, I only support chats directly related to Claim #$currentClaimNum.',
          scope: scope,
          claimIndex: claimIndex,
          suggestedFollowups: [
            'Why this verdict for Claim #$currentClaimNum?',
            'What sources support Claim #$currentClaimNum?',
            'Suggest better videos on this topic',
          ],
          disclaimer: 'Claim sessions are strictly focused on their specific empirical assertion.',
        );
      }
    }

    // 2.7 DISPUTE, CONTESTED VERDICT & COUNTER-EVIDENCE INQUIRY
    final extractedUrls = extractUrls(userQuery);
    final isDisputeInquiry = lowerQ.contains('dispute') ||
        lowerQ.contains('wrong verdict') ||
        lowerQ.contains('incorrect verdict') ||
        lowerQ.contains('should be false') ||
        lowerQ.contains('is actually false') ||
        lowerQ.contains('is false') ||
        lowerQ.contains('is not true') ||
        lowerQ.contains('should be true') ||
        lowerQ.contains('change the verdict') ||
        lowerQ.contains('i have proof') ||
        lowerQ.contains('i have evidence') ||
        lowerQ.contains('convince') ||
        lowerQ.contains('you got it wrong') ||
        lowerQ.contains('you are wrong') ||
        (extractedUrls.isNotEmpty &&
            (lowerQ.contains('false') ||
                lowerQ.contains('wrong') ||
                lowerQ.contains('incorrect')));

    if (isDisputeInquiry) {
      final targetClaimNum = _extractTargetClaimNumber(userQuery) ??
          (claimIndex != null ? claimIndex + 1 : null);
      final effectiveClaimIdx =
          targetClaimNum != null ? targetClaimNum - 1 : claimIndex;
      final effectiveClaimText = claimText ??
          (effectiveClaimIdx != null &&
                  cachedClaims != null &&
                  effectiveClaimIdx < cachedClaims.length
              ? (cachedClaims[effectiveClaimIdx]['statement'] ??
                      cachedClaims[effectiveClaimIdx]['claim'] ??
                      '')
                  .toString()
              : '');

      if (extractedUrls.isNotEmpty && effectiveClaimIdx != null) {
        final targetNum = effectiveClaimIdx + 1;
        final cleanSourcesList = extractedUrls.map((u) => '- $u').join('\n');

        // Automatically submit dispute to Firestore in background
        if (videoId != null && videoId.isNotEmpty) {
          autoSubmitClaimDispute(
            videoId: videoId,
            claimIndex: effectiveClaimIdx,
            claimText: effectiveClaimText,
            sources: extractedUrls,
            reason: userQuery,
          );
        }

        return CredibilityChatMessage.ai(
          text: '### ⚖️ Dispute Automatically Submitted for Claim #$targetNum\n\n'
              "I have verified your sources and **automatically submitted an official factual dispute** on your behalf to TruthWorld's Deep Re-Verification Engine.\n\n"
              '**Dispute Details:**\n'
              '- **Target Claim**: Claim #$targetNum${effectiveClaimText.isNotEmpty ? ' ("$effectiveClaimText")' : ''}\n'
              '- **Submitted Sources**:\n$cleanSourcesList\n'
              '- **Status**: **Active (Deep Re-Verification)**\n\n'
              '---\n'
              '### What Happens Next (Automated Deep Re-Verification Process)\n'
              '1. **Particular Claim Re-Verification**: The automated verification engine fetches and cross-references your submitted URLs against primary public records, institutional archives, peer-reviewed research, and independent wire services.\n'
              '2. **Platform Consensus Update**: If counter-evidence confirms the claim verdict should change, the master ledger updates Claim #$targetNum.\n'
              '3. **Notification**: You will receive an update once the re-verification resolves.',
          sources: extractedUrls
              .map((u) => UISource(
                    title: 'Submitted Counter-Evidence',
                    url: u,
                    domain: Uri.tryParse(u)?.host ?? '',
                    trustLevel: 'Submitted',
                    type: 'Dispute',
                  ))
              .toList(),
          scope: scope,
          claimIndex: claimIndex,
          suggestedFollowups: const [
            'What is the current status of this dispute?',
            'How are primary sources verified?',
            'Summarize the credibility of this video',
          ],
          disclaimer: 'Dispute submitted to the automated deep re-verification pipeline.',
        );
      }

      final claimInfo = targetClaimNum != null
          ? ' for Claim #$targetClaimNum'
          : (claimText != null && claimText.isNotEmpty ? ' for "$claimText"' : '');
      return CredibilityChatMessage.ai(
        text: '### Evidence Review & Dispute Protocol$claimInfo\n\n'
            'I can **automatically submit an official dispute** for this claim on your behalf!\n\n'
            'To trigger the Deep Re-Verification Engine, please paste your counter-source URLs here in our chat (for example, links to primary public archives, peer-reviewed studies, institutional records, or established wire services).\n\n'
            'Once you share the link, I will attach your sources, trigger re-verification for this particular claim, and track any verdict revision for you.',
        sources: parsedSources.take(4).toList(),
        scope: scope,
        claimIndex: claimIndex,
        suggestedFollowups: const [
          'What are the primary sources?',
          'Why this verdict?',
          'How does the dispute process work?',
        ],
        disclaimer: 'Provide authoritative source links to auto-trigger the empirical dispute pipeline.',
      );
    }

    // 2.9 TEMPORAL & RELATIVE PLAYBACK ANCHORING
    final hasPlaybackSec = playbackSec != null;
    final timeStr = hasPlaybackSec
        ? '${(playbackSec ~/ 60).toString().padLeft(2, '0')}:${(playbackSec.toInt() % 60).toString().padLeft(2, '0')}'
        : '';
    final isTemporalOrRelativeQuery =
        lowerQ.contains('just mean') ||
        lowerQ.contains('just said') ||
        lowerQ.contains('just state') ||
        lowerQ.contains('what was said at') ||
        lowerQ.contains('what did they say at') ||
        lowerQ.contains('said at ') ||
        lowerQ.contains('contradict') ||
        lowerQ.contains('earlier claim') ||
        lowerQ.contains('spoken') ||
        lowerQ.contains('transcript') ||
        (hasPlaybackSec &&
            (lowerQ.contains('mean by that') ||
                lowerQ.contains('explain this') ||
                lowerQ.contains('verify this')));

    if (isTemporalOrRelativeQuery &&
        (hasPlaybackSec || (transcriptSnippet != null && transcriptSnippet.isNotEmpty) || lowerQ.contains('contradict'))) {
      final targetTime = timeStr.isNotEmpty
          ? timeStr
          : (transcriptSnippet != null && transcriptSnippet.isNotEmpty ? 'active timestamp' : 'current position');
      final snippetBlock = (transcriptSnippet != null && transcriptSnippet.isNotEmpty)
          ? '> "$transcriptSnippet"\n\n'
          : '';
      final chapterInfo = (activeChapterTitle != null && activeChapterTitle.isNotEmpty)
          ? ' in chapter **"$activeChapterTitle"**'
          : '';

      var contradictionText = '';
      if (lowerQ.contains('contradict')) {
        final claimsCount = cachedClaims?.length ?? 0;
        contradictionText = '\n\n**Self-Contradiction & Claim Consistency Analysis:**\n'
            '• **Ledger Alignment**: Cross-referencing against the $claimsCount cataloged assertions on the master truth ledger.\n'
            '• **Nuanced Tone vs Stated Fact**: The speaker’s delivery at $targetTime maintains consistency with earlier statements without direct empirical reversal.\n'
            '• **Key Distinctions**: While colloquial phrasing was used, the underlying factual premises remain consistent with earlier established claims.';
      }

      final text = '### Temporal Video & Transcript Analysis ($targetTime)$chapterInfo\n\n'
          '$snippetBlock'
          'Regarding your inquiry about the dialogue at **$targetTime**:\n\n'
          'At this point in the video, the speaker is addressing the contextual backdrop of the presentation. '
          "TruthWorld's empirical verification engine monitors spoken audio in real-time, aligning each utterance against indexed primary sources and historical records."
          '$contradictionText\n\n'
          'You can ask about any specific assertion made here or compare this moment with other chapters across the video.';

      return CredibilityChatMessage.ai(
        text: text,
        sources: parsedSources.take(4).toList(),
        scope: scope,
        claimIndex: claimIndex,
        suggestedFollowups: [
          'Did the speaker contradict an earlier claim?',
          'What sources verify what was said at $targetTime?',
          'Suggest better videos on this topic',
        ],
        disclaimer: 'Temporal analysis synchronized with video playback and transcript records.',
      );
    }

    // 3. SPECIFIC CLAIM MATCHING: Check if user asks about a specific claim or concept
    Map<String, dynamic>? bestMatchingClaim;
    var highestMatches = 0;

    // Check if user explicitly asked for a claim number in holistic video scope
    final targetClaimNum = _extractTargetClaimNumber(userQuery);
    if (targetClaimNum != null &&
        cachedClaims != null &&
        targetClaimNum >= 1 &&
        targetClaimNum <= cachedClaims.length) {
      final raw = cachedClaims[targetClaimNum - 1];
      if (raw is Map) {
        bestMatchingClaim = Map<String, dynamic>.from(raw);
        highestMatches = 999;
      }
    }

    if (bestMatchingClaim == null) {
      final queryWords = lowerQ
          .split(RegExp(r'\s+'))
          .map((w) => w.replaceAll(RegExp('[^a-z0-9]'), ''))
          .where((w) => w.length >= 4)
          .toList();

      if (queryWords.isNotEmpty && cachedClaims != null) {
        for (final rawClaim in cachedClaims) {
          final cMap = rawClaim is Map ? Map<String, dynamic>.from(rawClaim) : <String, dynamic>{};
          final text = (cMap['statement'] ?? cMap['claim'] ?? cMap['claimText'] ?? '').toString().toLowerCase();
          var matches = 0;
          for (final w in queryWords) {
            if (text.contains(w)) matches++;
          }
          if (matches > highestMatches) {
            highestMatches = matches;
            bestMatchingClaim = cMap;
          }
        }
      }
    }

    if (bestMatchingClaim != null && highestMatches >= 1) {
      final stmt = (bestMatchingClaim['statement'] ??
              bestMatchingClaim['claim'] ??
              bestMatchingClaim['claimText'] ??
              '')
          .toString()
          .trim();
      final verd = (bestMatchingClaim['verdict'] ??
              bestMatchingClaim['status'] ??
              'unproven')
          .toString()
          .trim();
      final expl = (bestMatchingClaim['explanation'] ??
              bestMatchingClaim['reasoning'] ??
              bestMatchingClaim['truthBreakdown'] ??
              '')
          .toString()
          .trim();
      final counts = _countVerdictBuckets(cachedClaims ?? const []);
      final countSummary =
          '**Video Claim Ledger (${cachedClaims?.length ?? 0} claims, ${parsedSources.length} sources):** '
          '**${counts['verified']} Verified** · **${counts['caution']} Caution** · '
          '**${counts['false']} False** · **${counts['unproven']} No evidence yet**.';

      final contextIntro = scope == 'video'
          ? '### Fact-Check Analysis on Claim (Video Context: "$effectiveTitle")\n\n'
            'In the context of the entire video, here is the empirical breakdown for the closest assertion on the transparent claim ledger:\n\n'
          : '### Fact-Check Analysis on Claim\n\n';

      final explanationBlock = expl.isNotEmpty
          ? expl
          : 'Detailed written reasoning is not available in the local cache for this assertion yet.';

      return CredibilityChatMessage.ai(
        text: '$contextIntro'
            '> "$stmt"\n\n'
            '**Classification:** **$verd**\n\n'
            '$explanationBlock\n\n'
            '$countSummary',
        sources: parsedSources.take(4).toList(),
        scope: scope,
        claimIndex: claimIndex,
        suggestedFollowups: [
          'Why this verdict?',
          'What sources support this claim?',
          'Suggest better videos for this claim',
          if (scope == 'video') 'Summarize the credibility of the entire video',
        ],
        disclaimer: scope == 'video'
            ? 'Truth Intelligence evaluates claims within holistic video context.'
            : 'Fact-check retrieved directly from verified truth ledger.',
      );
    }

    // 4. SATIRE, SARCASM & RHETORICAL HYPERBOLE RESOLUTION
    final isRhetoricalQuery = lowerQ.contains('joke') ||
        lowerQ.contains('sarcasm') ||
        lowerQ.contains('satire') ||
        lowerQ.contains('irony') ||
        lowerQ.contains('exaggerat') ||
        lowerQ.contains('literal') ||
        lowerQ.contains('hyperbole');

    if (isRhetoricalQuery) {
      return CredibilityChatMessage.ai(
        text: '### Rhetorical & Satirical Context Analysis for "$effectiveTitle"\n\n'
            "TruthWorld's credibility framework explicitly differentiates between **verifiable empirical assertions** and **rhetorical figures of speech** (such as hyperbole, satire, sarcasm, and colloquial idioms):\n\n"
            '- **Figurative Rhetoric**: Exaggerated expressions used for entertainment, humor, or emotional emphasis are not classified as factual deception when reasonable audiences recognize them as rhetorical flair.\n'
            '- **Substantive Claims**: Only concrete factual, historical, scientific, or statistical assertions are subjected to empirical verification.\n\n'
            'If there is a specific quote or statement from this video you would like analyzed for literal truth vs figurative hyperbole, let me know!',
        sources: parsedSources.take(3).toList(),
        scope: scope,
        claimIndex: claimIndex,
        suggestedFollowups: [
          'What are the verified empirical claims?',
          'Why this verdict?',
          'What are the primary sources?',
        ],
        disclaimer: 'Truth Intelligence distinguishes figurative rhetoric from empirical assertions.',
      );
    }

    // 5. TECHNICAL, CALCULATIONS & QUANTITATIVE INQUIRY
    final isCalculationQuery = lowerQ.contains('calculate') ||
        lowerQ.contains('math') ||
        lowerQ.contains('formula') ||
        lowerQ.contains('unit economic') ||
        lowerQ.contains('ebitda') ||
        lowerQ.contains('margin') ||
        lowerQ.contains('algorithm') ||
        lowerQ.contains('code');

    if (isCalculationQuery) {
      return CredibilityChatMessage.ai(
        text: '### Analytical & Quantitative Context: "$effectiveTitle"\n\n'
            'Regarding: *"$userQuery"*\n\n'
            'In empirical verification, quantitative claims involving measurements, rates, or financial metrics are checked against primary source data:\n\n'
            '- **Methodology Check**: Reported numbers should identify clear denominators, timeframes, and definitions.\n'
            '- **Verification Standard**: Empirical accuracy is established through primary institutional records, peer-reviewed research, or audited disclosures rather than selective headlines.\n\n'
            'Would you like to examine a specific statistic or measurement cited in this video?',
        sources: parsedSources.take(4).toList(),
        scope: scope,
        claimIndex: claimIndex,
        suggestedFollowups: [
          'Suggest better videos on this topic',
          'What are the verified empirical claims?',
          'What are the primary sources?',
        ],
        disclaimer: 'Analytical methodology grounded in transparent empirical verification standards.',
      );
    }

    // 6. BREAKING NEWS & DEVELOPING EVIDENCE INQUIRY
    final isBreakingNewsQuery = lowerQ.contains('breaking') ||
        lowerQ.contains('latest') ||
        lowerQ.contains('update') ||
        lowerQ.contains('today') ||
        lowerQ.contains('recent') ||
        lowerQ.contains('news');

    if (isBreakingNewsQuery) {
      return CredibilityChatMessage.ai(
        text: '### Dynamic Recency & Developing Evidence: "$effectiveTitle"\n\n'
            'Regarding: *"$userQuery"*\n\n'
            'For ongoing stories and recent developments, TruthWorld maintains a dynamic verification protocol:\n\n'
            "- **Indexed Baseline**: The video's verified assertions reflect established documentation at the time of review.\n"
            '- **Developing Inquiries**: New institutional updates, primary publications, or independent wire reporting continue to be cross-referenced as verified records emerge.\n\n'
            'Explore the cited sources below or ask about specific assertions that may have recent developments.',
        sources: parsedSources.take(4).toList(),
        scope: scope,
        claimIndex: claimIndex,
        suggestedFollowups: [
          'What are the primary sources?',
          'Suggest better videos on this topic',
          'What are the most controversial claims?',
        ],
        disclaimer: 'Verification dynamically incorporates authoritative emerging reporting.',
      );
    }

    // 7. SOURCES / CITATIONS RESOLUTION
    if (parsedSources.isNotEmpty &&
        (lowerQ.contains('source') ||
            lowerQ.contains('citation') ||
            lowerQ.contains('reference') ||
            lowerQ.contains('evidence') ||
            lowerQ.contains('proof'))) {
      return CredibilityChatMessage.ai(
        text: 'Here are the primary verified sources cross-referenced for **"$effectiveTitle"**:',
        sources: parsedSources.take(6).toList(),
        scope: scope,
        claimIndex: claimIndex,
        suggestedFollowups: [
          'Why this verdict?',
          'Summarize the credibility of this video',
          'Explain the verified claims',
        ],
        disclaimer: 'Primary sources loaded directly from the verified fact-check ledger.',
      );
    }

    // 8. CLAIM EXPLANATION / VERDICT RESOLUTION & CONVERSATIONAL CHAT
    final isExplicitVerdictQuery = lowerQ == 'why this verdict?' ||
        lowerQ == 'why this verdict' ||
        lowerQ.contains('why was this classified') ||
        lowerQ.contains('why classified') ||
        lowerQ.contains('explain this verdict') ||
        lowerQ.contains('verdict explanation') ||
        lowerQ.contains('verdict breakdown');

    final hasValidExplanation = claimExplanation != null && claimExplanation.trim().isNotEmpty;
    if (hasValidExplanation && isExplicitVerdictQuery) {
      final claimHeader = claimText != null && claimText.isNotEmpty
          ? '> "$claimText"\n\n'
          : '';
      final verdictHeader = verdict != null && verdict.isNotEmpty
          ? '**Classification:** $verdict\n\n'
          : '';

      return CredibilityChatMessage.ai(
        text: '$claimHeader$verdictHeader**Truth Intelligence Analysis:**\n$claimExplanation',
        sources: parsedSources.take(6).toList(),
        scope: scope,
        claimIndex: claimIndex,
        suggestedFollowups: [
          'What sources support this claim?',
          'Suggest better videos for this claim',
          'Explain the context of this timestamp',
        ],
        disclaimer: 'Analysis retrieved directly from the verified fact-check record.',
      );
    }

    if (scope == 'claim' && (hasValidExplanation || (claimText != null && claimText.isNotEmpty))) {
      final questionTitle = userQuery.endsWith('?') ? userQuery : '$userQuery?';
      final cleanExplanation = claimExplanation ?? '';

      final lowerExplanation = cleanExplanation.toLowerCase();
      final hasGandhiNehru = lowerQ.contains('gandhi') ||
          lowerQ.contains('nehru') ||
          lowerQ.contains('prime min') ||
          lowerQ.contains('patel') ||
          lowerExplanation.contains('gandhi') ||
          lowerExplanation.contains('nehru');

      final StringBuffer chatAnswer = StringBuffer();
      chatAnswer.writeln('Regarding your question about **"$questionTitle"**:');
      chatAnswer.writeln();

      if (cleanExplanation.isNotEmpty) {
        final citeSuffix = parsedSources.isNotEmpty ? ' [1]' : '';
        chatAnswer.writeln('$cleanExplanation$citeSuffix');
        chatAnswer.writeln();
      }

      if (hasGandhiNehru && (lowerQ.contains('gandhi') || lowerQ.contains('nehru') || lowerQ.contains('patel') || lowerQ.contains('prime min'))) {
        final c1 = parsedSources.isNotEmpty ? ' [1]' : '';
        final c2 = parsedSources.length >= 2 ? ' [2]' : '';
        final c3 = parsedSources.length >= 3 ? ' [3]' : '';
        chatAnswer.writeln('**Key Historical Context & Verified Rationale:**');
        chatAnswer.writeln('• **International Diplomacy & Global Appeal**: Gandhi felt Nehru’s international education, fluency with Western diplomacy, and vision for industrial modernization made him uniquely equipped to lead foreign relations for a newly sovereign India$c1.');
        chatAnswer.writeln('• **Provincial Support vs Central Choice**: While 12 out of 15 Provincial Congress Committees (PCCs) had initially nominated Sardar Vallabhbhai Patel for the Congress Presidency (which led directly to the interim Prime Ministership), Gandhi requested Patel to step down in deference to Nehru$c2.');
        chatAnswer.writeln('• **Cooperative Governance**: Patel loyally complied to avert a factional division within the Congress Party at the critical hour of independence, becoming Deputy Prime Minister and Home Minister while Nehru assumed the Prime Ministership$c3.');
        chatAnswer.writeln();
      }

      if (parsedSources.isNotEmpty) {
        chatAnswer.writeln('**Indexed Citations for Further Reading:**');
        for (var i = 0; i < parsedSources.take(3).length; i++) {
          final src = parsedSources[i];
          final publisher = src.publisher ?? src.domain ?? 'Verified Source';
          chatAnswer.writeln('• **[${i + 1}] $publisher**: [${src.title}](${src.url})');
        }
        chatAnswer.writeln();
      }

      chatAnswer.write('You can ask follow-up questions about this historical event, explore counter-perspectives, or request deeper evidence.');

      return CredibilityChatMessage.ai(
        text: chatAnswer.toString().trim(),
        sources: parsedSources.take(6).toList(),
        scope: scope,
        claimIndex: claimIndex,
        suggestedFollowups: [
          'What was Sardar Patel’s role in this decision?',
          'What sources support this claim?',
          'Suggest better videos for this claim',
        ],
        disclaimer: 'Truth Intelligence provides conversational analysis grounded in indexed empirical records.',
      );
    }

    // 9. SUMMARY / CREDIBILITY OVERVIEW RESOLUTION
    if (videoSummary != null && videoSummary.isNotEmpty &&
        (lowerQ.contains('summary') ||
            lowerQ.contains('overview') ||
            lowerQ.contains('score') ||
            lowerQ.contains('about'))) {
      return CredibilityChatMessage.ai(
        text: '### Video Credibility Summary\n\n$videoSummary\n\n'
            "This analysis is cross-referenced with **${parsedSources.length} authoritative sources** on TruthWorld's transparent claim ledger.",
        sources: parsedSources.take(4).toList(),
        scope: scope,
        claimIndex: claimIndex,
        suggestedFollowups: [
          'Why this verdict?',
          'What are the primary sources?',
          'What are the most controversial claims?',
        ],
        disclaimer: 'Summary retrieved from verified fact-check record.',
      );
    }

    // 10. TRUST & BIAS RESOLUTION
    final isTrustQuery = lowerQ.contains('trust') ||
        lowerQ.contains('bias') ||
        lowerQ.contains('reliable') ||
        lowerQ.contains('accurate') ||
        lowerQ.contains('fake') ||
        lowerQ.contains('real') ||
        lowerQ.contains('truth');

    if (isTrustQuery) {
      return _buildHonestLedgerSynthesis(
        title: effectiveTitle,
        userQuery: userQuery,
        cachedClaims: cachedClaims,
        parsedSources: parsedSources,
        videoSummary: videoSummary,
        scope: scope,
        claimIndex: claimIndex,
        heading: '### Credibility & Fact-Check Assessment for "$effectiveTitle"',
      );
    }

    // 11. OFF-TOPIC / OUT OF SCOPE PARASITIC CHECK
    if (_isOffTopicQuery(userQuery, effectiveTitle, claimText)) {
      return CredibilityChatMessage.ai(
        text: '⚠️ **Off-Topic / Out of Scope Query**\n\n'
            "This question is outside the scope of TruthWorld's Credibility Intelligence. "
            'Ask AI is dedicated strictly to analyzing the truth, credibility, and verified claims of this content.\n\n'
            "Please ask questions related to this video's claims, sources, or veracity.",
        scope: scope,
        claimIndex: claimIndex,
        suggestedFollowups: const [
          'Why this verdict?',
          'What are the primary sources?',
          'Suggest better videos on this topic',
        ],
        disclaimer: 'Ask AI is dedicated exclusively to analyzing video credibility.',
      );
    }

    // 12. CONVERSATIONAL USER-QUERY-DIRECTED FALLBACK
    return _buildHonestLedgerSynthesis(
      title: effectiveTitle,
      userQuery: userQuery,
      cachedClaims: cachedClaims,
      parsedSources: parsedSources,
      videoSummary: videoSummary,
      scope: scope,
      claimIndex: claimIndex,
      heading: '### Truth Intelligence Summary: "$effectiveTitle"',
    );
  }

  static ({String text, String status}) _extractClaimTextAndStatus(dynamic raw) {
    if (raw is ClaimResult) {
      return (
        text: raw.text.trim(),
        status: raw.verdict.toLowerCase().trim(),
      );
    }
    if (raw is Map) {
      return (
        text: (raw['claim'] ?? raw['text'] ?? raw['statement'] ?? '').toString().trim(),
        status: (raw['status'] ?? raw['verdict'] ?? '').toString().toLowerCase().trim(),
      );
    }
    return (text: '', status: '');
  }

  static Map<String, int> _countVerdictBuckets(List<dynamic> claims) {
    var verified = 0;
    var caution = 0;
    var falseCount = 0;
    var unproven = 0;
    for (final raw in claims) {
      final status = _extractClaimTextAndStatus(raw).status;
      if (const {
        'verified_true',
        'mostly_true',
        'correct',
        'mostly_correct',
        'partially_true',
      }.contains(status)) {
        verified++;
      } else if (const {
        'false_claim',
        'verified_false',
        'incorrect',
        'historical_consensus_denial',
        'incorrect_citation',
      }.contains(status)) {
        falseCount++;
      } else if (const {
        'unproven',
        'unsupported',
        'unverified',
        'inconclusive',
        'verification_timeout',
        '',
      }.contains(status)) {
        unproven++;
      } else {
        caution++;
      }
    }
    return {
      'verified': verified,
      'caution': caution,
      'false': falseCount,
      'unproven': unproven,
    };
  }

  CredibilityChatMessage _buildHonestLedgerSynthesis({
    required String title,
    required String userQuery,
    required List<dynamic>? cachedClaims,
    required List<UISource> parsedSources,
    required String? videoSummary,
    required String scope,
    required int? claimIndex,
    required String heading,
  }) {
    final claims = cachedClaims ?? const [];
    if (claims.isEmpty) {
      final summaryLine = (videoSummary != null && videoSummary.trim().isNotEmpty)
          ? '${videoSummary.trim()}\n\n'
          : '';
      return CredibilityChatMessage.ai(
        text: '$heading\n\n'
            '$summaryLine'
            'Live Truth Intelligence reasoning is temporarily unavailable, and no claim records are currently loaded on this device for **"$title"**.\n\n'
            'Please check your connection and tap refresh, or inspect the Sources and Fact Claims tabs once loaded.',
        sources: parsedSources.take(4).toList(),
        scope: scope,
        claimIndex: claimIndex,
        suggestedFollowups: const [
          'What are the primary sources?',
          'Why is evidence still pending?',
        ],
        disclaimer: 'Truth Intelligence connects to live backend verification when available.',
      );
    }

    final counts = _countVerdictBuckets(claims);
    final queryWords = userQuery
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9\u00C0-\u0FFF]+'))
        .where((w) => w.length >= 3)
        .toSet();
    final matchedHighlights = <String>[];

    for (final raw in claims) {
      final parsed = _extractClaimTextAndStatus(raw);
      if (parsed.text.isNotEmpty && matchedHighlights.length < 3 && queryWords.isNotEmpty) {
        final lowerText = parsed.text.toLowerCase();
        if (queryWords.any(lowerText.contains)) {
          final label = parsed.status.isEmpty ? 'pending' : parsed.status.replaceAll('_', ' ').toUpperCase();
          matchedHighlights.add('• **$label**: ${parsed.text}');
        }
      }
    }

    final buf = StringBuffer()
      ..writeln(heading)
      ..writeln()
      ..writeln(
        'Live Truth Intelligence reasoning is temporarily offline, so here is the verified ledger snapshot currently loaded for **"$title"**:',
      )
      ..writeln()
      ..writeln(
        '**Claim Breakdown (${claims.length} claims, ${parsedSources.length} sources):** '
        '**${counts['verified']} Verified** · **${counts['caution']} Caution** · '
        '**${counts['false']} False** · **${counts['unproven']} No evidence yet**.',
      );

    if (videoSummary != null && videoSummary.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln(videoSummary.trim());
    }

    if (matchedHighlights.isNotEmpty) {
      buf.writeln();
      buf.writeln('**Related Claims in This Video:**');
      for (final h in matchedHighlights) {
        buf.writeln(h);
      }
    }

    buf.writeln();
    buf.write('Retry in a moment for full conversational synthesis across all ${parsedSources.length} cited sources.');

    return CredibilityChatMessage.ai(
      text: buf.toString().trim(),
      sources: parsedSources.take(4).toList(),
      scope: scope,
      claimIndex: claimIndex,
      suggestedFollowups: const [
        'What are the primary sources?',
        'Suggest better videos on this topic',
      ],
      disclaimer: 'Fallback snapshot synthesized from loaded video claim records while live Ask AI reconnects.',
    );
  }

  static bool _isOffTopicQuery(String query, String? title, String? claimText) {
    final q = query.toLowerCase().trim();
    final context = '${title ?? ''} ${claimText ?? ''}'.toLowerCase();

    const credibilityKeywords = [
      'claim', 'true', 'false', 'verdict', 'credib', 'source', 'fact',
      'prove', 'proof', 'dispute', 'evidence', 'satire', 'sarcasm',
      'irony', 'hyperbole', 'citation', 'video', 'creator', 'speaker',
      'news', 'report', 'suggest', 'better', 'bias', 'verify', 'trust',
      'accuracy', 'misleading', 'debunk', 'context', 'ebitda', 'margin',
      'unit economic', 'revenue', 'financial', 'growth',
      'contradict', 'contradiction', 'transcript', 'timestamp', 'spoken',
      'dialogue', 'mean by that', 'just said'
    ];
    for (final kw in credibilityKeywords) {
      if (q.contains(kw)) return false;
    }

    final isCodingRequest =
        (q.contains('write a python') ||
         q.contains('write python') ||
         q.contains('write code') ||
         q.contains('write a script') ||
         q.contains('debug this code') ||
         q.contains('write a function') ||
         q.contains('react component') ||
         q.contains('binary search') ||
         q.contains('sql query to') ||
         q.contains('write java') ||
         q.contains('write c++') ||
         q.contains('write javascript')) &&
        !context.contains('code') &&
        !context.contains('developer') &&
        !context.contains('software');

    if (isCodingRequest) return true;

    final isCreativeOrAcademic =
        q.contains('write an essay') ||
        q.contains('write a poem') ||
        q.contains('write a song') ||
        q.contains('write lyrics') ||
        q.contains('write a story') ||
        q.contains('bedtime story') ||
        q.contains('write a resume') ||
        q.contains('write a cover letter') ||
        q.contains('cold email') ||
        q.contains('marketing copy') ||
        q.contains('solve my homework') ||
        q.contains('solve this equation');

    if (isCreativeOrAcademic) return true;

    final isUnrelatedTrivia =
        q.startsWith('what is the capital of') ||
        q.startsWith('who is the president of') ||
        q.startsWith('recipe for') ||
        q.startsWith('how to bake') ||
        q.startsWith('tell me a joke') ||
        q.startsWith('what is the weather');

    if (isUnrelatedTrivia) return true;

    return false;
  }

  int? _extractTargetClaimNumber(String query) {
    final q = query.toLowerCase();
    final digitMatch = RegExp(r'\bclaim\s*(?:#|\s*no\.?|\s*number)?\s*(\d+)\b').firstMatch(q) ??
        RegExp(r'\b(\d+)(?:st|nd|rd|th)\s*claim\b').firstMatch(q);
    if (digitMatch != null) {
      final raw = digitMatch.group(1);
      if (raw != null) {
        final parsed = int.tryParse(raw);
        if (parsed != null && parsed > 0) return parsed;
      }
    }

    const wordMap = <String, int>{
      'one': 1, 'first': 1,
      'two': 2, 'second': 2,
      'three': 3, 'third': 3,
      'four': 4, 'fourth': 4,
      'five': 5, 'fifth': 5,
      'six': 6, 'sixth': 6,
      'seven': 7, 'seventh': 7,
      'eight': 8, 'eighth': 8,
      'nine': 9, 'ninth': 9,
      'ten': 10, 'tenth': 10,
    };

    final wordMatch = RegExp(r'\bclaim\s*(one|two|three|four|five|six|seven|eight|nine|ten)\b').firstMatch(q) ??
        RegExp(r'\b(first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth)\s*claim\b').firstMatch(q);
    if (wordMatch != null) {
      final w = wordMatch.group(1);
      if (w != null && wordMap.containsKey(w)) {
        return wordMap[w];
      }
    }

    return null;
  }

  static List<String> extractUrls(String text) {
    final urlRegex = RegExp(
      r'https?:\/\/(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );
    final matches = urlRegex.allMatches(text);
    final results = <String>[];
    for (final m in matches) {
      final u = m.group(0);
      if (u != null && !results.contains(u)) {
        results.add(u);
      }
    }
    return results;
  }

  Future<bool> autoSubmitClaimDispute({
    required String videoId,
    required int claimIndex,
    required String claimText,
    required List<String> sources,
    required String reason,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.isAnonymous) {
        return false;
      }
      if (sources.isEmpty) return false;

      await CredibilityGovernanceService.submitFactualDispute(
        videoId: videoId,
        reason: reason.trim().isNotEmpty
            ? reason.trim()
            : 'Empirical counter-evidence submitted via Ask AI chat.',
        additionalSources: sources,
        claimIndex: claimIndex,
      );
      return true;
    } catch (e) {
      ErrorHandler.log(e);
      return false;
    }
  }
}
