import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide SearchController;
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/core/services/algorithm/user_signal_tracker.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/domain/usecases/search/search_videos_usecase.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/data/services/search_service.dart';
import 'package:truthworld/features/search/presentation/controllers/search/search_components.dart';

export 'search/search_components.dart';

/// SearchController: Business logic, debouncing, caching & orchestration layer.
class SearchController extends BaseController {
  final SearchService _searchService;
  final SearchRateLimiter _rateLimiter;
  final SearchHistoryCacheManager _cacheManager;
  final SearchTrendingManager _trendingManager;
  final SearchSuggestionsEngine _suggestionsEngine;
  final SearchVideosUseCase? _searchVideosUseCase;

  SearchController({
    SearchService? searchService,
    SearchRateLimiter? rateLimiter,
    SearchHistoryCacheManager? cacheManager,
    SearchTrendingManager? trendingManager,
    SearchSuggestionsEngine? suggestionsEngine,
    SearchVideosUseCase? searchVideosUseCase,
  })  : _searchService = searchService ?? SearchService(),
        _rateLimiter = rateLimiter ?? SearchRateLimiter(),
        _cacheManager = cacheManager ?? SearchHistoryCacheManager(),
        _trendingManager = trendingManager ?? SearchTrendingManager(),
        _suggestionsEngine = suggestionsEngine ?? SearchSuggestionsEngine(),
        _searchVideosUseCase = searchVideosUseCase ??
            (Get.isRegistered<SearchVideosUseCase>()
                ? Get.find<SearchVideosUseCase>()
                : null);

  // Observable State

  /// Current search query
  final RxString searchQuery = ''.obs;

  /// Search results (empty list when idle)
  final RxList<SearchResult> searchResults = <SearchResult>[].obs;

  /// Loading state
  final RxBool rxIsLoading = false.obs;
  @override
  bool get isLoading => rxIsLoading.value || super.isLoading;

  /// Error message (if any)
  final RxString rxErrorMessage = ''.obs;
  @override
  String get errorMessage => rxErrorMessage.value.isNotEmpty ? rxErrorMessage.value : super.errorMessage;

  /// Recent searches history
  final RxList<String> recentSearches = <String>[].obs;

  final RxList<String> suggestions = <String>[].obs;
  final RxList<SearchResult> recommendedResults = <SearchResult>[].obs;
  final RxBool isRecommendedLoading = false.obs;
  final Map<String, List<SearchResult>> _recommendedCache = {};

  // Realtime Trending Today state
  final RxList<TrendingItem> realtimeTrendingItems = <TrendingItem>[].obs;
  final RxBool isRealtimeTrendingLoading = false.obs;

  // Suggestions & filters
  final RxList<SearchSuggestion> richSuggestions = <SearchSuggestion>[].obs;
  final RxBool showSuggestions = false.obs;
  final RxBool isShowingFallback = false.obs;
  final Rx<AiSearchIntent?> activeAiIntent = Rx<AiSearchIntent?>(null);
  final RxBool isAiSearching = false.obs;
  final RxList<SearchResult> broadenedResults = <SearchResult>[].obs;
  final RxBool isBroadenedView = false.obs;
  final RxString selectedFilter = 'All'.obs;
  final RxSet<String> watchedVideoIds = <String>{}.obs;
  final RxBool isNavigating = false.obs;

  /// Search execution tracking (decouples live typing from submitted search)
  final RxBool hasExecutedSearch = false.obs;
  final RxString executedQuery = ''.obs;

  /// Cache statistics (for debugging)
  final RxMap<String, dynamic> cacheStats = <String, dynamic>{}.obs;

  /// Pagination state
  final RxInt currentPage = 0.obs;
  final RxBool hasMoreResults = false.obs;
  final RxBool isLoadingMore = false.obs;

  // Debounce & cancellation tokens
  final Duration debounceDelay = const Duration(milliseconds: 250);
  int _searchToken = 0;
  int _suggestionToken = 0;
  String _lastSearchQuery = '';
  String _lastSuggestionQuery = '';

  // Pagination & limits

  static const int resultsPerPage = 15;
  static const int maxRecentSearches = 10;
  static const int maxSearchQueryLength = 100;
  static const int minSearchQueryLength = 1;

  List<SearchResult> _allResults = [];

