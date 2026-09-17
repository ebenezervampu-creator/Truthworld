import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/algorithm/algorithm_remote_config.dart';
import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile.dart';
import 'package:truthworld/features/home/data/services/feed_cache_manager.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TruthworldAlgorithm algorithm;

  setUp(() {
    Get.reset();
    Get.put(AlgorithmRemoteConfig());
    algorithm = Get.put(TruthworldAlgorithm());
  });

  tearDown(Get.reset);

  Video createVideo({
    required String id,
    required String title,
    required String channelId,
    required String category,
    List<String> topics = const [],
    List<String> tags = const [],
    double trustScore = 4.0,
  }) {
    return Video(
      id: id,
      title: title,
      description: 'Description for $title',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      ownerId: 'owner_$channelId',
      channelId: channelId,
      channelName: 'Channel $channelId',
      category: category,
      topics: topics,
      tags: tags,
      trustScore: trustScore,
      isFactChecked: true,
      status: VideoStatus.ready,
      visibility: 'public',
    );
  }

  group('TruthworldAlgorithm - Diversity & Catalog Availability', () {
    test('Preserves all 3 videos from the same channel without dropping any (Zero Catalog Drop)', () {
      final candidates = [
        createVideo(id: 'vid_1', title: 'Video 1', channelId: 'ch_same', category: 'Business & Finance', topics: ['investing']),
        createVideo(id: 'vid_2', title: 'Video 2', channelId: 'ch_same', category: 'Business & Finance', topics: ['sales']),
        createVideo(id: 'vid_3', title: 'Video 3', channelId: 'ch_same', category: 'Business & Finance', topics: ['tech']),
      ];

      final ranked = algorithm.rankVideos(
        candidates,
        RecommendationSurface.homeFeedAll,
        diversityConfig: DiversityConfig.homeFeed,
      );

      // Previously, maxConsecutiveSameChannel: 2 dropped vid_3 leaving only 2 videos.
      // With our fix, all 3 videos must be preserved.
      expect(ranked.length, equals(3));
      final returnedIds = ranked.map((s) => s.video.id).toSet();
      expect(returnedIds, containsAll(['vid_1', 'vid_2', 'vid_3']));
    });

    test('Personalized feed ranks high-affinity category/topic at the top', () {
      // User with strong affinity for 'sales' topic
      final userProfile = UserInterestProfile(
        userId: 'user_123',
        categoryAffinities: {'Business & Finance': 0.8},
        topicAffinities: {'topic:sales': 0.9, 'topic:investing': 0.1},
      );
      algorithm.updateProfile(userProfile);

      final candidates = [
        createVideo(id: 'vid_invest', title: 'Investing Intro', channelId: 'ch_1', category: 'Business & Finance', topics: ['investing']),
        createVideo(id: 'vid_sales', title: 'Cold Calling & Sales', channelId: 'ch_2', category: 'Business & Finance', topics: ['sales']),
      ];

      final ranked = algorithm.rankVideos(
        candidates,
        RecommendationSurface.homeFeedAll,
      );

      expect(ranked.length, equals(2));
      // Sales video must be ranked higher because of topic:sales affinity
      expect(ranked.first.video.id, equals('vid_sales'));
    });
  });

  group('FeedCacheManager - Scoped Caching', () {
    test('Generates user-scoped and guest cache keys correctly', () {
      final guestHomeKey = FeedCacheManager.cacheKeyForCategory('All', userId: 'guest');
      expect(guestHomeKey, equals('feed_home_guest'));

      final userHomeKey = FeedCacheManager.cacheKeyForCategory('All', userId: 'usr_789');
      expect(userHomeKey, equals('feed_home_usr_789'));

      final guestTrendingKey = FeedCacheManager.cacheKeyForCategory('Trending', userId: 'guest');
      expect(guestTrendingKey, equals('feed_trending_guest'));

      final userTrendingKey = FeedCacheManager.cacheKeyForCategory('Trending', userId: 'usr_789');
      expect(userTrendingKey, equals('feed_trending_usr_789'));
    });
  });

  group('UserInterestProfile - Guest Factory', () {
    test('Initializes guest profile with neutral defaults', () {
      final guest = UserInterestProfile.guest();
      expect(guest.userId, equals('guest'));
      expect(guest.categoryAffinities, isEmpty);
      expect(guest.topicAffinities, isEmpty);
      expect(guest.avgWatchCompletion, equals(0.5));
      expect(guest.recentlyWatchedVideoIds, isEmpty);
    });
  });
}
