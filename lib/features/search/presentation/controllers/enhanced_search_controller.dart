import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/features/search/data/services/search_service.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/core/services/logger_service.dart';

// ════════════════════════════════════════════════════════════════════════════════
// SEARCH FILTER ENUMS (Industry Standard)
// ════════════════════════════════════════════════════════════════════════════════

enum SearchType { all, videos, channels, playlists }

enum SortBy {
  relevance,
  viewCount,
  uploadDate,
  duration, // Only for videos
  channelName, // Only for channels
  videoCount, // Only for playlists
}

enum UploadDate {
  anytime,
  lastHour,
  today,
  thisWeek,
  thisMonth,
  thisYear,
}

enum DurationFilter {
  any,
  lessThan4Min,
  between4and20Min,
  moreThan20Min,
}

enum VideoQuality {
  any,
  hd,
  fourK,
}

// ════════════════════════════════════════════════════════════════════════════════
// SEARCH STATE MODEL
// ════════════════════════════════════════════════════════════════════════════════

class SearchFilters {
  SearchType searchType;
  SortBy sortBy;
  UploadDate uploadDate;
  DurationFilter duration;
  VideoQuality quality;
  int minViews;
  bool verifiedOnly;

  SearchFilters({
    this.searchType = SearchType.all,
    this.sortBy = SortBy.relevance,
    this.uploadDate = UploadDate.anytime,
    this.duration = DurationFilter.any,
    this.quality = VideoQuality.any,
    this.minViews = 0,
    this.verifiedOnly = false,
  });