  late final TextEditingController textEditingController = trackTextController(TextEditingController());
  late final ScrollController scrollController = trackScrollController(ScrollController());

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(() {
      if (!scrollController.hasClients || scrollController.positions.length != 1) return;
      final position = scrollController.position;
      if (position.pixels > position.maxScrollExtent * 0.8) {
        loadNextPage();
      }
    });

    unawaited(_loadPersistentCache());
    unawaited(_loadRecentSearches());
    unawaited(fetchTrendingSuggestions());
    unawaited(_fetchWatchedVideoIds());
    _initRealtimeTrendingSubscription();
    unawaited(fetchRecommendedForFilter(selectedFilter.value));

    // Snappy GetX worker debounce
    addWorker(
      debounce(
        searchQuery,
        _onQueryDebounced,
        time: debounceDelay,
      ),
    );

    if (Get.isRegistered<UserLanguagesService>()) {
      addWorker(
        ever(UserLanguagesService.to.primaryLanguage, (_) {
          _searchService.clearCache();
          if (searchQuery.value.trim().isNotEmpty) {
            _executeSearch(searchQuery.value.trim());
          } else {
            fetchRecommendedForFilter(selectedFilter.value);
          }
        }),
      );
    }
  }

  void _onQueryDebounced(String query) {
    final (isValid, sanitized, errorMsg) = SearchFilterHelper.validateQuery(query);
    if (!isValid && query.isNotEmpty) {
      rxErrorMessage.value = errorMsg;
      return;
    }
    if (query.isEmpty) return;
    _fetchRichSuggestions(sanitized);
  }

  Future<void> _loadPersistentCache() async {
    final cached = await _cacheManager.loadPersistentCache();
    if (cached.isNotEmpty) {
      _allResults = cached;
    }
  }

  Future<void> _loadRecentSearches() async {
    final recent = await _cacheManager.loadRecentSearches();
    recentSearches.assignAll(recent);
  }

  Future<void> _saveRecentSearches() async {
    await _cacheManager.saveRecentSearches(recentSearches.toList());
  }

  void _initRealtimeTrendingSubscription() {
    final sub = _trendingManager.subscribeToTrending(
      onTrendingLoaded: realtimeTrendingItems.assignAll,
      onLoadingChanged: (loading) => isRealtimeTrendingLoading.value = loading,
    );
    if (sub != null) trackSubscription(sub);
  }

  Future<void> fetchRecommendedForFilter(String filter) async {
    if (_recommendedCache.containsKey(filter) && _recommendedCache[filter]!.isNotEmpty) {
      recommendedResults.assignAll(_recommendedCache[filter]!);
      return;
    }

    try {
      isRecommendedLoading.value = true;
      final recs = await _searchService.getRecommendedForFilter(
        filter,
        watchedVideoIds: watchedVideoIds,
      );
      _recommendedCache[filter] = recs;
      if (selectedFilter.value == filter) {
        recommendedResults.assignAll(recs);
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchController.fetchRecommendedForFilter');
    } finally {
      isRecommendedLoading.value = false;
    }
  }

  List<TrendingItem> get filteredRealtimeTrending {
    return SearchTrendingManager.filterTrending(realtimeTrendingItems, selectedFilter.value);
  }

  void onSearchChanged(String query) {
    final (isValid, _, errorMsg) = SearchFilterHelper.validateQuery(query);
    if (!isValid && query.isNotEmpty) {
      rxErrorMessage.value = errorMsg;
      return;
    }

    if (query.isEmpty) {
      searchQuery.value = query;
      _clearResults();
      richSuggestions.clear();
      showSuggestions.value = false;
      return;
    }

    // Reset executed search flag when user edits the query away from what was submitted
    if (hasExecutedSearch.value &&
        query.trim().toLowerCase() != executedQuery.value.toLowerCase()) {
      hasExecutedSearch.value = false;
    }

    showSuggestions.value = true;
    searchQuery.value = query;
  }

  Future<void> _fetchRichSuggestions(String query) async {
    final normalized = query.toLowerCase().trim();
    if (normalized.isEmpty || normalized == _lastSuggestionQuery) return;
    _lastSuggestionQuery = normalized;

    _suggestionToken++;
    final token = _suggestionToken;

    final results = await _suggestionsEngine.fetchRichSuggestions(
      query: normalized,
      recentSearches: recentSearches.toList(),
      currentToken: token,
      isTokenActive: (t) => t == _suggestionToken,
    );

    if (token != _suggestionToken) return;
    richSuggestions.assignAll(results);
  }

  Future<void> performSearch(String query) async {
    showSuggestions.value = false;
    searchQuery.value = query;
    await _executeSearch(query);
  }

  Future<void> _fetchWatchedVideoIds() async {
    try {
      if (!Get.isRegistered<AuthService>()) return;
      final uid = AuthService.to.uid;
      if (uid.isEmpty) return;
      final ids = await _cacheManager.fetchWatchedVideoIds(uid);
      watchedVideoIds.assignAll(ids);
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchController._fetchWatchedVideoIds');
    }
  }

  List<SearchResult> get filteredResults {
    return SearchFilterHelper.applyFilter(
      results: _allResults,
      filter: selectedFilter.value,
      watchedVideoIds: watchedVideoIds,
      userPrimaryLanguage: Get.isRegistered<UserLanguagesService>()
          ? UserLanguagesService.to.primaryLanguage.value
          : 'English',
    );
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    if (searchQuery.value.trim().isNotEmpty) {
      currentPage.value = 0;
      _loadPage(0);
    } else {
      fetchRecommendedForFilter(filter);
    }
  }

  Future<void> _executeSearch(String query) async {
    final (isValid, cleanQuery, _) = SearchFilterHelper.validateQuery(query);
    if (!isValid || cleanQuery.isEmpty) return;

    hasExecutedSearch.value = true;
    executedQuery.value = cleanQuery;

    final normalized = cleanQuery;
    if (normalized == _lastSearchQuery && searchResults.isNotEmpty) {
      showSuggestions.value = false;
      return;
    }
    _lastSearchQuery = normalized;

    _searchToken++;
    final token = _searchToken;

    if (_rateLimiter.isRateLimitExceeded()) {
      rxErrorMessage.value = 'Too many searches. Please slow down and try again in a moment.';
      AppSnackbar.warning(
        'Please wait a moment before searching again.',
        title: 'Rate Limited',
      );
      return;
    }

    showSuggestions.value = false;
    if (!_searchService.isCached(normalized)) {
      rxIsLoading.value = true;
    }

    rxErrorMessage.value = '';
    currentPage.value = 0;
    _allResults = [];

    final stopwatch = Stopwatch()..start();

    try {
      isAiSearching.value = true;
      final execResult = await SearchExecutionPipeline.execute(
        query: normalized,
        searchService: _searchService,
        activeFilter: selectedFilter.value,
        watchedVideoIds: watchedVideoIds,
      );

      if (token != _searchToken) return;

      activeAiIntent.value = execResult.activeAiIntent;
      isBroadenedView.value = false;
      broadenedResults.assignAll(execResult.broadenedResults);
      isShowingFallback.value = execResult.isShowingFallback;

      stopwatch.stop();

      _allResults = execResult.results;

      if (_allResults.isEmpty && _searchVideosUseCase != null) {
        final domainRes = await _searchVideosUseCase(
          SearchVideosParams(query: normalized),
        );
        domainRes.when(
          success: (entities) {
            if (entities.isNotEmpty) {
              _allResults = entities
                  .map((e) => SearchResult(
                        id: e.id,
                        title: e.title,
                        thumbnail: e.thumbnailUrl,
                        channelName: e.channelName,
                        channelImage: e.channelAvatarUrl,
                        createdAt: Timestamp.fromDate(e.createdAt),
                        views: e.viewCount,
                        category: e.category,
                        durationMs: e.duration.inMilliseconds,
                      ))
                  .toList();
            }
          },
          failure: (_) {},
        );
      }

      _cacheManager.savePersistentCache(_allResults);
      _loadPage(0);

      rxIsLoading.value = false;
      _addToRecentSearches(normalized);

      if (Get.isRegistered<UserSignalTracker>()) {
        Get.find<UserSignalTracker>().trackSearch(query: normalized);
      }

      cacheStats.value = _searchService.getCacheStats();
      SearchAnalyticsTracker.trackSearchAnalytics(
        query: normalized,
        resultCount: _allResults.length,
        latencyMs: stopwatch.elapsedMilliseconds,
        wasCached: _searchService.isCached(normalized),
      );

      _rateLimiter.recordQuery();

      if (_allResults.isEmpty) {
        rxErrorMessage.value = 'No results found for "$normalized"';
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(e, stackTrace: stackTrace, tag: 'SearchController.executeSearch');
      if (token != _searchToken) return;

      stopwatch.stop();
      rxErrorMessage.value = 'Search failed. Please try again.';
      SearchAnalyticsTracker.trackSearchAnalytics(
        query: normalized,
        resultCount: 0,
        latencyMs: stopwatch.elapsedMilliseconds,
        wasCached: false,
        error: e.toString(),
      );
    } finally {
      if (token == _searchToken) {
        rxIsLoading.value = false;
        isAiSearching.value = false;
      }
    }
  }

  void _addToRecentSearches(String query) {
    final updated = _cacheManager.addQueryToRecent(
      currentList: recentSearches.toList(),
      query: query,
    );
    recentSearches.assignAll(updated);
  }

  void _clearResults() {
    searchResults.clear();
    _allResults.clear();
    activeAiIntent.value = null;
    isAiSearching.value = false;
    broadenedResults.clear();
    isBroadenedView.value = false;
    rxErrorMessage.value = '';
    rxIsLoading.value = false;
    searchQuery.value = '';
    currentPage.value = 0;
    hasMoreResults.value = false;
    isShowingFallback.value = false;
    hasExecutedSearch.value = false;
    executedQuery.value = '';
  }

  void broadenSearch() {
    if (broadenedResults.isNotEmpty) {
      isBroadenedView.value = true;
      _allResults = List<SearchResult>.from(broadenedResults);
      if (scrollController.hasClients) {
        scrollController.jumpTo(0);
      }
      _loadPage(0);
    }
  }

  void clearAiSearch() {
    activeAiIntent.value = null;
    isBroadenedView.value = false;
    broadenedResults.clear();
    clearSearch();
  }

  void _loadPage(int page) {
    final (pageItems, hasMore) = SearchPaginationManager.getPageSlice(
      allItems: filteredResults,
      page: page,
    );
    searchResults.value = pageItems;
    hasMoreResults.value = hasMore;
  }

  Future<void> loadNextPage() async {
    final items = filteredResults;
    final startIndex = (currentPage.value + 1) * resultsPerPage;
    if (startIndex >= items.length || isLoadingMore.value) return;

    isLoadingMore.value = true;
    await Future.delayed(const Duration(milliseconds: 300));

    _loadPage(currentPage.value + 1);
    currentPage.value++;
    isLoadingMore.value = false;
  }

  void clearSearch() {
    textEditingController.clear();
    _clearResults();
    searchQuery.value = '';
    richSuggestions.clear();
    showSuggestions.value = false;
    fetchRecommendedForFilter(selectedFilter.value);
  }

  void searchFromRecent(String query) {
    searchQuery.value = query;
    _executeSearch(query);
  }

  void clearRecentSearches() {
    recentSearches.clear();
    _saveRecentSearches();
  }

  Future<void> fetchTrendingSuggestions() async {
    try {
      final trending = await _searchService.getTrendingSuggestions();
      suggestions.value = trending;
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchController.fetchTrendingSuggestions');
    }
  }

  Future<void> warmupCache() async {
    await _searchService.warmupCache([
      'flutter',
      'firebase',
      'web development',
      'mobile apps',
      'tutorial',
    ]);
  }

  void clearServiceCache() {
    _searchService.clearCache();
    cacheStats.value = {};
  }

  Map<String, dynamic> getCacheStats() {
    return _searchService.getCacheStats();
  }

  Map<String, String> getMemoryStats() {
    final cacheSize = getCacheStats()['size'] ?? 0;
    final resultsCount = searchResults.length;
    final recentCount = recentSearches.length;

    return {
      'cache_entries': '$cacheSize',
      'displayed_results': '$resultsCount',
      'recent_searches': '$recentCount',
      'total_cached_results': '${_allResults.length}',
    };
  }

  Future<void> onResultTapped(SearchResult result) async {
    await SearchNavigationHandler.handleResultTapped(result, isNavigating: isNavigating);
  }

  @override
  void onClose() {
    _trendingManager.dispose();
    super.onClose();
  }
}
