import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/services/algorithm/feed_algorithm_service.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/home/data/services/feed_cache_manager.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home Feed Refresh & Caching Bug Fix Tests', () {
    late FeedCacheManager cacheManager;

    setUpAll(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (methodCall) async => '.',
      );
      await setupMockFirebase();
      await GetStorage.init('test_storage');
    });

    setUp(() {
      cacheManager = FeedCacheManager(GetStorage('test_storage'));
    });

    tearDown(() {
      GetStorage('test_storage').erase();
    });

    test('FeedCacheManager never saves 0-video feed to cache', () {
      const cacheKey = 'test_empty_cache_key';

      // Attempt to save an empty list
      cacheManager.saveFeedToCache(cacheKey, []);

      // Cache should remain completely unset (no empty metadata/list saved)
      final cachedVideos = cacheManager.getValidCachedVideos(cacheKey);
      expect(cachedVideos, isNull);
    });

    test('FeedCacheManager falls back to playable videos when strict sanitization yields 0', () {
      final now = DateTime.now();
      // Video with status processing but valid playable URL
      final video = Video(
        id: 'vid_processing_playable',
        title: 'Tech Analysis',
        description: 'Description',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'owner_1',
        channelId: 'channel_1',
        channelName: 'Channel One',
        category: 'Tech',
        tags: [],
        createdAt: Timestamp.fromDate(now),
        uploadedAt: Timestamp.fromDate(now),
        videoUrl: 'https://example.com/stream.m3u8',
        status: VideoStatus.processing,
        geminiApproved: true,
        isApproved: true,
      );

      const cacheKey = 'test_fallback_cache_key';
      cacheManager.saveFeedToCache(cacheKey, [video]);

      // Cache should contain the playable fallback video
      final cachedVideos = cacheManager.getValidCachedVideos(cacheKey);
      expect(cachedVideos, isNotNull);
      expect(cachedVideos!.length, equals(1));
      expect(cachedVideos.first.id, equals('vid_processing_playable'));
    });

    test('FeedAlgorithmService.applyLocalAdjustments does not starve feed when all videos are recently watched', () {
      final service = FeedAlgorithmService();
      final now = DateTime.now();

      final video1 = Video(
        id: 'vid_1',
        title: 'Video 1',
        description: 'Desc',
        thumbnailUrl: 'https://example.com/thumb1.jpg',
        ownerId: 'owner_1',
        channelId: 'channel_1',
        channelName: 'Channel 1',
        category: 'Tech',
        tags: [],
        createdAt: Timestamp.fromDate(now),
        uploadedAt: Timestamp.fromDate(now),
        videoUrl: 'https://example.com/video1.mp4',
        status: VideoStatus.ready,
      );

      final video2 = Video(
        id: 'vid_2',
        title: 'Video 2',
        description: 'Desc',
        thumbnailUrl: 'https://example.com/thumb2.jpg',
        ownerId: 'owner_2',
        channelId: 'channel_2',
        channelName: 'Channel 2',
        category: 'Tech',
        tags: [],
        createdAt: Timestamp.fromDate(now),
        uploadedAt: Timestamp.fromDate(now),
        videoUrl: 'https://example.com/video2.mp4',
        status: VideoStatus.ready,
      );

      // Both videos are in recently watched
      final recentlyWatched = {'vid_1', 'vid_2'};

      final adjusted = service.applyLocalAdjustments(
        [video1, video2],
        recentlyWatchedVideoIds: recentlyWatched,
      );

      // Feed should relax recently watched and not return 0 videos
      expect(adjusted.length, equals(2));
      expect(adjusted.map((v) => v.id), containsAll(['vid_1', 'vid_2']));
    });

    test('FeedAlgorithmService.applyLocalAdjustments strictly honors blocked channels even when relaxing watched', () {
      final service = FeedAlgorithmService();
      final now = DateTime.now();

      final video1 = Video(
        id: 'vid_1',
        title: 'Video 1',
        description: 'Desc',
        thumbnailUrl: 'https://example.com/thumb1.jpg',
        ownerId: 'owner_1',
        channelId: 'channel_blocked',
        channelName: 'Blocked Channel',
        category: 'Tech',
        tags: [],
        createdAt: Timestamp.fromDate(now),
        uploadedAt: Timestamp.fromDate(now),
        videoUrl: 'https://example.com/video1.mp4',
        status: VideoStatus.ready,
      );

      final video2 = Video(
        id: 'vid_2',
        title: 'Video 2',
        description: 'Desc',
        thumbnailUrl: 'https://example.com/thumb2.jpg',
        ownerId: 'owner_2',
        channelId: 'channel_clean',
        channelName: 'Good Channel',
        category: 'Tech',
        tags: [],
        createdAt: Timestamp.fromDate(now),
        uploadedAt: Timestamp.fromDate(now),
        videoUrl: 'https://example.com/video2.mp4',
        status: VideoStatus.ready,
      );

      // Both are watched, but video1 is from a blocked channel
      final adjusted = service.applyLocalAdjustments(
        [video1, video2],
        blockedChannelIds: {'channel_blocked'},
        recentlyWatchedVideoIds: {'vid_1', 'vid_2'},
      );

      // Only video2 from the unblocked channel should be returned
      expect(adjusted.length, equals(1));
      expect(adjusted.first.id, equals('vid_2'));
    });

    test('VideoMapParser resolves stream URLs from media map and HLS/Dash fields', () {
      final rawData = <String, dynamic>{
        'id': 'vid_media_hls',
        'title': 'Decentralized Intelligence',
        'description': 'AI and decentralized protocols',
        'media': {
          'hlsUrl': 'https://cdn.example.com/master.m3u8',
          'thumbnailUrl': 'https://cdn.example.com/thumb.jpg',
        },
        'status': 'processing',
        'visibility': 'public',
        'ownerId': 'owner_hls',
        'channelId': 'channel_hls',
        'channelName': 'Tech Channel',
      };

      final video = Video.fromMap(rawData);
      expect(video.hlsUrl, equals('https://cdn.example.com/master.m3u8'));
      expect(video.thumbnailUrl, equals('https://cdn.example.com/thumb.jpg'));
      expect(VideoVisibilityPolicy.hasPlayableMedia(video), isTrue);
      expect(VideoVisibilityPolicy.isValidVideo(video), isTrue);
    });

    test('VideoVisibilityPolicy identifies unhydrated recommendation videos lacking playable media', () {
      // Simulates the lightweight response from getHomeFeed endpoint
      final lightweightResponse = <String, dynamic>{
        'id': 'f37dd18e-209b-4d35-b872-a6e651351382',
        'title': 'choosen one series 1 season 2',
        'creatorName': 'Ebenezer Vampu',
        'channelId': 'g3zghQFpUkqsiezaIhud',
        'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
        'category': 'Movies',
        'duration': 219,
        'viewCount': 0,
        'likeCount': 1,
        'trustScore': 100,
        // Notice videoUrl and originalUrl are absent in unhydrated recommendation response
      };

      final video = Video.fromMap(lightweightResponse);
      expect(video.id, equals('f37dd18e-209b-4d35-b872-a6e651351382'));
      expect(VideoVisibilityPolicy.hasPlayableMedia(video), isFalse);

      // Once hydrated with Firestore stream data, video becomes fully playable and valid
      final hydratedVideo = video.copyWith(
        originalUrl: 'https://storage.googleapis.com/videos/stream.mp4',
        videoUrl: 'https://storage.googleapis.com/videos/stream.mp4',
        status: VideoStatus.ready,
      );
      expect(VideoVisibilityPolicy.hasPlayableMedia(hydratedVideo), isTrue);
      expect(VideoVisibilityPolicy.isValidVideo(hydratedVideo), isTrue);
    });

    test('VideoVisibilityPolicy strictly rejects incomplete uploading videos from feed', () {
      final uploadingVideo = <String, dynamic>{
        'id': '9f0e09f7-ba6e-4e4a-b9ab-6422542270cc',
        'title': 'Uploading...',
        'creatorName': 'Ebenezer Vampu',
        'channelId': 'g3zghQFpUkqsiezaIhud',
        'category': 'Spirituality',
        'status': 'uploading',
      };

      final video = Video.fromMap(uploadingVideo);
      expect(VideoVisibilityPolicy.isValidVideo(video), isFalse);
    });
  });
}
