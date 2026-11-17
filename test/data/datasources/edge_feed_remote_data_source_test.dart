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

    test('fetches explore feed from /api/feed/explore with diversity', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/feed/explore');
        return http.Response(
          jsonEncode({
            'feed': [
              {
                'id': 'exp_vid_1',
                'title': 'Explore Video',
                'category': 'science',
                'videoUrl': 'https://storage.googleapis.com/test.mp4',
                'moderationStatus': 'approved',
                'createdAt': DateTime.now().toIso8601String(),
              }
            ],
            'count': 1,
            'hasMore': false,
          }),
          200,
        );
      });

      final dataSource = EdgeFeedRemoteDataSource(
        client: client,
        cacheManager: cacheManager,
        baseUrl: 'https://www.truthworld.in',
      );

      final res = await dataSource.fetchExploreFeed(limit: 10);
      expect(res.videos.length, 1);
      expect(res.videos.first.id, 'exp_vid_1');
    });

    test('fetches topic feed from /api/feed?topic=science with local caching', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/feed');
        expect(request.url.queryParameters['topic'], 'science');
        return http.Response(
          jsonEncode({
            'feed': [
              {
                'id': 'topic_vid_1',
                'title': 'Quantum Physics',
                'category': 'science',
                'videoUrl': 'https://storage.googleapis.com/test.mp4',
                'moderationStatus': 'approved',
                'createdAt': DateTime.now().toIso8601String(),
              }
            ],
            'count': 1,
            'topic': 'science',
            'hasMore': false,
          }),
          200,
          headers: {'etag': 'W/"topic_etag_1"'},
        );
      });

      final dataSource = EdgeFeedRemoteDataSource(
        client: client,
        cacheManager: cacheManager,
        baseUrl: 'https://www.truthworld.in',
      );

      final res = await dataSource.fetchTopicFeed('science', limit: 12);
      expect(res.videos.length, 1);
      expect(res.videos.first.id, 'topic_vid_1');
    });

    test('fetches channel uploads from /api/feed?channelId=chan_xyz', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/feed');
        expect(request.url.queryParameters['channelId'], 'chan_xyz');
        return http.Response(
          jsonEncode({
            'feed': [
              {
                'id': 'chan_vid_1',
                'title': 'Channel Upload',
                'category': 'science',
                'videoUrl': 'https://storage.googleapis.com/test.mp4',
                'moderationStatus': 'approved',
                'createdAt': DateTime.now().toIso8601String(),
              }
            ],
            'count': 1,
            'channelId': 'chan_xyz',
            'hasMore': false,
          }),
          200,
        );
      });

      final dataSource = EdgeFeedRemoteDataSource(
        client: client,
        cacheManager: cacheManager,
        baseUrl: 'https://www.truthworld.in',
      );

      final res = await dataSource.fetchChannelFeed('chan_xyz', limit: 12);
      expect(res.videos.length, 1);
      expect(res.videos.first.id, 'chan_vid_1');
    });

    test('fetches discovery topics from /api/discovery/topics', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/discovery/topics');
        return http.Response(
          jsonEncode({
            'topics': [
              {
                'id': 't_ai',
                'slug': 'ai',
                'name': 'AI',
                'category': 'Technology',
                'trendingScore': 99.0,
                'videoCount': 100,
                'status': 'active',
              }
            ],
            'count': 1,
          }),
          200,
        );
      });

      final dataSource = EdgeFeedRemoteDataSource(
        client: client,
        cacheManager: cacheManager,
        baseUrl: 'https://www.truthworld.in',
      );

      final topics = await dataSource.fetchDiscoveryTopics();
      expect(topics.length, 1);
      expect(topics.first.slug, 'ai');
    });

    test('fetches discovery channels from /api/discovery/channels', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/discovery/channels');
        return http.Response(
          jsonEncode({
            'channels': [
              {
                'id': 'c_truth',
                'name': 'Truth Official',
                'handle': 'truthofficial',
                'category': 'News',
                'subscriberCount': 50000,
                'status': 'active',
              }
            ],
            'count': 1,
          }),
          200,
        );
      });

      final dataSource = EdgeFeedRemoteDataSource(
        client: client,
        cacheManager: cacheManager,
        baseUrl: 'https://www.truthworld.in',
      );

      final channels = await dataSource.fetchDiscoveryChannels();
      expect(channels.length, 1);
      expect(channels.first.handle, 'truthofficial');
    });
  });
}
