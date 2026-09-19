import 'package:truthworld/core/services/ai/ai_search_service.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/data/services/search_service.dart';
import 'package:truthworld/features/search/presentation/controllers/search/search_analytics_tracker.dart';

/// Result container for search execution pipeline outputs.
class SearchExecutionResult {
  SearchExecutionResult({
    required this.results,
    required this.activeAiIntent,
    required this.broadenedResults,
    required this.isShowingFallback,
  });

  final List<SearchResult> results;
  final AiSearchIntent? activeAiIntent;
  final List<SearchResult> broadenedResults;
  final bool isShowingFallback;
}

/// Pipeline executing query processing, AI intent detection, search querying,
/// language broadening, and empty-state recommendation fallback.
class SearchExecutionPipeline {
  static Future<SearchExecutionResult> execute({
    required String query,
    required SearchService searchService,
    required String activeFilter,
    required Set<String> watchedVideoIds,
  }) async {
    // 1. Parse AI search intent
    final intent = await AiSearchService.instance.parseQuery(query);
    final activeAiIntent = intent.hasCriteria ? intent : null;

    // 2. Query search service with exponential backoff
    var results = await SearchAnalyticsTracker.retryWithBackoff(
      () => searchService.search(
        query,
        intent: activeAiIntent,
        filter: activeFilter,
      ),
    );

    // 3. Broadened cross-language results
    final broadened = <SearchResult>[];
    if (activeAiIntent != null &&
        activeAiIntent.detectedLanguage != null &&
        activeAiIntent.broadenPrompt != null) {
      final broadIntent = activeAiIntent.copyWith(clearLanguage: true);
      final broadResults = await searchService.search(query, intent: broadIntent);
      broadened.addAll(broadResults);
    }

    // 4. Fallback to recommended results if query returns empty
    var fellBack = false;
    if (results.isEmpty) {
      results = await searchService.getRecommendedForFilter(
        activeFilter,
        watchedVideoIds: watchedVideoIds,
      );
      fellBack = results.isNotEmpty;
    }

    final hasDirectMatch = results.any((r) {
      final title = r.title.toLowerCase();
      final channel = r.channelName.toLowerCase();
      return title.contains(query) || channel.contains(query);
    });

    if (hasDirectMatch) fellBack = false;

    return SearchExecutionResult(
      results: results,
      activeAiIntent: activeAiIntent,
      broadenedResults: broadened,
      isShowingFallback: fellBack,
    );
  }
}
