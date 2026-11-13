import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:truthworld/features/home/data/datasources/edge_feed_remote_data_source.dart';
import 'package:truthworld/features/home/data/services/feed_cache_manager.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class FakeGetStorage extends Fake implements GetStorage {
  final Map<String, dynamic> _store = {};

  @override
  T? read<T>(String key) => _store[key] as T?;

  @override
  Future<void> write(String key, dynamic value) async {
    _store[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EdgeFeedRemoteDataSource', () {
    late FakeGetStorage fakeStorage;
    late FeedCacheManager cacheManager;

    setUp(() {
      fakeStorage = FakeGetStorage();
      cacheManager = FeedCacheManager(fakeStorage);
    });

    test('fetches feed via 200 OK, returns videos, and extracts ETag', () async {
      final sampleVideoMap = {
        'id': 'vid_test_1',
        'title': 'Test Edge Video',
        'category': 'science',
        'status': 'published',
        'visibility': 'public',
        'videoUrl': 'https://storage.googleapis.com/videos/test.mp4',
        'moderationStatus': 'approved',
        'createdAt': DateTime.now().toIso8601String(),
        'views': 100,
        'likes': 10,
        'commentCount': 2,
      };

      final client = MockClient((request) async {
        expect(request.url.path, '/api/feed');
        expect(request.headers['Authorization'], isNull);

        return http.Response(
          jsonEncode({
            'feed': [sampleVideoMap],
            'count': 1,
            'nextCursor': 'cursor_abc123',
            'hasMore': true,
          }),
          200,
          headers: {'etag': 'W/"test_etag_123"'},
        );
      });

      final dataSource = EdgeFeedRemoteDataSource(
        client: client,
        cacheManager: cacheManager,
        baseUrl: 'https://www.truthworld.in',
      );

      final res = await dataSource.fetchFeed(category: 'science', limit: 10);

      expect(res.videos.length, 1);
      expect(res.videos.first.id, 'vid_test_1');
      expect(res.nextCursor, 'cursor_abc123');
      expect(res.hasMore, true);
      expect(res.isNotModified, false);
      expect(res.eTag, 'W/"test_etag_123"');
    });

    test('handles 304 Not Modified by reusing local cached videos', () async {
      final cacheKey = FeedCacheManager.cacheKeyForCategory('technology');
      final localVideo = Video.fromMap({
        'id': 'vid_cached_local',
        'title': 'Locally Cached Video',
        'category': 'technology',
        'status': 'published',
        'visibility': 'public',
        'videoUrl': 'https://storage.googleapis.com/videos/local.mp4',
        'moderationStatus': 'approved',
        'createdAt': DateTime.now().toIso8601String(),
        'views': 50,
      });

      cacheManager.saveFeedToCache(
        cacheKey,
        [localVideo],
        eTag: 'W/"cached_etag_456"',
        nextCursor: 'next_local_cursor',
      );

      final client = MockClient((request) async {
        expect(request.headers['If-None-Match'], 'W/"cached_etag_456"');
        return http.Response('', 304, headers: {'etag': 'W/"cached_etag_456"'});
      });

      final dataSource = EdgeFeedRemoteDataSource(
        client: client,
        cacheManager: cacheManager,
        baseUrl: 'https://www.truthworld.in',
      );

      final res = await dataSource.fetchFeed(category: 'technology');

      expect(res.isNotModified, true);
      expect(res.videos.length, 1);
      expect(res.videos.first.id, 'vid_cached_local');
      expect(res.nextCursor, 'next_local_cursor');
    });

    test('does not send If-None-Match when local cached body is empty', () async {
      final client = MockClient((request) async {
        expect(request.headers['If-None-Match'], isNull);
        return http.Response(
          jsonEncode({'feed': [], 'count': 0, 'hasMore': false}),
          200,
        );
      });

      final dataSource = EdgeFeedRemoteDataSource(
        client: client,
        cacheManager: cacheManager,
        baseUrl: 'https://www.truthworld.in',
      );

      final res = await dataSource.fetchFeed(category: 'non_cached_cat');
      expect(res.videos, isEmpty);
    });

    test('throws EdgeFeedException on 500 error allowing caller to fall back', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final dataSource = EdgeFeedRemoteDataSource(
        client: client,
        cacheManager: cacheManager,
        baseUrl: 'https://www.truthworld.in',
      );

      expect(
        () => dataSource.fetchFeed(),
        throwsA(isA<EdgeFeedException>()),
      );
    });
  });
}