  SearchFilters copyWith({
    SearchType? searchType,
    SortBy? sortBy,
    UploadDate? uploadDate,
    DurationFilter? duration,
    VideoQuality? quality,
    int? minViews,
    bool? verifiedOnly,
  }) {
    return SearchFilters(
      searchType: searchType ?? this.searchType,
      sortBy: sortBy ?? this.sortBy,
      uploadDate: uploadDate ?? this.uploadDate,
      duration: duration ?? this.duration,
      quality: quality ?? this.quality,
      minViews: minViews ?? this.minViews,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// ENHANCED SEARCH CONTROLLER (Industry Standard)
// ════════════════════════════════════════════════════════════════════════════════

class EnhancedSearchController extends GetxController {
  final SearchService _searchService = SearchService();
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GetStorage _storage = GetStorage();
  static const String _storageKey = 'recent_searches';

  // ════════════════════════════════════════ OBSERVABLE STATE ════════════════════════════════════

  // Search query
  final RxString searchQuery = ''.obs;

  // Results (separated by type for efficient filtering)
  final RxList<SearchResult> allResults = <SearchResult>[].obs;
  final RxList<SearchResult> videoResults = <SearchResult>[].obs;
  final RxList<SearchResult> channelResults = <SearchResult>[].obs;
  final RxList<SearchResult> playlistResults = <SearchResult>[].obs;

  // Current displayed results based on filters
  final RxList<SearchResult> displayedResults = <SearchResult>[].obs;

  // Filters
  final Rx<SearchFilters> filters = SearchFilters().obs;

  // Loading states
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxString errorMessage = ''.obs;

  // Pagination
  final RxInt currentPage = 0.obs;
  final RxBool hasMoreResults = false.obs;
  static const int resultsPerPage = 20;

  // Recent & suggestions
  final RxList<String> recentSearches = <String>[].obs;
  final RxList<SearchResult> recommendedResults = <SearchResult>[].obs;

  // Filter visibility
  final RxBool showFilters = false.obs;

  // Result counts
  final RxInt totalVideoCount = 0.obs;
  final RxInt totalChannelCount = 0.obs;
  final RxInt totalPlaylistCount = 0.obs;

  // Search analytics
  final RxInt estimatedReadCount = 0.obs;
  final RxDouble estimatedCost = 0.0.obs;

  // ════════════════════════════════════════ LIFECYCLE ════════════════════════════════════

  @override
  void onInit() {
    super.onInit();
    _loadRecentSearches();
    fetchTrendingContent();
    _setupAnalytics();
  }

  @override
  void onClose() {
    searchQuery.value = '';
    super.onClose();
  }

  // ════════════════════════════════════════ CORE SEARCH METHODS ════════════════════════════════════

  /// Execute search with current filters
  Future<void> performSearch(String query) async {
    if (query.isEmpty) {
      clearSearch();
      return;
    }

    if (query.length > 150) {
      errorMessage.value = 'Search query too long (max 150 characters)';
      return;
    }

    searchQuery.value = query;
    await _executeSearch(query);
  }

  Future<void> _executeSearch(String query) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      currentPage.value = 0;

      // Perform searches in parallel
      final results = await Future.wait([
        _searchService.searchVideos(query),
        _searchService.searchChannels(query),
        _searchService.searchPlaylists(query),
      ]);

      videoResults.value = results[0];
      channelResults.value = results[1];
      playlistResults.value = results[2];

      // Merge all results
      allResults.value = [...videoResults, ...channelResults, ...playlistResults];

      // Update counts
      totalVideoCount.value = videoResults.length;
      totalChannelCount.value = channelResults.length;
      totalPlaylistCount.value = playlistResults.length;

      // Track search analytics
      await _analytics.logSearch(searchTerm: query);
      _addToRecentSearches(query);

      // Apply filters and pagination
      _applyFiltersAndSort();
      _loadPage(0);

      // Update cost estimate
      _updateCostEstimate();
    } catch (e) {
      errorMessage.value = 'Search failed: $e';
      logger.error('Search error', error: e, tag: 'SEARCH');
    } finally {
      isLoading.value = false;
    }
  }

  /// Apply current filters and sort results
  void _applyFiltersAndSort() {
    List<SearchResult> filtered = [];

    switch (filters.value.searchType) {
      case SearchType.videos:
        filtered = _filterVideos(videoResults);
        break;
      case SearchType.channels:
        filtered = channelResults;
        break;
      case SearchType.playlists:
        filtered = playlistResults;
        break;
      case SearchType.all:
        filtered = [
          ..._filterVideos(videoResults),
          ...channelResults,
          ...playlistResults,
        ];
        break;
    }

    // Apply sorting
    filtered = _sortResults(filtered);

    allResults.value = filtered;
    hasMoreResults.value = filtered.length > resultsPerPage;
  }

  /// Filter videos by selected criteria (cost-effective)
  List<SearchResult> _filterVideos(List<SearchResult> videos) {
    return videos.where((video) {
      // Min views filter
      if (filters.value.minViews > 0 && video.viewCount < filters.value.minViews) {
        return false;
      }

      // Upload date filter (cost-effective: done in-memory)
      if (!_isWithinDateRange(video.uploadedAt)) {
        return false;
      }

      // Duration filter (only for videos)
      if (!_isDurationInRange(video.duration ?? 0)) {
        return false;
      }

      // Quality filter (if available)
      if (filters.value.quality != VideoQuality.any) {
        if (!_hasRequiredQuality(video.quality)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Sort results by selected criteria
  List<SearchResult> _sortResults(List<SearchResult> results) {
    final sorted = List<SearchResult>.from(results);

    switch (filters.value.sortBy) {
      case SortBy.relevance:
        // Already sorted by Firestore relevance
        break;
      case SortBy.viewCount:
        sorted.sort((a, b) => b.viewCount.compareTo(a.viewCount));
        break;
      case SortBy.uploadDate:
        sorted.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        break;
      case SortBy.duration:
        sorted.sort((a, b) => (b.duration ?? 0).compareTo(a.duration ?? 0));
        break;
      case SortBy.channelName:
        sorted.sort((a, b) => a.channelName.compareTo(b.channelName));
        break;
      case SortBy.videoCount:
        sorted.sort((a, b) => (b.videoCount ?? 0).compareTo(a.videoCount ?? 0));
        break;
    }

    return sorted;
  }

  /// Check if date is within selected range
  bool _isWithinDateRange(DateTime uploadedAt) {
    final now = DateTime.now();

    switch (filters.value.uploadDate) {
      case UploadDate.anytime:
        return true;
      case UploadDate.lastHour:
        return now.difference(uploadedAt).inHours < 1;
      case UploadDate.today:
        return uploadedAt.day == now.day && uploadedAt.month == now.month && uploadedAt.year == now.year;
      case UploadDate.thisWeek:
        return now.difference(uploadedAt).inDays < 7;
      case UploadDate.thisMonth:
        return uploadedAt.month == now.month && uploadedAt.year == now.year;
      case UploadDate.thisYear:
        return uploadedAt.year == now.year;
    }
  }

  /// Check if video duration is in selected range
  bool _isDurationInRange(int durationSeconds) {
    final durationMinutes = durationSeconds ~/ 60;

    switch (filters.value.duration) {
      case DurationFilter.any:
        return true;
      case DurationFilter.lessThan4Min:
        return durationMinutes < 4;
      case DurationFilter.between4and20Min:
        return durationMinutes >= 4 && durationMinutes <= 20;
      case DurationFilter.moreThan20Min:
        return durationMinutes > 20;
    }
  }

  /// Check if video has required quality
  bool _hasRequiredQuality(String? quality) {
    if (quality == null || quality.isEmpty) return false;

    final qualityLower = quality.toLowerCase();
    switch (filters.value.quality) {
      case VideoQuality.any:
        return true;
      case VideoQuality.hd:
        return qualityLower.contains('1080') || qualityLower.contains('720');
      case VideoQuality.fourK:
        return qualityLower.contains('4k') || qualityLower.contains('2160');
    }
  }

  // ════════════════════════════════════════ FILTER MANAGEMENT ════════════════════════════════════

  /// Update search type filter
  void setSearchType(SearchType type) {
    filters.value = filters.value.copyWith(searchType: type);
    currentPage.value = 0;
    _applyFiltersAndSort();
    _loadPage(0);
  }

  /// Update sort order
  void setSortBy(SortBy sort) {
    filters.value = filters.value.copyWith(sortBy: sort);
    _applyFiltersAndSort();
    _loadPage(0);
  }

  /// Update upload date filter
  void setUploadDate(UploadDate date) {
    filters.value = filters.value.copyWith(uploadDate: date);
    _applyFiltersAndSort();
    _loadPage(0);
  }

  /// Update duration filter
  void setDuration(DurationFilter duration) {
    filters.value = filters.value.copyWith(duration: duration);
    _applyFiltersAndSort();
    _loadPage(0);
  }

  /// Update quality filter
  void setQuality(VideoQuality quality) {
    filters.value = filters.value.copyWith(quality: quality);
    _applyFiltersAndSort();
    _loadPage(0);
  }

  /// Update minimum views filter
  void setMinViews(int views) {
    filters.value = filters.value.copyWith(minViews: views);
    _applyFiltersAndSort();
    _loadPage(0);
  }

  /// Toggle verified channels only
  void setVerifiedOnly(bool verified) {
    filters.value = filters.value.copyWith(verifiedOnly: verified);
    _applyFiltersAndSort();
    _loadPage(0);
  }

  /// Reset all filters to defaults
  void resetFilters() {
    filters.value = SearchFilters();
    _applyFiltersAndSort();
    _loadPage(0);
  }

  // ════════════════════════════════════════ PAGINATION ════════════════════════════════════

  /// Load specific page
  void _loadPage(int page) {
    final startIndex = page * resultsPerPage;
    final endIndex = (page + 1) * resultsPerPage;

    if (startIndex >= allResults.length) {
      displayedResults.clear();
      hasMoreResults.value = false;
      return;
    }

    final endIndexCapped = endIndex > allResults.length ? allResults.length : endIndex;
    displayedResults.value = allResults.sublist(startIndex, endIndexCapped);
    hasMoreResults.value = endIndexCapped < allResults.length;
  }

  /// Load next page
  Future<void> loadNextPage() async {
    if (!hasMoreResults.value || isLoadingMore.value) {
      return;
    }

    isLoadingMore.value = true;
    await Future.delayed(const Duration(milliseconds: 200));

    _loadPage(currentPage.value + 1);
    currentPage.value++;

    isLoadingMore.value = false;
  }

  // ════════════════════════════════════════ RECENT SEARCHES ════════════════════════════════════

  void _addToRecentSearches(String query) {
    if (query.trim().isEmpty) return;
    
    final trimmedQuery = query.trim();
    if (recentSearches.contains(trimmedQuery)) {
      recentSearches.remove(trimmedQuery);
    }
    
    recentSearches.insert(0, trimmedQuery);
    if (recentSearches.length > 15) {
      recentSearches.removeLast();
    }
    
    _saveRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final List<dynamic>? stored = _storage.read<List<dynamic>>(_storageKey);
    if (stored != null) {
      recentSearches.value = stored.cast<String>();
    } else {
      // Default suggestions if empty
      recentSearches.value = [
        'Flutter tutorial',
        'TruthWorld news',
        'Blockchain tech',
        'AI future',
      ];
    }
  }

  void _saveRecentSearches() {
    _storage.write(_storageKey, recentSearches.toList());
  }

  void clearRecentSearches() {
    recentSearches.clear();
    _saveRecentSearches();
  }

  void removeRecentSearch(String query) {
    recentSearches.remove(query);
    _saveRecentSearches();
  }

  // ════════════════════════════════════════ RECOMMENDATIONS & TRENDING ════════════════════════════════════

  Future<void> fetchTrendingContent() async {
    try {
      final videos = await _firestore
          .collection('videos')
          .where('status', isEqualTo: 'processed')
          .orderBy('viewCount', descending: true)
          .limit(10)
          .get();

      recommendedResults.value = videos.docs
          .map((doc) => SearchResult.fromFirestore(doc, type: ResultType.video))
          .toList();
    } catch (e) {
      logger.error('Error fetching trending', error: e, tag: 'TRENDING');
    }
  }

  // ════════════════════════════════════════ COST TRACKING (ENTERPRISE FEATURE) ════════════════════════════════════

  void _updateCostEstimate() {
    // Cost calculation: ~$0.0012 per read (Firestore pricing)
    final estimatedReads = (videoResults.length + channelResults.length + playlistResults.length) ~/
        20; // Approximate reads needed
    estimatedReadCount.value = estimatedReads;
    estimatedCost.value = estimatedReads * 0.0012;
  }

  // ════════════════════════════════════════ ANALYTICS ════════════════════════════════════

  void _setupAnalytics() {
    // Configure analytics for search tracking
  }

  /// Clear search and results
  void clearSearch() {
    searchQuery.value = '';
    displayedResults.clear();
    allResults.clear();
    videoResults.clear();
    channelResults.clear();
    playlistResults.clear();
    currentPage.value = 0;
    errorMessage.value = '';
  }

  /// Quick search from recent
  void searchFromRecent(String query) {
    performSearch(query);
  }
}





