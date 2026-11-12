import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/data/services/search_service.dart';
import 'package:truthworld/features/search/presentation/controllers/search_controller.dart';
import '../../test_helpers/mock_firebase.dart';

class _FakeSearchService extends Fake implements SearchService {
  @override
  bool isCached(String query) => false;

  @override
  Future<List<SearchResult>> search(
    String query, {
    AiSearchIntent? intent,
    String? filter,
    int limit = 20,
  }) async => [];

  @override
  Future<List<String>> getTrendingSuggestions() async => [];

  @override
  Future<List<SearchResult>> getRecommendedForFilter(
    String filter, {
    Set<String>? watchedVideoIds,
  }) async => [];

  @override
  void clearCache() {}

  @override
  Map<String, dynamic> getCacheStats() => {'size': 0};
}

class _FakeSearchTrendingManager extends Fake implements SearchTrendingManager {
  @override
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subscribeToTrending({
    required void Function(List<TrendingItem> items) onTrendingLoaded,
    required void Function(bool isLoading) onLoadingChanged,
  }) {
    onLoadingChanged(false);
    return null;
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await GetStorage.init();
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    Get.put<AuthService>(AuthService(), permanent: true);
  });

  tearDown(() {
    Get.delete<SearchController>(force: true);
    Get.reset();
  });

  SearchResult createTestResult({
    required String id,
    required String title,
    ResultType type = ResultType.video,
  }) {
    return SearchResult(
      id: id,
      title: title,
      thumbnail: 'https://example.com/thumb.jpg',
      views: 100,
      channelName: 'Test Channel',
      channelImage: 'https://example.com/avatar.jpg',
      createdAt: Timestamp.now(),
      type: type,
    );
  }

  group('SearchRateLimiter Tests', () {
    test('tracks and limits query rate per window', () {
      final limiter = SearchRateLimiter(maxQueriesPerMinute: 3);
      expect(limiter.isRateLimitExceeded(), isFalse);

      limiter.recordQuery();
      limiter.recordQuery();
      expect(limiter.queryCount, equals(2));
      expect(limiter.isRateLimitExceeded(), isFalse);

      limiter.recordQuery();
      expect(limiter.queryCount, equals(3));
      expect(limiter.isRateLimitExceeded(), isTrue);

      limiter.reset();
      expect(limiter.queryCount, equals(0));
      expect(limiter.isRateLimitExceeded(), isFalse);
    });
  });

  group('SearchFilterHelper Tests', () {
    test('validates and sanitizes queries with trailing speech punctuation', () {
      final (valid1, sanitized1, err1) = SearchFilterHelper.validateQuery('  Flutter Development...!?  ');
      expect(valid1, isTrue);
      expect(sanitized1, equals('flutter development'));
      expect(err1, isEmpty);

      final (validEmpty, _, errEmpty) = SearchFilterHelper.validateQuery('   ');
      expect(validEmpty, isFalse);
      expect(errEmpty, equals('Query cannot be empty'));
    });

    test('applies category and status filters accurately', () {
      final v1 = createTestResult(id: '1', title: 'Flutter Live Stream');
      final v2 = createTestResult(id: '2', title: 'Dart Tutorial');
      final c1 = createTestResult(id: '3', title: 'Flutter Channel', type: ResultType.channel);
      final t1 = createTestResult(id: '4', title: 'Tech Topic', type: ResultType.topic);
      final p1 = createTestResult(id: '5', title: 'Full Playlist', type: ResultType.playlist);

      final all = <SearchResult>[v1, v2, c1, t1, p1];

      expect(SearchFilterHelper.applyFilter(results: all, filter: 'Videos', watchedVideoIds: {}), equals([v1, v2]));
      expect(SearchFilterHelper.applyFilter(results: all, filter: 'Channels', watchedVideoIds: {}), equals([c1]));
      expect(SearchFilterHelper.applyFilter(results: all, filter: 'Topics', watchedVideoIds: {}), equals([t1]));
      expect(SearchFilterHelper.applyFilter(results: all, filter: 'Playlists', watchedVideoIds: {}), equals([p1]));
      expect(SearchFilterHelper.applyFilter(results: all, filter: 'Live', watchedVideoIds: {}), equals([v1, c1, t1, p1]));
      expect(SearchFilterHelper.applyFilter(results: all, filter: 'Watched', watchedVideoIds: {'1'}), equals([v1, c1, t1, p1]));
      expect(SearchFilterHelper.applyFilter(results: all, filter: 'Unwatched', watchedVideoIds: {'1'}), equals([v2, c1, t1, p1]));
    });
  });

  group('SearchPaginationManager Tests', () {
    test('returns exact slices and computes hasMore', () {
      final items = List<SearchResult>.generate(
        35,
        (i) => createTestResult(id: '$i', title: 'Item $i'),
      );

      final (page0, hasMore0) = SearchPaginationManager.getPageSlice(
        allItems: items,
        page: 0,
      );
      expect(page0.length, equals(15));
      expect(page0.first.id, equals('0'));
      expect(hasMore0, isTrue);

      final (page1, hasMore1) = SearchPaginationManager.getPageSlice(
        allItems: items,
        page: 1,
      );
      expect(page1.length, equals(15));
      expect(page1.first.id, equals('15'));
      expect(hasMore1, isTrue);

      final (page2, hasMore2) = SearchPaginationManager.getPageSlice(
        allItems: items,
        page: 2,
      );
      expect(page2.length, equals(5));
      expect(page2.first.id, equals('30'));
      expect(hasMore2, isFalse);
    });
  });

  group('SearchTrendingManager Tests', () {
    test('formats search/view volumes into compact notation', () {
      expect(SearchTrendingManager.formatVolume(500), equals('500'));
      expect(SearchTrendingManager.formatVolume(1500), equals('1.5k'));
      expect(SearchTrendingManager.formatVolume(24300), equals('24.3k'));
      expect(SearchTrendingManager.formatVolume(1000000), equals('1.0M'));
      expect(SearchTrendingManager.formatVolume(3450000), equals('3.5M'));
    });

    test('filters trending items by active chip', () {
      final items = [
        TrendingItem(id: '1', rank: 1, title: 'T1', category: 'video', volume: 100),
        TrendingItem(id: '2', rank: 2, title: 'T2', category: 'topic', volume: 200),
        TrendingItem(id: '3', rank: 3, title: 'T3', category: 'channel', volume: 300),
        TrendingItem(id: '4', rank: 4, title: 'T4', category: 'playlist', volume: 400),
      ];

      expect(SearchTrendingManager.filterTrending(items, 'Videos').length, equals(1));
      expect(SearchTrendingManager.filterTrending(items, 'Topics').length, equals(1));
      expect(SearchTrendingManager.filterTrending(items, 'Channels').length, equals(1));
      expect(SearchTrendingManager.filterTrending(items, 'Playlists').length, equals(1));
      expect(SearchTrendingManager.filterTrending(items, 'All').length, equals(4));
    });
  });

  group('SearchHistoryCacheManager Tests', () {
    test('adds query to recent history with deduplication and moves to front', () {
      final manager = SearchHistoryCacheManager();
      var history = ['flutter', 'dart', 'firebase'];

      history = manager.addQueryToRecent(
        currentList: history,
        query: 'dart',
        maxRecent: 5,
      );
      expect(history, equals(['dart', 'flutter', 'firebase']));

      history = manager.addQueryToRecent(
        currentList: history,
        query: 'state management',
        maxRecent: 3,
      );
      expect(history, equals(['state management', 'dart', 'flutter']));
    });
  });

  group('SearchController Coordinator Tests', () {
    test('initializes observable states cleanly', () {
      final controller = Get.put(SearchController(
        searchService: _FakeSearchService(),
        trendingManager: _FakeSearchTrendingManager(),
      ));

      expect(controller.searchQuery.value, isEmpty);
      expect(controller.searchResults, isEmpty);
      expect(controller.selectedFilter.value, equals('All'));
      expect(controller.currentPage.value, equals(0));
      expect(controller.showSuggestions.value, isFalse);
    });

    test('onSearchChanged updates query and displays suggestions without triggering executed search', () {
      final controller = Get.put(SearchController(
        searchService: _FakeSearchService(),
        trendingManager: _FakeSearchTrendingManager(),
      ));

      expect(controller.hasExecutedSearch.value, isFalse);
      expect(controller.executedQuery.value, isEmpty);

      controller.onSearchChanged('flutter tutorial');
      expect(controller.searchQuery.value, equals('flutter tutorial'));
      expect(controller.showSuggestions.value, isTrue);
      expect(controller.hasExecutedSearch.value, isFalse);

      controller.clearSearch();
      expect(controller.searchQuery.value, isEmpty);
      expect(controller.showSuggestions.value, isFalse);
      expect(controller.searchResults, isEmpty);
      expect(controller.hasExecutedSearch.value, isFalse);
      expect(controller.executedQuery.value, isEmpty);
    });

    test('decouples live typing from executed search state', () async {
      final controller = Get.put(SearchController(
        searchService: _FakeSearchService(),
        trendingManager: _FakeSearchTrendingManager(),
      ));

      // User types 'j'
      controller.onSearchChanged('j');
      expect(controller.hasExecutedSearch.value, isFalse);

      // User submits 'j'
      await controller.performSearch('j');
      expect(controller.hasExecutedSearch.value, isTrue);
      expect(controller.executedQuery.value, equals('j'));
      expect(controller.showSuggestions.value, isFalse);

      // User starts typing again to change to 'ji'
      controller.onSearchChanged('ji');
      expect(controller.hasExecutedSearch.value, isFalse);
      expect(controller.showSuggestions.value, isTrue);
    });

    test('setFilter updates filter and resets pagination', () {
      final controller = Get.put(SearchController(
        searchService: _FakeSearchService(),
        trendingManager: _FakeSearchTrendingManager(),
      ));

      controller.setFilter('Videos');
      expect(controller.selectedFilter.value, equals('Videos'));

      controller.setFilter('Channels');
      expect(controller.selectedFilter.value, equals('Channels'));
    });
  });
}
