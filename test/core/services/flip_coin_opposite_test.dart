import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/algorithm/algorithm_remote_config.dart';
import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile.dart';
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

  group('FlipCoinService calculateUserContrastScore & isOppositeSideVideo', () {
    final establishedProfile = UserInterestProfile(
      userId: 'user_1',
      categoryAffinities: {
        'Technology': 0.9,
        'Science': 0.8,
        'Gaming': 0.6,
      },
      topicAffinities: {
        'topic:ai': 0.85,
        'topic:russia': 0.75,
      },
      followedTopicSlugs: {'ai', 'russia'},
      subscribedChannelIds: {'channel_tech_fav'},
      channelExposureCounts: {'channel_tech_fav': 10},
      recentlyWatchedVideoIds: {'vid_tech_1', 'vid_tech_2'},
    );

    test('Disqualifies videos uploaded by the user themselves (returns 0.0)', () {
      final ownVideo = createSampleVideo(
        id: 'vid_own_1',
        title: 'My Video on Finance and Tech',
        channelId: 'channel_ebenezer',
        category: 'Technology',
      );
      // set ownerId to matching userId
      final ownVideoWithOwner = ownVideo.copyWith(ownerId: 'user_1');

      final score = flipCoinService.calculateUserContrastScore(ownVideoWithOwner, establishedProfile);
      expect(score, equals(0.0));
      expect(flipCoinService.isOppositeSideVideo(ownVideoWithOwner, establishedProfile), isFalse);
    });

    test('Disqualifies videos from user subscribed channels (returns 0.0)', () {
      final subscribedVideo = createSampleVideo(
        id: 'vid_sub_1',
        title: 'Breakthroughs in AI and Tech',
        channelId: 'channel_tech_fav',
        category: 'Technology',
        topics: ['ai'],
      );

      final score = flipCoinService.calculateUserContrastScore(subscribedVideo, establishedProfile);
      expect(score, equals(0.0));
      expect(flipCoinService.isOppositeSideVideo(subscribedVideo, establishedProfile), isFalse);
    });

    test('Disqualifies same-side videos in top category with no contrasting angle (returns 0.0)', () {
      final sameSideVideo = createSampleVideo(
        id: 'vid_same_1',
        title: 'The Great AI Revolution Future Tech',
        channelId: 'channel_random_tech',
        category: 'Technology',
        topics: ['ai'],
      );

      final score = flipCoinService.calculateUserContrastScore(sameSideVideo, establishedProfile);
      expect(score, equals(0.0));
      expect(flipCoinService.isOppositeSideVideo(sameSideVideo, establishedProfile), isFalse);
    });

    test('Qualifies videos with contrarian / opposite keywords (returns > 0.0)', () {
      final oppositeAiVideo = createSampleVideo(
        id: 'vid_opp_1',
        title: 'AI Safety and Ethics: The Serious Risks and Regulation Ahead',
        channelId: 'channel_ethics_lab',
        category: 'Technology',
        topics: ['ethics', 'regulation'],
      );

      final score = flipCoinService.calculateUserContrastScore(oppositeAiVideo, establishedProfile);
      expect(score, greaterThan(0.0));
      expect(flipCoinService.isOppositeSideVideo(oppositeAiVideo, establishedProfile), isTrue);

      final oppositeGeopoliticsVideo = createSampleVideo(
        id: 'vid_opp_2',
        title: 'Ukraine and NATO Diplomacy for Longterm Peace',
        channelId: 'channel_world_peace',
        category: 'News',
        topics: ['ukraine', 'peace', 'diplomacy'],
      );

      final scoreGeo = flipCoinService.calculateUserContrastScore(oppositeGeopoliticsVideo, establishedProfile);
      expect(scoreGeo, greaterThan(0.0));
      expect(flipCoinService.isOppositeSideVideo(oppositeGeopoliticsVideo, establishedProfile), isTrue);
    });

    test('Qualifies videos with coin battle pairs / stances', () {
      final coinBattleVideo = createSampleVideo(
        id: 'vid_battle_1',
        title: 'The Counter Perspective Debate',
        channelId: 'channel_debate',
        category: 'Documentary',
        coinBattlePairVideoId: 'vid_tech_1',
        coinBattleStance: 'Against Unchecked Acceleration',
      );

      final score = flipCoinService.calculateUserContrastScore(coinBattleVideo, establishedProfile);
      expect(score, greaterThan(0.0));
      expect(flipCoinService.isOppositeSideVideo(coinBattleVideo, establishedProfile), isTrue);
    });

    test('Qualifies videos from alternative under-explored categories with diverse channel', () {
      final alternativeCatVideo = createSampleVideo(
        id: 'vid_alt_1',
        title: 'Deep Wilderness & Ancient Philosophy',
        channelId: 'channel_nature_philo',
        category: 'Philosophy',
        topics: ['philosophy', 'nature'],
      );

      final score = flipCoinService.calculateUserContrastScore(alternativeCatVideo, establishedProfile);
      expect(score, greaterThan(0.0));
      expect(flipCoinService.isOppositeSideVideo(alternativeCatVideo, establishedProfile), isTrue);
    });

    test('Handles cold start / new user profile with debate/fact-checked content', () {
      final newProfile = UserInterestProfile();

      final debateVideo = createSampleVideo(
        id: 'vid_cold_1',
        title: 'AI Risks vs Breakthroughs: The Global Debate',
        channelId: 'channel_global',
        category: 'Technology',
        coinBattleStance: 'Pro-Safety',
      );

      final score = flipCoinService.calculateUserContrastScore(debateVideo, newProfile);
      expect(score, greaterThan(0.0));
      expect(flipCoinService.isOppositeSideVideo(debateVideo, newProfile), isTrue);

      final normalStandardVideo = createSampleVideo(
        id: 'vid_cold_normal',
        title: 'Hike a social media platform',
        channelId: 'channel_user',
        category: 'Technology',
      );

      final normalScore = flipCoinService.calculateUserContrastScore(normalStandardVideo, newProfile);
      expect(normalScore, equals(0.0));
      expect(flipCoinService.isOppositeSideVideo(normalStandardVideo, newProfile), isFalse);
    });
  });

  group('TruthworldAlgorithm rankVideosOpposite strict filtering', () {
    test('Returns ONLY qualifying opposite-side videos and completely excludes same-side videos', () {
      final userProfile = UserInterestProfile(
        userId: 'user_1',
        categoryAffinities: {
          'Technology': 0.95,
        },
        topicAffinities: {
          'topic:ai': 0.9,
        },
        followedTopicSlugs: {'ai'},
        subscribedChannelIds: {'channel_sub_tech'},
      );
      algorithm.updateProfile(userProfile);

      final sameSideSubscribed = createSampleVideo(
        id: '1',
        title: 'Best AI Tools of 2026',
        channelId: 'channel_sub_tech',
        category: 'Technology',
        topics: ['ai'],
      );

      final sameSideStandard = createSampleVideo(
        id: '2',
        title: 'New AI Breakthrough Announcement',
        channelId: 'channel_other_tech',
        category: 'Technology',
        topics: ['ai'],
      );

      final oppositeSide1 = createSampleVideo(
        id: '3',
        title: 'AI Safety and Job Displacement Risks',
        channelId: 'channel_ethics',
        category: 'Technology',
        topics: ['ethics', 'safety', 'regulation'],
      );

      final oppositeSide2 = createSampleVideo(
        id: '4',
        title: 'Wisdom of Ancient Philosophy and Nature',
        channelId: 'channel_philo',
        category: 'Philosophy',
        topics: ['philosophy'],
      );

      final candidates = [
        sameSideSubscribed,
        sameSideStandard,
        oppositeSide1,
        oppositeSide2,
      ];

      final ranked = algorithm.rankVideosOpposite(
        candidates,
        RecommendationSurface.homeFeedAll,
        diversityConfig: DiversityConfig.homeFeed,
      );

      final resultIds = ranked.map((s) => s.video.id).toList();

      // Only oppositeSide1 and oppositeSide2 should be returned
      expect(resultIds, containsAll(['3', '4']));
      expect(resultIds, isNot(contains('1')));
      expect(resultIds, isNot(contains('2')));
      expect(resultIds.length, equals(2));
    });
  });

  group('VideoScreen Flip Coin calculateContrastScore & rankVideosForCurrentVideoOpposite', () {
    final currentPlayingVideo = createSampleVideo(
      id: 'current_vid',
      title: 'The Great AI Revolution & Acceleration',
      channelId: 'channel_ai_main',
      category: 'Technology',
      topics: ['ai', 'technology'],
      coinBattleStance: 'Pro-Acceleration',
      coinBattlePairVideoId: 'paired_counter_vid',
    );

    test('calculateContrastScore returns 0.0 for same video and same channel', () {
      final sameVid = createSampleVideo(
        id: 'current_vid',
        title: 'The Great AI Revolution & Acceleration',
        channelId: 'channel_ai_main',
        category: 'Technology',
      );
      final sameChanVid = createSampleVideo(
        id: 'same_chan_vid',
        title: 'Another Tech AI Video',
        channelId: 'channel_ai_main',
        category: 'Technology',
      );

      expect(flipCoinService.calculateContrastScore(currentPlayingVideo, sameVid), equals(0.0));
      expect(flipCoinService.calculateContrastScore(currentPlayingVideo, sameChanVid), equals(0.0));
    });

    test('calculateContrastScore gives highest boost for direct coin battle paired video', () {
      final pairedCounterVid = createSampleVideo(
        id: 'paired_counter_vid',
        title: 'The Dangers of Unchecked AI: Alignment and Safety',
        channelId: 'channel_ethics',
        category: 'Technology',
        coinBattlePairVideoId: 'current_vid',
        coinBattleStance: 'Pro-Safety',
      );

      final score = flipCoinService.calculateContrastScore(currentPlayingVideo, pairedCounterVid);
      expect(score, greaterThanOrEqualTo(1.5));
    });

    test('calculateContrastScore qualifies videos with opposing keywords from different channels', () {
      final opposingKeywordVid = createSampleVideo(
        id: 'opp_kw_vid',
        title: 'AI Safety Ethics & Strict Regulation Policy',
        channelId: 'channel_policy',
        category: 'Technology',
        topics: ['ethics', 'regulation'],
      );

      final score = flipCoinService.calculateContrastScore(currentPlayingVideo, opposingKeywordVid);
      expect(score, greaterThan(0.0));
    });

    test('rankVideosForCurrentVideoOpposite strictly returns only opposite perspective videos', () {
      final sameSideVid = createSampleVideo(
        id: 'same_side_1',
        title: 'AI is Amazing: Full Guide',
        channelId: 'channel_ai_main',
        category: 'Technology',
        topics: ['ai'],
      );

      final pairedCounterVid = createSampleVideo(
        id: 'paired_counter_vid',
        title: 'The Counter Perspective on AI',
        channelId: 'channel_ethics',
        category: 'Technology',
        coinBattlePairVideoId: 'current_vid',
        coinBattleStance: 'Pro-Safety',
      );

      final opposingKeywordVid = createSampleVideo(
        id: 'opp_kw_vid',
        title: 'AI Safety and Ethics Debate',
        channelId: 'channel_policy',
        category: 'Technology',
        topics: ['ethics', 'safety'],
      );

      final candidates = [sameSideVid, pairedCounterVid, opposingKeywordVid];

      final ranked = algorithm.rankVideosForCurrentVideoOpposite(
        currentPlayingVideo,
        candidates,
      );

      final resultIds = ranked.map((s) => s.video.id).toList();

      expect(resultIds, containsAll(['paired_counter_vid', 'opp_kw_vid']));
      expect(resultIds, isNot(contains('same_side_1')));
      expect(resultIds.first, equals('paired_counter_vid')); // Highest priority
    });

    test('Identifies and prioritizes Iran / Ceasefire video when Israel President video is playing', () {
      final israelPresidentVideo = createSampleVideo(
        id: 'israel_speech_1',
        title: 'Israel Prime Minister and President Address Nation on Military Campaign and War',
        channelId: 'channel_israel_news',
        category: 'News',
        topics: ['israel', 'war', 'middle east'],
      );

      final iranPresidentVideo = createSampleVideo(
        id: 'iran_speech_1',
        title: 'Iran President Pezeshkian Address on Middle East Diplomacy and Defense',
        channelId: 'channel_world_diplomacy',
        category: 'News',
        topics: ['iran', 'diplomacy', 'middle east'],
      );

      final sameSideIsraelVideo = createSampleVideo(
        id: 'israel_same_side',
        title: 'Israel Military Analysis of Today Operations',
        channelId: 'channel_israel_news',
        category: 'News',
        topics: ['israel', 'war'],
      );

      final candidates = [sameSideIsraelVideo, iranPresidentVideo];

      final ranked = algorithm.rankVideosForCurrentVideoOpposite(
        israelPresidentVideo,
        candidates,
      );

      final resultIds = ranked.map((s) => s.video.id).toList();

      expect(resultIds, contains('iran_speech_1'));
      expect(resultIds, isNot(contains('israel_same_side')));
    });

    test('Flip Coin surfaces balanced spectrum across Counterpart Actor, Diplomatic UN, and Peace Perspectives', () {
      final israelWarSpeech = createSampleVideo(
        id: 'israel_war_speech',
        title: 'Israel Military Operation and War Campaign Address',
        channelId: 'channel_israel_official',
        category: 'News',
        topics: ['israel', 'war', 'middle east'],
      );

      // 1. Counterpart Actor Perspective (Iran address)
      final iranSpeech = createSampleVideo(
        id: 'iran_speech',
        title: 'Iran President Address on Regional Deterrence and Sovereignty',
        channelId: 'channel_iran_official',
        category: 'News',
        topics: ['iran', 'middle east'],
      );

      // 2. Diplomatic / Institutional Perspective (UN Ceasefire)
      final unDiplomacy = createSampleVideo(
        id: 'un_ceasefire',
        title: 'UN Security Council Emergency Session: Ceasefire Negotiations and Treaty',
        channelId: 'channel_un_news',
        category: 'News',
        topics: ['un', 'diplomacy', 'ceasefire', 'treaty'],
      );

      // 3. Civilian Protection / Conceptual Peace Perspective
      final peaceCivilian = createSampleVideo(
        id: 'peace_civilian',
        title: 'Civilian Protection and De-escalation: The Humanitarian Peace Framework',
        channelId: 'channel_humanitarian',
        category: 'News',
        topics: ['peace', 'humanitarian', 'de-escalation'],
      );

      // 4. Same-side pro-war video (must be excluded)
      final sameSideWar = createSampleVideo(
        id: 'same_side_war_2',
        title: 'Israel War Strategy Breakdown and Troop Deployment',
        channelId: 'channel_israel_official',
        category: 'News',
        topics: ['israel', 'war'],
      );

      final candidates = [sameSideWar, iranSpeech, unDiplomacy, peaceCivilian];

      final ranked = algorithm.rankVideosForCurrentVideoOpposite(
        israelWarSpeech,
        candidates,
      );

      final resultIds = ranked.map((s) => s.video.id).toList();

      // All 3 diverse counter-perspectives should be returned, same-side excluded
      expect(resultIds, containsAll(['iran_speech', 'un_ceasefire', 'peace_civilian']));
      expect(resultIds, isNot(contains('same_side_war_2')));
      expect(resultIds.length, equals(3));
    });
  });
}
