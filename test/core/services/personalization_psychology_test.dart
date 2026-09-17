import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/algorithm/algorithm_remote_config.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile.dart';
import 'package:truthworld/features/home/presentation/controllers/home_discovery_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlipCoinService flipCoinService;
  late TruthworldAlgorithm algorithm;

  setUp(() {
    Get.reset();
    Get.put(AlgorithmRemoteConfig());
    flipCoinService = Get.put(FlipCoinService());
    algorithm = Get.put(TruthworldAlgorithm());
  });

  tearDown(Get.reset);

  Video createSampleVideo({
    required String id,
    required String title,
    required String channelId,
    required String category,
    List<String> topics = const [],
    List<String> tags = const [],
    String? coinBattlePairVideoId,
    String? coinBattleStance,
    double trustScore = 4.0,
    bool isFactChecked = true,
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
      tags: tags,
      topics: topics,
      trustScore: trustScore,
      isFactChecked: isFactChecked,
      status: VideoStatus.ready,
      visibility: 'public',
      coinBattlePairVideoId: coinBattlePairVideoId,
      coinBattleStance: coinBattleStance,
    );
  }

  group('UserPsychologyProfile & Cognitive Archetypes', () {
    test('Analytical Deep Diver: high fact-check and long-form watch completion', () {
      final profile = UserInterestProfile(
        userId: 'analyst_1',
        totalWatchDurationSec: 18000,
        avgWatchCompletion: 0.88,
        factCheckedWatchCount: 15,
        longFormWatchCount: 10,
        categoryAffinities: {'Science': 0.8, 'Philosophy': 0.7},
      );

      final psychology = profile.psychologyProfile;
      expect(psychology.archetype, equals(CognitiveArchetype.analyticalDeepDiver));
      expect(psychology.criticalThinkingScore, greaterThan(0.6));
      expect(psychology.intellectualDepthScore, greaterThan(0.6));
    });

    test('Curious Explorer: high novelty, broad topic and channel exploration', () {
      final profile = UserInterestProfile(
        userId: 'explorer_1',
        exploredTopicSlugs: {
          'ai', 'space', 'geopolitics', 'economics', 'history',
          'biology', 'quantum', 'robotics', 'climate', 'art'
        },
        discoveredChannelIds: {'ch1', 'ch2', 'ch3', 'ch4', 'ch5', 'ch6'},
        searchTopicCounts: {'science': 4, 'technology': 5, 'music': 3},
        categoryAffinities: {'Tech': 0.3, 'Music': 0.2, 'Science': 0.25},
      );

      final psychology = profile.psychologyProfile;
      expect(psychology.archetype, equals(CognitiveArchetype.curiousExplorer));
      expect(psychology.noveltyPreference, greaterThan(0.6));
      expect(psychology.focusVsBreadth, lessThanOrEqualTo(0.5));
    });

    test('Focused Specialist: concentrated topics with low breadth', () {
      final profile = UserInterestProfile(
        userId: 'specialist_1',
        categoryAffinities: {'Technology': 0.95},
        topicAffinities: {'topic:flutter': 0.9, 'topic:dart': 0.85},
        topicExploreCounts: {'topic:flutter': 15, 'topic:dart': 12},
        exploredTopicSlugs: {'flutter', 'dart'},
        discoveredChannelIds: {'flutter_dev'},
      );

      final psychology = profile.psychologyProfile;
      expect(psychology.archetype, equals(CognitiveArchetype.focusedSpecialist));
      expect(psychology.focusVsBreadth, greaterThanOrEqualTo(0.6));
    });

    test('Love score calculation combines searches, topics, channels, completion, and likes', () {
      final profile = UserInterestProfile(
        userId: 'user_love',
        searchTopicCounts: {'astronomy': 6},
        exploredTopicSlugs: {'astronomy'},
        topicExploreCounts: {'topic:astronomy': 5},
        discoveredChannelIds: {'nasa_channel'},
        channelExploreCounts: {'nasa_channel': 4},
        recentlyLikedVideoIds: {'video_mars'},
        avgWatchCompletion: 0.85,
        categoryAffinities: {'Science': 0.8},
        topicAffinities: {'topic:astronomy': 0.9},
      );

      final psychology = profile.psychologyProfile;

      // Video that user genuinely loves (matches category, topic, channel)
      final loveScore = psychology.calculateLoveScore(
        category: 'Science',
        topics: ['astronomy'],
        channelId: 'nasa_channel',
      );

      expect(loveScore, greaterThan(0.55));

      // Video in completely unrelated topic and channel
      final unlovedScore = psychology.calculateLoveScore(
        category: 'Cooking',
        topics: ['baking'],
        channelId: 'chef_channel',
      );

      expect(unlovedScore, equals(0.0));
      expect(loveScore, greaterThan(unlovedScore));
    });
  });

  group('Unexplored Horizon Detection', () {
    test('Identifies unexplored categories correctly', () {
      final profile = UserInterestProfile(
        userId: 'user_horizon',
        categoryAffinities: {'Science': 0.8, 'Technology': 0.6},
        recentlyWatchedVideoIds: {'vid1', 'vid2'},
      );

      final allCategories = ['Science', 'Technology', 'Philosophy', 'Art', 'History'];
      final unexplored = profile.getUnexploredCategories(allCategories);

      expect(unexplored, contains('Philosophy'));
      expect(unexplored, contains('Art'));
      expect(unexplored, contains('History'));
      expect(unexplored, isNot(contains('Science')));
      expect(unexplored, isNot(contains('Technology')));

      expect(profile.isUnexploredCategory('Philosophy'), isTrue);
      expect(profile.isUnexploredCategory('Science'), isFalse);
    });

    test('Identifies unexplored topics correctly', () {
      final profile = UserInterestProfile(
        userId: 'user_topics',
        exploredTopicSlugs: {'quantum', 'relativity'},
        topicAffinities: {'topic:quantum': 0.8},
      );

      final candidateTopics = ['quantum', 'relativity', 'neuroscience', 'epistemology'];
      final unexplored = profile.getUnexploredTopicSlugs(candidateTopics);

      expect(unexplored, contains('neuroscience'));
      expect(unexplored, contains('epistemology'));
      expect(unexplored, isNot(contains('quantum')));
      expect(unexplored, isNot(contains('relativity')));
    });
  });

  group('TruthworldAlgorithm Personalization & Adaptive Weighting', () {
    test('Analytical Deep Diver receives elevated knowledgeQuality and credibility weighting', () {
      final analystProfile = UserInterestProfile(
        userId: 'analyst_test',
        totalWatchDurationSec: 20000,
        avgWatchCompletion: 0.9,
        factCheckedWatchCount: 20,
        longFormWatchCount: 15,
        categoryAffinities: {'Science': 0.8},
      );

      algorithm.updateProfile(analystProfile);

      final highQualityVideo = createSampleVideo(
        id: 'vid_scientific_paper',
        title: 'Rigorous Peer-Reviewed Quantum Paper',
        channelId: 'science_channel',
        category: 'Science',
        trustScore: 4.8,
      );

      final scored = algorithm.scoreVideo(
        highQualityVideo,
        RecommendationSurface.homeFeedAll,
      );

      expect(scored, isNotNull);
      expect(scored!.signalBreakdown['knowledgeQuality'], greaterThan(0.0));
      expect(scored.signalBreakdown['loveAffinity'], isNotNull);
    });

    test('Video with high love score gets love boost in final score', () {
      final profile = UserInterestProfile(
        userId: 'love_boost_user',
        searchTopicCounts: {'robotics': 10},
        exploredTopicSlugs: {'robotics'},
        topicExploreCounts: {'topic:robotics': 8},
        discoveredChannelIds: {'boston_dynamics'},
        categoryAffinities: {'Technology': 0.9},
      );

      algorithm.updateProfile(profile);

      final lovedVideo = createSampleVideo(
        id: 'vid_robotics',
        title: 'New Humanoid Robotics Breakthrough',
        channelId: 'boston_dynamics',
        category: 'Technology',
        topics: ['robotics'],
        trustScore: 4.5,
      );

      final normalVideo = createSampleVideo(
        id: 'vid_unrelated',
        title: 'Random Entertainment Clip',
        channelId: 'random_channel',
        category: 'Entertainment',
        topics: ['pranks'],
        trustScore: 3.0,
        isFactChecked: false,
      );

      final scoredLoved = algorithm.scoreVideo(lovedVideo, RecommendationSurface.homeFeedAll);
      final scoredNormal = algorithm.scoreVideo(normalVideo, RecommendationSurface.homeFeedAll);

      expect(scoredLoved, isNotNull);
      expect(scoredNormal, isNotNull);
      expect(scoredLoved!.score, greaterThan(scoredNormal!.score));
      expect(scoredLoved.signalBreakdown['loveAffinity'], greaterThan(0.0));
    });
  });

  group('FlipCoin The Other Side & Unexplored Horizon Ranking', () {
    test('FlipCoinService boosts videos in unexplored categories and unexplored topics', () {
      final profile = UserInterestProfile(
        userId: 'user_flip_test',
        categoryAffinities: {'Technology': 0.9, 'Gaming': 0.8},
        exploredTopicSlugs: {'flutter', 'unity', 'coding'},
        topicAffinities: {'topic:flutter': 0.9, 'topic:unity': 0.8},
        recentlyWatchedVideoIds: {'vid_tech_1', 'vid_tech_2'},
      );

      // Candidate 1: Unexplored category (Philosophy) with counter-perspective
      final unexploredHorizonVideo = createSampleVideo(
        id: 'vid_phil',
        title: 'Epistemology and Rational Skepticism of Tech',
        channelId: 'phil_channel',
        category: 'Philosophy',
        topics: ['epistemology', 'metaphysics'],
        trustScore: 4.2,
      );

      // Candidate 2: Video in user's comfort zone (Technology) with 0 contrast
      final comfortZoneVideo = createSampleVideo(
        id: 'vid_comfort',
        title: 'Flutter Tutorial and App Development',
        channelId: 'flutter_channel',
        category: 'Technology',
        topics: ['flutter', 'coding'],
        trustScore: 4.2,
      );

      final contrastUnexplored = flipCoinService.calculateUserContrastScore(
        unexploredHorizonVideo,
        profile,
      );

      final contrastComfort = flipCoinService.calculateUserContrastScore(
        comfortZoneVideo,
        profile,
      );

      expect(contrastUnexplored, greaterThan(0.5));
      // Comfort zone video without counter-perspective is disqualified (0.0)
      expect(contrastComfort, equals(0.0));
      expect(flipCoinService.isOppositeSideVideo(unexploredHorizonVideo, profile), isTrue);
      expect(flipCoinService.isOppositeSideVideo(comfortZoneVideo, profile), isFalse);
    });

    test('rankVideosOpposite prioritizes unexplored horizon videos', () {
      final profile = UserInterestProfile(
        userId: 'user_rank_opp',
        categoryAffinities: {'Politics': 0.9},
        exploredTopicSlugs: {'election'},
      );

      algorithm.updateProfile(profile);

      final unexploredVideo = createSampleVideo(
        id: 'vid_space_exploration',
        title: 'Deep Space Telescope Discoveries',
        channelId: 'astro_channel',
        category: 'Science',
        topics: ['astrophysics'],
        trustScore: 4.5,
      );

      final sameSideVideo = createSampleVideo(
        id: 'vid_same_side',
        title: 'Standard Election Campaign News',
        channelId: 'pol_channel',
        category: 'Politics',
        topics: ['election'],
      );

      final oppositeFeed = algorithm.rankVideosOpposite(
        [unexploredVideo, sameSideVideo],
        RecommendationSurface.homeFeedAll,
      );

      // The feed must contain the unexplored horizon video and exclude the same-side comfort video
      final videoIds = oppositeFeed.map((s) => s.video.id).toList();
      expect(videoIds, contains('vid_space_exploration'));
      expect(videoIds, isNot(contains('vid_same_side')));
    });
  });

  group('Home Unexplored Tab & Latent Love Personalization', () {
    test('HomeDiscoveryController places Unexplored tab directly before Trending for signed-in users, and never shows Flip Coin or Unexplored for unsigned users', () {
      final authCategories = HomeDiscoveryController.getFixedCategories();
      final unauthCategories = HomeDiscoveryController.getFixedCategories(isAuthenticated: false);

      // Signed-in users see Unexplored before Trending, and Flip Coin
      expect(authCategories, contains('Unexplored'));
      expect(authCategories, contains('Flip Coin'));
      final authUnexploredIdx = authCategories.indexOf('Unexplored');
      final authTrendingIdx = authCategories.indexOf('Trending');
      expect(authUnexploredIdx, isNonNegative);
      expect(authTrendingIdx, isNonNegative);
      expect(authUnexploredIdx, equals(authTrendingIdx - 1));

      // Unsigned users must NEVER see Flip Coin or Unexplored
      expect(unauthCategories, isNot(contains('Flip Coin')));
      expect(unauthCategories, isNot(contains('Unexplored')));
      expect(unauthCategories, isNot(contains('Subscriptions')));
      expect(unauthCategories, isNot(contains('Posts')));
      expect(unauthCategories, equals(['All', 'Trending', 'New', 'Popular']));
    });

    test('rankVideosUnexplored prioritizes high latent-love unexplored content tailored to archetype', () {
      final analystProfile = UserInterestProfile(
        userId: 'deep_diver_user',
        factCheckedWatchCount: 18,
        longFormWatchCount: 15,
        totalWatchDurationSec: 15000,
        avgWatchCompletion: 0.90,
        categoryAffinities: {'Technology': 0.85},
        exploredTopicSlugs: {'coding', 'flutter'},
        recentlyWatchedVideoIds: {'vid_already_watched'},
      );

      algorithm.updateProfile(analystProfile);

      // Candidate 1: Unexplored category (Philosophy) with high knowledge quality and fact check
      // Perfectly matches analytical deep diver's psychology
      final latentLoveUnexplored = createSampleVideo(
        id: 'vid_latent_love',
        title: 'Epistemological Foundations of Rational Thought',
        channelId: 'philosophy_center',
        category: 'Philosophy',
        topics: ['epistemology', 'rationalism'],
        trustScore: 4.9,
      );

      // Candidate 2: Already watched video (must be disqualified)
      final alreadyWatched = createSampleVideo(
        id: 'vid_already_watched',
        title: 'Tech Architecture Review',
        channelId: 'tech_channel',
        category: 'Technology',
        topics: ['architecture'],
        trustScore: 4.8,
      );

      // Candidate 3: Comfort zone video already deeply explored with no unexplored topics
      final deeplyExploredComfort = createSampleVideo(
        id: 'vid_comfort_zone',
        title: 'Flutter Coding Tips',
        channelId: 'coding_channel',
        category: 'Technology',
        topics: ['coding', 'flutter'],
      );

      final ranked = algorithm.rankVideosUnexplored(
        [latentLoveUnexplored, alreadyWatched, deeplyExploredComfort],
        RecommendationSurface.unexplored,
      );

      final ids = ranked.map((s) => s.video.id).toList();
      expect(ids, contains('vid_latent_love'));
      expect(ids, isNot(contains('vid_already_watched')));
      expect(ids, isNot(contains('vid_comfort_zone')));
      expect(ranked.first.score, greaterThan(5.0));
      expect(ranked.first.signalBreakdown['unexploredBonus'], greaterThan(0.0));
      expect(ranked.first.signalBreakdown['archetypeBonus'], greaterThan(0.0));
    });

    test('rankVideosUnexplored strictly disqualifies watched videos from watchProgress and profile', () {
      final profile = UserInterestProfile(
        userId: 'user_123',
        categoryAffinities: {'History': 0.1},
        recentlyWatchedVideoIds: {'vid_watched_1'},
        watchProgress: {'vid_watched_progress': 0.45},
      );

      algorithm.updateProfile(profile);

      final unexpVideo = createSampleVideo(
        id: 'vid_unexplored',
        title: 'Ancient Egypt Secrets',
        channelId: 'history_hub',
        category: 'History',
        topics: ['egypt'],
      );

      final watchedVideo1 = createSampleVideo(
        id: 'vid_watched_1',
        title: 'Watched Video 1',
        channelId: 'history_hub',
        category: 'History',
        topics: ['pyramids'],
      );

      final watchedProgressVideo = createSampleVideo(
        id: 'vid_watched_progress',
        title: 'Partially Watched Video',
        channelId: 'history_hub',
        category: 'History',
        topics: ['pharaohs'],
      );

      final ranked = algorithm.rankVideosUnexplored(
        [unexpVideo, watchedVideo1, watchedProgressVideo],
        RecommendationSurface.unexplored,
      );

      final ids = ranked.map((s) => s.video.id).toList();
      expect(ids, contains('vid_unexplored'));
      expect(ids, isNot(contains('vid_watched_1')));
      expect(ids, isNot(contains('vid_watched_progress')));
    });
  });
}
