import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/features/home/data/services/feed_cache_manager.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

class MockMainController extends MainController {
  final RxMap<String, int> _mockViews = <String, int>{}.obs;

  @override
  // ignore: must_call_super
  void onInit() {
    // Isolated unit test: bypass live Firestore stream initialization
  }

  @override
  RxMap<String, int> get videoViews => _mockViews;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Video Views Synchronization & Realtime Reactivity Tests', () {
    late FeedCacheManager cacheManager;
    late GetStorage storage;

    setUpAll(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (methodCall) async => '.',
      );
      await setupMockFirebase();
      await GetStorage.init('views_sync_storage');
    });

    setUp(() {
      Get.testMode = true;
      Get.reset();
      storage = GetStorage('views_sync_storage');
      storage.erase();
      cacheManager = FeedCacheManager(storage);
    });

    tearDown(() {
      Get.reset();
      storage.erase();
    });

    test('Video.views reads MainController.to.videoViews reactively', () {
      final mainCtrl = Get.put<MainController>(MockMainController());

      // Video 1 with raw views 0 (e.g. from parent doc)
      final video1 = Video(
        id: 'vid_eggs_truth',
        title: 'Are Eggs Vegetarian or Non-Vegetarian? The Science & Truth Explained',
        description: 'Debunking food myths with nutritional science.',
        thumbnailUrl: 'https://cdn.truthworld.com/thumbs/eggs.jpg',
        ownerId: 'creator_1',
        channelId: 'ch_1',
        channelName: 'Science Truths',
        category: 'Education',
        tags: ['health', 'food'],
        createdAt: Timestamp.now(),
        viewCount: 0,
      );

      // Initially shows raw 0 views
      expect(video1.views, 0);
      expect(video1.viewCount, 0);

      // User plays video in VideoScreen, shards/tracking update MainController.to.videoViews
      mainCtrl.videoViews[video1.id] = 4;

      // Video in Home immediately reflects 4 views reactively
      expect(video1.views, 4);
      expect(video1.viewCount, 4);

      // Video 2 with raw view 1 (e.g. Zomato video)
      final video2 = Video(
        id: 'vid_zomato_transformation',
        title: "Zomato's Big Transformation: From Food Delivery to a Consumer Empire",
        description: 'Business case study of Zomato.',
        thumbnailUrl: 'https://cdn.truthworld.com/thumbs/zomato.jpg',
        ownerId: 'creator_2',
        channelId: 'ch_2',
        channelName: 'Biz Insider',
        category: 'Business',
        tags: ['business', 'startups'],
        createdAt: Timestamp.now(),
        viewCount: 1,
      );

      expect(video2.views, 1);

      // Video 2 gets 2 views
      mainCtrl.videoViews[video2.id] = 2;

      expect(video2.views, 2);
      expect(video2.viewCount, 2);
    });

    test('FeedCacheManager.updateCachedVideo updates cached video view counts across multiple feeds', () {
      const homeKey = FeedCacheManager.keyHomeFeed;
      const trendingKey = FeedCacheManager.keyTrendingFeed;

      final video1 = Video(
        id: 'vid_eggs_truth',
        title: 'Are Eggs Vegetarian?',
        description: 'Food facts',
        ownerId: 'creator_1',
        channelId: 'ch_1',
        channelName: 'Science Truths',
        category: 'Education',
        tags: const ['food'],
        videoUrl: 'https://cdn.truthworld.com/videos/eggs.mp4',
        hlsUrl: 'https://cdn.truthworld.com/videos/eggs/master.m3u8',
        thumbnailUrl: 'https://cdn.truthworld.com/thumbs/eggs.jpg',
        createdAt: Timestamp.now(),
        viewCount: 0,
        status: VideoStatus.ready,
      );

      final video2 = Video(
        id: 'vid_zomato_transformation',
        title: "Zomato's Big Transformation",
        description: 'Business model',
        ownerId: 'creator_2',
        channelId: 'ch_2',
        channelName: 'Biz Insider',
        category: 'Business',
        tags: const ['business'],
        videoUrl: 'https://cdn.truthworld.com/videos/zomato.mp4',
        hlsUrl: 'https://cdn.truthworld.com/videos/zomato/master.m3u8',
        thumbnailUrl: 'https://cdn.truthworld.com/thumbs/zomato.jpg',
        createdAt: Timestamp.now(),
        viewCount: 1,
        status: VideoStatus.ready,
      );

      // Save initial feeds to cache
      cacheManager.saveFeedToCache(homeKey, [video1, video2]);
      cacheManager.saveFeedToCache(trendingKey, [video1]);

      // Verify initial cached state
      final cachedHomeBefore = cacheManager.getValidCachedVideos(homeKey);
      expect(cachedHomeBefore, isNotNull);
      expect(cachedHomeBefore!.firstWhere((v) => v.id == video1.id).views, 0);
      expect(cachedHomeBefore.firstWhere((v) => v.id == video2.id).views, 1);

      // Video 1 views update to 4, Video 2 views update to 2
      final updatedVideo1 = video1.copyWith(viewCount: 4);
      final updatedVideo2 = video2.copyWith(viewCount: 2);

      cacheManager.updateCachedVideo(updatedVideo1);
      cacheManager.updateCachedVideo(updatedVideo2);

      // Verify that cached feeds now have the updated view counts
      final cachedHomeAfter = cacheManager.getValidCachedVideos(homeKey);
      expect(cachedHomeAfter, isNotNull);
      expect(cachedHomeAfter!.firstWhere((v) => v.id == video1.id).views, 4);
      expect(cachedHomeAfter.firstWhere((v) => v.id == video2.id).views, 2);

      final cachedTrendingAfter = cacheManager.getValidCachedVideos(trendingKey);
      expect(cachedTrendingAfter, isNotNull);
      expect(cachedTrendingAfter!.firstWhere((v) => v.id == video1.id).views, 4);
    });
  });
}
