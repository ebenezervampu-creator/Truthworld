import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // For defaultTargetPlatform
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:truthworld/features/search/data/services/search_service.dart';
import 'package:truthworld/features/search/data/models/search_result.dart'; // Correct name
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/models/playlist_model.dart';

/// SearchController: Business logic & debouncing layer
///
/// Responsibilities:
/// - Input debouncing (⭐ BIGGEST LATENCY WIN)
/// - Query validation & sanitization
/// - State management
/// - Result management with pagination
/// - Rate limiting & cost tracking
/// - Persistent disk cache
/// - Analytics
/// - Error recovery with exponential backoff
///
/// Solves 9 Critical Problems:
/// 1. ✅ Request cancellation (adaptive debounce)
/// 2. ✅ Rate limiting
/// 3. ✅ Persistent disk cache
/// 4. ✅ Pagination
/// 5. ✅ Input validation
/// 6. ✅ Error recovery
/// 7. ✅ Mobile-adaptive debounce
/// 8. ✅ Analytics tracking
/// 9. ✅ Memory optimization
class SearchController extends GetxController {
  final SearchService _searchService = SearchService();

  // ══════════════════════════════════════════════════════════════
  // OBSERVABLE STATE
  // ══════════════════════════════════════════════════════════════

  /// Current search query
  final RxString searchQuery = ''.obs;

  /// Search results (empty list when idle)
  final RxList<SearchResult> searchResults = <SearchResult>[].obs;

  /// Loading state
  final RxBool isLoading = false.obs;

  /// Error message (if any)
  final RxString errorMessage = ''.obs;

  /// Recent searches history
  final RxList<String> recentSearches = <String>[].obs;

  final RxList<String> suggestions = <String>[].obs;
  final RxList<SearchResult> recommendedResults =
      <SearchResult>[].obs; // 🎯 For empty state "You may like"

  /// Cache statistics (for debugging)
  final RxMap<String, dynamic> cacheStats = <String, dynamic>{}.obs;

  /// Pagination state
  final RxInt currentPage = 0.obs;
  final RxBool hasMoreResults = false.obs;
  final RxBool isLoadingMore = false.obs;

  // ══════════════════════════════════════════════════════════════
  // PROBLEM 1 & 7: REQUEST CANCELLATION & MOBILE-ADAPTIVE DEBOUNCE
  // ══════════════════════════════════════════════════════════════

  /// Timer for debouncing user input (adaptive)
  Timer? _debounceTimer;

  /// Debounce duration (350ms is optimal, but adaptive for mobile)
  late Duration debounceDelay;

  /// Request cancellation token
  bool _shouldCancelRequest = false;

  /// ══════════════════════════════════════════════════════════════
  /// PROBLEM 2: RATE LIMITING
  /// ══════════════════════════════════════════════════════════════

  /// Maximum queries per minute to avoid API abuse
  static const int maxQueriesPerMinute = 30;
  int _queryCount = 0;
  DateTime _queryWindowStart = DateTime.now();

  /// Cost tracking (for optimization)
  final RxDouble estimatedMonthlyCost = 0.0.obs;
  int _firestoreReadsCount = 0;

  // ══════════════════════════════════════════════════════════════
  // PROBLEM 3: PERSISTENT DISK CACHE
  // ══════════════════════════════════════════════════════════════

  static const String _cacheStorageKey = 'search_cache_persistent';
  static const String _recentSearchesKey = 'search_recent_history';

  // ══════════════════════════════════════════════════════════════
  // PROBLEM 4: PAGINATION
  // ══════════════════════════════════════════════════════════════

  /// Results per page
  static const int resultsPerPage = 15;

  /// All results (paginated)
  List<SearchResult> _allResults = [];

  // ══════════════════════════════════════════════════════════════
  // CONSTANTS
  // ══════════════════════════════════════════════════════════════

  static const int maxRecentSearches = 10;
  static const int maxSearchQueryLength = 100;
  static const int minSearchQueryLength = 1;

  /// Initialize filters
  void _initializeFilters() {
    // Placeholder for filter initialization
    debugPrint('🎯 [Search] Filters initialized');
  }

  @override
  void onInit() {
    super.onInit();
    _initializeFilters();
    _initializeAdaptiveDebounce();
    _loadPersistentCache();
    _loadRecentSearches();
    fetchTrendingSuggestions();
  }

  // ══════════════════════════════════════════════════════════════
  // PROBLEM 7: MOBILE-ADAPTIVE DEBOUNCE
  // ══════════════════════════════════════════════════════════════

  /// Initialize adaptive debounce based on device
  void _initializeAdaptiveDebounce() {
    // Adaptive debounce for mobile vs desktop
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    debounceDelay = isMobile
        ? Duration(milliseconds: 450) // Slower for mobile (less powerful)
        : Duration(milliseconds: 350); // Faster for desktop

    debugPrint(
      '⏱️ [Search] Debounce set to ${debounceDelay.inMilliseconds}ms '
      '(Platform: ${isMobile ? "mobile" : "desktop"})',
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PROBLEM 3: PERSISTENT DISK CACHE
  // ══════════════════════════════════════════════════════════════

  /// Load persistent cache from disk
  Future<void> _loadPersistentCache() async {
    try {
      final cached = GetStorage().read(_cacheStorageKey);
      if (cached != null && cached is String) {
        final List<dynamic> decoded = jsonDecode(cached);
        _allResults = decoded.map((item) => SearchResult.fromMap(item as Map<String, dynamic>)).toList();
      }
      debugPrint('💾 [Search] Persistent cache loaded');
    } catch (e) {
      debugPrint('⚠️ [Search] Failed to load persistent cache: $e');
    }
  }

  /// Save cache to disk for offline support
  Future<void> _savePersistentCache() async {
    try {
      final cacheString = jsonEncode(
        _allResults.map((r) => r.toMap()).toList(),
      );
      debugPrint('💾 [Search] Cache saved (Size: ${cacheString.length} chars)');
      await GetStorage().write(_cacheStorageKey, cacheString);
    } catch (e) {
      debugPrint('⚠️ [Search] Failed to save cache: $e');
    }
  }

  /// Load recent searches from disk
  Future<void> _loadRecentSearches() async {
    try {
      final recent = GetStorage().read(_recentSearchesKey) as List?;
      recentSearches.value = (recent ?? []).cast<String>();
      debugPrint('📝 [Search] Recent searches loaded');
    } catch (e) {
      debugPrint('⚠️ [Search] Failed to load recent searches: $e');
    }
  }

  /// Save recent searches to disk
  Future<void> _saveRecentSearches() async {
    try {
      await GetStorage().write(_recentSearchesKey, recentSearches.toList());
      debugPrint('📝 [Search] Recent searches saved');
    } catch (e) {
      debugPrint('⚠️ [Search] Failed to save recent searches: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // PROBLEM 5: INPUT VALIDATION & SANITIZATION
  // ══════════════════════════════════════════════════════════════

  /// Validate and sanitize search query
  ///
  /// Returns: (isValid, sanitizedQuery, errorMessage)
  (bool, String, String) _validateQuery(String query) {
    final trimmed = query.trim();

    // Empty check
    if (trimmed.isEmpty) {
      return (false, '', 'Query cannot be empty');
    }

    // Length validation
    if (trimmed.length < minSearchQueryLength) {
      return (
        false,
        '',
        'Query must be at least $minSearchQueryLength character',
      );
    }

    if (trimmed.length > maxSearchQueryLength) {
      return (
        false,
        '',
        'Query cannot exceed $maxSearchQueryLength characters',
      );
    }

    // Sanitize: Remove special characters, extra spaces
    final sanitized = trimmed
        .replaceAll(RegExp(r"""[<>"']"""), '') // Remove quotes/brackets
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .toLowerCase();

    // Prevent SQL injection / NoSQL injection patterns
    if (_hasInjectionPatterns(sanitized)) {
      return (
        false,
        '',
        'Invalid characters detected. Please use simple text only.',
      );
    }

    return (true, sanitized, '');
  }

  /// Check for injection patterns
  bool _hasInjectionPatterns(String query) {
    final injectionPatterns = [
      r"""[';"]""", // Quotes (SQL)
      r'\$where', // MongoDB
      r'\.constructor', // Prototype pollution
      r'__proto__', // Prototype pollution
      r'eval\(', // Code execution
    ];

    for (final pattern in injectionPatterns) {
      if (RegExp(pattern).hasMatch(query)) {
        return true;
      }
    }
    return false;
  }

  // ══════════════════════════════════════════════════════════════
  // PROBLEM 2: RATE LIMITING
  // ══════════════════════════════════════════════════════════════

  /// Check if query limit exceeded
  bool _isRateLimitExceeded() {
    final now = DateTime.now();
    final secondsSinceWindowStart = now.difference(_queryWindowStart).inSeconds;

    // Reset window if minute has passed
    if (secondsSinceWindowStart > 60) {
      _queryCount = 0;
      _queryWindowStart = now;
      return false;
    }

    // Check if limit exceeded
    if (_queryCount >= maxQueriesPerMinute) {
      debugPrint(
        '⚠️ [Search] Rate limit exceeded! '
        '($_queryCount/$maxQueriesPerMinute queries in last $secondsSinceWindowStart seconds)',
      );
      return true;
    }

    return false;
  }

  /// Track query for rate limiting & cost
  void _recordQuery() {
    _queryCount++;
    _firestoreReadsCount++;

    // Update cost estimate ($0.06 per 100K reads)
    estimatedMonthlyCost.value = (_firestoreReadsCount * 0.06) / 100000;

    debugPrint(
      '💰 [Search] Query recorded ($_queryCount/min) | '
      'Est. cost: \$${estimatedMonthlyCost.value.toStringAsFixed(4)}/month',
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PROBLEM 8: ANALYTICS
  // ══════════════════════════════════════════════════════════════

  /// Track search to Firebase Analytics
  Future<void> _trackSearchAnalytics(
    String query,
    int resultCount,
    int latencyMs,
    bool wasCached,
    String? error,
  ) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'search_executed',
        parameters: {
          'query': query,
          'results_count': resultCount,
          'latency_ms': latencyMs,
          'was_cached': wasCached
              ? 1
              : 0, // 💡 Problem 8: Must be num or string
          'error': error ?? 'none',
          'query_timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint(
        '📊 [Search] Analytics tracked: "$query" ($resultCount results)',
      );
    } catch (e) {
      debugPrint('⚠️ [Search] Failed to track analytics: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // PROBLEM 6: ERROR RECOVERY WITH EXPONENTIAL BACKOFF
  // ══════════════════════════════════════════════════════════════

  /// Retry failed query with exponential backoff
  Future<List<SearchResult>> _retryWithBackoff(
    Future<List<SearchResult>> Function() queryFn, {
    int maxRetries = 3,
    int initialDelayMs = 100,
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await queryFn();
      } catch (e) {
        if (i == maxRetries - 1) {
          debugPrint('❌ [Search] Query failed after $maxRetries retries');
          rethrow;
        }

        // Exponential backoff: 100ms, 200ms, 400ms
        final backoffDelay = initialDelayMs * (1 << i);
        debugPrint(
          '🔄 [Search] Retry ${i + 1}/$maxRetries after ${backoffDelay}ms',
        );

        await Future.delayed(Duration(milliseconds: backoffDelay));
      }
    }

    return [];
  }

  // ══════════════════════════════════════════════════════════════
  // PROBLEM 1: REQUEST CANCELLATION (ADAPTIVE DEBOUNCE)
  // ══════════════════════════════════════════════════════════════

  /// 🔑 MAIN ENTRY POINT: Called when user types
  ///
  /// This method demonstrates the debouncing optimization:
  /// - Without debounce: 10-15 queries per typing
  /// - With debounce: 1 query per search
  void onSearchChanged(String query) {
    // Validate input
    final (isValid, sanitized, errorMsg) = _validateQuery(query);
    if (!isValid && query.isNotEmpty) {
      errorMessage.value = errorMsg;
      debugPrint('⚠️ [Search] Validation error: $errorMsg');
      return;
    }

    searchQuery.value = query;

    // Cancel previous timer if still active (Problem 1: Request Cancellation)
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
      _shouldCancelRequest = true;
      debugPrint('⏰ [Search] Previous debounce cancelled');
    }

    // If query is empty, clear results and stop
    if (query.isEmpty) {
      _clearResults();
      return;
    }

    // Start new debounce timer with adaptive delay
    debugPrint(
      '⏳ [Search] Debounce started for: "$sanitized" '
      '(${debounceDelay.inMilliseconds}ms)',
    );
    _shouldCancelRequest = false;

    _debounceTimer = Timer(debounceDelay, () {
      // Check if request was cancelled
      if (_shouldCancelRequest) {
        debugPrint('❌ [Search] Request cancelled before execution');
        return;
      }

      _executeSearch(sanitized);
    });
  }

  /// Execute the actual search query (called after debounce)
  Future<void> _executeSearch(String query) async {
    if (query.isEmpty) return;

    final normalized = query.toLowerCase().trim();
    debugPrint('🔍 [Search] Executing search for: "$normalized"');

    // Check rate limit (Problem 2)
    if (_isRateLimitExceeded()) {
      errorMessage.value =
          'Too many searches. Please slow down and try again in a moment.';
      Get.snackbar(
        'Rate Limited',
        'Please wait a moment before searching again',
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 3),
      );
      return;
    }

    // Show loading state only if not cached
    if (!_searchService.isCached(normalized)) {
      isLoading.value = true;
    }

    errorMessage.value = '';
    currentPage.value = 0;
    _allResults = [];

    final stopwatch = Stopwatch()..start();

    try {
      // Execute search with retry logic (Problem 6)
      final results = await _retryWithBackoff(
        () => _searchService.search(normalized),
        maxRetries: 3,
        initialDelayMs: 100,
      );

      stopwatch.stop();

      // Update UI with results
      _allResults = results;
      _savePersistentCache(); // Save results to persistent disk cache
      _loadPage(0); // Load first page

      isLoading.value = false;

      // Add to recent searches (Problem 3: Persistent)
      _addToRecentSearches(normalized);

      // Update cache stats for debugging
      cacheStats.value = _searchService.getCacheStats();

      // Track to analytics (Problem 8)
      _trackSearchAnalytics(
        normalized,
        results.length,
        stopwatch.elapsedMilliseconds,
        _searchService.isCached(normalized),
        null,
      );

      // Record for rate limiting & cost (Problem 2)
      _recordQuery();

      if (results.isEmpty) {
        debugPrint('⚠️ [Search] No results found for: "$normalized"');
        errorMessage.value = 'No results found for "$normalized"';
      } else {
        debugPrint('✅ [Search] Found ${results.length} results');
      }
    } catch (e) {
      stopwatch.stop();

      isLoading.value = false;
      errorMessage.value = 'Search failed. Please try again.';

      // Track error to analytics
      _trackSearchAnalytics(
        normalized,
        0,
        stopwatch.elapsedMilliseconds,
        false,
        e.toString(),
      );

      debugPrint('❌ [Search] Error: $e');
    }
  }

  /// Add query to recent searches (with deduplication)
  void _addToRecentSearches(String query) {
    // Remove if already exists (to avoid duplicates)
    recentSearches.removeWhere((q) => q.toLowerCase() == query.toLowerCase());

    // Add to front
    recentSearches.insert(0, query);

    // Keep only max items
    if (recentSearches.length > maxRecentSearches) {
      recentSearches.removeRange(maxRecentSearches, recentSearches.length);
    }

    // Save to disk (Problem 3: Persistent)
    _saveRecentSearches();

    debugPrint('📝 [Search] Recent searches: ${recentSearches.join(", ")}');
  }

  /// Clear current search results
  void _clearResults() {
    searchResults.clear();
    _allResults.clear();
    errorMessage.value = '';
    isLoading.value = false;
    searchQuery.value = '';
    currentPage.value = 0;
    hasMoreResults.value = false;
    debugPrint('🧹 [Search] Results cleared');
  }

  // ══════════════════════════════════════════════════════════════
  // PROBLEM 4: PAGINATION
  // ══════════════════════════════════════════════════════════════

  /// Load specific page of results
  void _loadPage(int page) {
    final startIndex = page * resultsPerPage;
    final endIndex = (page + 1) * resultsPerPage;

    if (startIndex >= _allResults.length) {
      searchResults.clear();
      hasMoreResults.value = false;
      return;
    }

    final endIndexCapped = endIndex > _allResults.length
        ? _allResults.length
        : endIndex;

    searchResults.value = _allResults.sublist(startIndex, endIndexCapped);
    hasMoreResults.value = endIndexCapped < _allResults.length;

    debugPrint(
      '📄 [Search] Loaded page $page '
      '(${searchResults.length} results shown, more: ${hasMoreResults.value})',
    );
  }

  /// Load next page (for infinite scroll)
  Future<void> loadNextPage() async {
    if (!hasMoreResults.value || isLoadingMore.value) {
      return;
    }

    isLoadingMore.value = true;
    await Future.delayed(Duration(milliseconds: 300)); // Simulate load time

    _loadPage(currentPage.value + 1);
    currentPage.value++;

    isLoadingMore.value = false;
    debugPrint('📄 [Search] Next page loaded');
  }

  /// Clear current search (reset to initial state)
  void clearSearch() {
    _debounceTimer?.cancel();
    _shouldCancelRequest = true;
    _clearResults();
    debugPrint('🧹 [Search] Search cleared');
  }

  /// Quick search from recent searches
  void searchFromRecent(String query) {
    debugPrint('⚡ [Search] Quick search from recent: "$query"');
    searchQuery.value = query;
    _executeSearch(query);
  }

  /// Clear recent searches history
  void clearRecentSearches() {
    recentSearches.clear();
    _saveRecentSearches();
    debugPrint('🗑️ [Search] Recent searches cleared');
  }

  /// Load trending suggestions (Problem 9: Resource Cleanup)
  Future<void> fetchTrendingSuggestions() async {
    try {
      debugPrint('📈 [Search] Loading trending suggestions...');
      final trending = await _searchService.getTrendingSuggestions();
      suggestions.value = trending;

      // Also fetch some recommended videos for the empty state
      final recommended = await _searchService.getRecommended();
      recommendedResults.value = recommended;
    } catch (e) {
      debugPrint('⚠️ [Search] Failed to load trending: $e');
    }
  }

  /// Warmup cache with trending searches (call on app init)
  Future<void> warmupCache() async {
    await _searchService.warmupCache([
      'flutter',
      'firebase',
      'web development',
      'mobile apps',
      'tutorial',
    ]);
  }

  /// Clear service cache
  void clearServiceCache() {
    _searchService.clearCache();
    cacheStats.value = {};
    debugPrint('🗑️ [Search] Service cache cleared');
  }

  /// Get current cache statistics
  Map<String, dynamic> getCacheStats() {
    return _searchService.getCacheStats();
  }

  // ══════════════════════════════════════════════════════════════
  // PROBLEM 9: MEMORY OPTIMIZATION & RESOURCE CLEANUP
  // ══════════════════════════════════════════════════════════════

  /// Get memory usage statistics
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

  /// Navigate to appropriate screen when user taps a result
  Future<void> onResultTapped(SearchResult result) async {
    debugPrint(
      '👆 [Search] User tapped: ${result.title} (Type: ${result.type}, ID: ${result.id})',
    );

    try {
      // ⏳ [LOADING STATE]
      Get.dialog(
        const Center(child: CircularProgressIndicator(color: Colors.white)),
        barrierDismissible: false,
      );

      final String collection = result.type == ResultType.video
          ? 'videos'
          : (result.type == ResultType.channel ? 'channels' : 'playlists');

      final doc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(result.id)
          .get();

      if (Get.isDialogOpen ?? false) Get.back(); // Remove loading dialog

      if (!doc.exists) {
        String typeName = result.type.toString().split('.').last;
        Get.snackbar(
          'Error',
          '${typeName.capitalizeFirst} not found',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Track tap to analytics
      await FirebaseAnalytics.instance.logEvent(
        name: 'search_result_tapped',
        parameters: {
          'result_id': result.id,
          'result_title': result.title,
          'result_type': result.type.toString(),
        },
      );

      // 🧭 NAVIGATE BASED ON TYPE
      switch (result.type) {
        case ResultType.video:
          final video = Video.fromDocumentSnapshot(doc);
          Get.toNamed('/watch?v=${video.id}', arguments: {"video": video});
          break;
        case ResultType.channel:
          final channel = Channel.fromDocumentSnapshot(doc);
          Get.toNamed(channel.channelRoute, arguments: {"channel": channel});
          break;
        case ResultType.playlist:
          final playlist = PlaylistModel.fromDocumentSnapshot(doc);
          // Check if HomeController is available (we're in home screen context)
          if (Get.isRegistered<HomeController>()) {
            final homeController = Get.find<HomeController>();
            homeController.navigateToPlaylistDetail(playlist);
          } else {
            // Navigate to home first, then show playlist detail
            Get.toNamed('/', arguments: {'openPlaylist': playlist});
          }
          break;
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      debugPrint('❌ [Search] Navigation failed: $e');
      Get.snackbar('Navigation Error', 'Could not open result: $e');
    }
  }

  /// Dispose resources (Problem 9)
  /// Called when user leaves search page
  @override
  void onClose() {
    _debounceTimer?.cancel();
    _searchService.clearCache(); // Optional: aggressive memory cleanup
    _allResults.clear();
    searchResults.clear();
    debugPrint('🧹 [Search] Controller disposed, resources cleaned up');
    super.onClose();
  }
}





