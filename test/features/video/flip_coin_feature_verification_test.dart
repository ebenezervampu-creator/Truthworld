import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/algorithm/algorithm_remote_config.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_recommendations_controller.dart';

Video buildTestVideo({
  required String id,
  required String title,
  required String channelId,
  String channelName = 'Truth Channel',
  String category = 'Technology',
  List<String> topics = const [],
  List<String> tags = const [],
  String? coinBattlePairVideoId,
  String? coinBattleStance,
  bool isFactChecked = true,
  String description = 'Video description',
}) {
  return Video(
    id: id,
    title: title,
    description: description,
    thumbnailUrl: 'https://example.com/$id.jpg',
    ownerId: 'owner_$channelId',
    channelId: channelId,
    channelName: channelName,
    category: category,
    tags: tags,
    topics: topics,
    coinBattlePairVideoId: coinBattlePairVideoId,
    coinBattleStance: coinBattleStance,
    isFactChecked: isFactChecked,
    status: VideoStatus.ready,
    visibility: 'public',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Full-Fledged Flip Coin Feature Verification Suite', () {
    late FlipCoinService flipService;
    late TruthworldAlgorithm algorithm;
    late Video basePlayingVideo;

    setUp(() {
      Get.reset();
      Get.put(AlgorithmRemoteConfig());
      flipService = Get.put(FlipCoinService());
      algorithm = Get.put(TruthworldAlgorithm());

      basePlayingVideo = buildTestVideo(
        id: 'playing_vid_1',
        title: 'The Rapid AI Revolution and Acceleration',
        channelId: 'channel_tech_future',
        channelName: 'Future Tech',
        topics: ['ai', 'technology'],
        tags: ['acceleration', 'growth'],
        coinBattleStance: 'Pro-Acceleration',
        coinBattlePairVideoId: 'counter_pair_vid',
      );
    });

    tearDown(Get.reset);

    // =========================================================================
    // 1. RECOMMENDATIONS TAB BAR ORDER & DYNAMIC PILLS
    // =========================================================================
    test('1. Verified: Recommendation tab bar hides "Flip Coin" tab when 0 flip videos available', () {
      final videoWithoutCounterpart = buildTestVideo(
        id: 'no_counterpart_vid',
        title: 'Neutral Cooking Video',
        channelId: 'chan_cooking',
        channelName: 'Chef Corner',
      );

      final controller = VideoRecommendationsController(
        getVideo: () => videoWithoutCounterpart,
      );

      expect(controller.hasFlipCoinVideos, isFalse);
      final filters = controller.recommendationFilters;

      expect(filters, contains('All'));
      expect(filters, contains('From Chef Corner'));
      expect(
        filters,
        isNot(contains('Flip Coin')),
        reason: 'Flip Coin tab MUST NOT be shown when there are 0 flip videos available',
      );
    });

    test('2. Verified: Recommendation tab bar shows "From channel" BEFORE "Flip Coin" when at least one video exists', () {
      final controller = VideoRecommendationsController(
        getVideo: () => basePlayingVideo,
      );

      // basePlayingVideo has coinBattlePairVideoId set, so hasFlipCoinVideos is true
      expect(controller.hasFlipCoinVideos, isTrue);

      final filters = controller.recommendationFilters;

      expect(filters, contains('All'));
      expect(filters, contains('From Future Tech'));
      expect(filters, contains('Flip Coin'));

      final fromChannelIndex = filters.indexOf('From Future Tech');
      final flipCoinIndex = filters.indexOf('Flip Coin');

      expect(fromChannelIndex, isNot(equals(-1)));
      expect(flipCoinIndex, isNot(equals(-1)));
      expect(
        fromChannelIndex,
        lessThan(flipCoinIndex),
        reason: '"From channel" tab MUST be placed before "Flip Coin"',
      );
    });

    test('2b. Verified: Tag tabs after Flip Coin are only shown when at least one matching video exists', () {
      final controller = VideoRecommendationsController(
        getVideo: () => basePlayingVideo, // tags: ['acceleration', 'growth']
      );

      // Initially 0 matching videos in recommendations/cache -> tags should NOT appear
      var filters = controller.recommendationFilters;
      expect(filters, contains('From Future Tech'));
      expect(filters, contains('Flip Coin'));
      expect(filters, isNot(contains('acceleration')), reason: 'Must not show tag tab when 0 matching videos exist');
      expect(filters, isNot(contains('growth')), reason: 'Must not show tag tab when 0 matching videos exist');

      // Now add a matching video for 'acceleration'
      controller.recommendedVideos.add(
        buildTestVideo(
          id: 'v_accel',
          title: 'Acceleration Dynamics',
          channelId: 'other_chan',
          tags: ['acceleration'],
        ),
      );

      filters = controller.recommendationFilters;
      expect(filters, contains('acceleration'), reason: 'Tag tab MUST be shown when at least one matching video exists');
      expect(filters, isNot(contains('growth')), reason: 'Growth tag MUST remain hidden when 0 videos exist');

      // Tag tab appears AFTER Flip Coin
      final flipCoinIndex = filters.indexOf('Flip Coin');
      final accelIndex = filters.indexOf('acceleration');
      expect(flipCoinIndex, isNot(equals(-1)));
      expect(accelIndex, isNot(equals(-1)));
      expect(flipCoinIndex, lessThan(accelIndex), reason: 'Tag tab MUST appear after Flip Coin');
    });

    test('3. Verified: Tab order preserved when navigated from playlist or topic', () {
      final sampleTopic = Topic(
        id: 'topic_ai',
        title: 'Artificial Intelligence',
        slug: 'ai',
        handle: 'ai',
        handleLowercase: 'ai',
        description: 'AI topic',
        category: 'Technology',
        thumbnailUrl: '',
        videoCount: 12,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final samplePlaylist = PlaylistModel(
        id: 'pl_tech',
        ownerId: 'u1',
        channelId: 'c1',
        playlistName: 'Curated AI',
        videoIds: ['playing_vid_1'],
      );

      final controller = VideoRecommendationsController(
        getVideo: () => basePlayingVideo,
        getCurrentTopic: () => sampleTopic,
        getCurrentPlaylist: () => samplePlaylist,
        getNavigatedFromTopic: () => true,
        getNavigatedFromPlaylist: () => true,
      );

      final filters = controller.recommendationFilters;
      final topicIndex = filters.indexOf('Artificial Intelligence');
      final fromChannelIndex = filters.indexOf('From Future Tech');
      final flipCoinIndex = filters.indexOf('Flip Coin');

      expect(topicIndex, lessThan(fromChannelIndex));
      expect(fromChannelIndex, lessThan(flipCoinIndex));
    });

    // =========================================================================
    // 2. VIDEO SCREEN CONTROLLER FLIP TOGGLING & STATE SYNC
    // =========================================================================
    test('3. Verified: Toggling Flip Coin activates flipped state and tracks surface interaction', () {
      expect(flipService.isVideoFlipped(basePlayingVideo.id), isFalse);

      flipService.toggleVideoFlip(basePlayingVideo.id);
      expect(flipService.isVideoFlipped(basePlayingVideo.id), isTrue);

      flipService.toggleVideoFlip(basePlayingVideo.id);
      expect(flipService.isVideoFlipped(basePlayingVideo.id), isFalse);
    });

    // =========================================================================
    // 3. PERSPECTIVE CONTRAST EVALUATION & STRICT SAME-SIDE DISQUALIFICATION
    // =========================================================================
    test('4. Verified: Same video and same channel are strictly disqualified (contrast score = 0.0)', () {
      final sameVideo = basePlayingVideo;
      final sameChannelOtherVideo = buildTestVideo(
        id: 'other_vid_same_chan',
        title: 'AI Safety Guide',
        channelId: basePlayingVideo.channelId,
      );

      final scoreSameVid = flipService.calculateContrastScore(basePlayingVideo, sameVideo);
      final scoreSameChan = flipService.calculateContrastScore(basePlayingVideo, sameChannelOtherVideo);

      expect(scoreSameVid, equals(0.0));
      expect(scoreSameChan, equals(0.0));
    });

    test('5. Verified: Coin Battle paired counter-video receives maximum contrast priority score', () {
      final directCounterPair = buildTestVideo(
        id: 'counter_pair_vid',
        title: 'Why Unchecked AI Leads to Catastrophe: The Safety Stance',
        channelId: 'channel_safety_org',
        coinBattlePairVideoId: basePlayingVideo.id,
        coinBattleStance: 'Pro-Safety',
      );

      final evaluation = flipService.evaluateVideoContrast(basePlayingVideo, directCounterPair);

      expect(evaluation.isDirectDebatePair, isTrue);
      expect(evaluation.contrastScore, greaterThanOrEqualTo(2.0));
      expect(evaluation.category, equals(PerspectiveCategory.directCounterDebate));
      expect(evaluation.explanation, contains('Direct Coin Battle'));
    });

    test('6. Verified: Conceptual contrast matches opposing paradigms (War ↔ Peace, Acceleration ↔ Safety)', () {
      final safetyVideo = buildTestVideo(
        id: 'safety_vid',
        title: 'The Ethical Precaution and AI Safety Standards',
        channelId: 'channel_independent_ethics',
        topics: ['safety', 'ethics', 'regulation'],
        tags: ['safety', 'precaution'],
      );

      final evaluation = flipService.evaluateVideoContrast(basePlayingVideo, safetyVideo);

      expect(evaluation.qualifies, isTrue);
      expect(evaluation.contrastScore, greaterThan(0.0));
      expect(evaluation.explanation, contains('Conceptual Contrast'));
    });

    test('7. Verified: Geopolitical Counterpart Actor & Diplomatic UN perspectives are surfaced', () {
      final israelWarVideo = buildTestVideo(
        id: 'israel_war',
        title: 'Israel Military Campaign and Operation in Middle East',
        channelId: 'chan_israel_news',
        category: 'News',
        topics: ['israel', 'war'],
      );

      final iranDiplomacyVideo = buildTestVideo(
        id: 'iran_un_speech',
        title: 'Iran & UN Emergency Session: Ceasefire Treaty and Diplomacy',
        channelId: 'chan_un_diplomacy',
        category: 'News',
        topics: ['iran', 'un', 'ceasefire', 'diplomacy'],
      );

      final sameSideWarVideo = buildTestVideo(
        id: 'israel_troops',
        title: 'Troop Deployment Updates in the Conflict',
        channelId: 'chan_israel_news',
        category: 'News',
        topics: ['israel', 'war'],
      );

      final candidates = [sameSideWarVideo, iranDiplomacyVideo];

      final ranked = algorithm.rankVideosForCurrentVideoOpposite(
        israelWarVideo,
        candidates,
      );

      final resultIds = ranked.map((s) => s.video.id).toList();

      expect(resultIds, contains('iran_un_speech'));
      expect(resultIds, isNot(contains('israel_troops')), reason: 'Same-side / same-channel must be excluded');
    });

    // =========================================================================
    // 4. RANKING ROUND-ROBIN PERSPECTIVE DIVERSITY
    // =========================================================================
    test('8. Verified: rankVideosForCurrentVideoOpposite prioritizes direct pairs then round-robins categories', () {
      final candidateSameSide = buildTestVideo(
        id: 'same_side_pro',
        title: 'More Acceleration and AI Growth',
        channelId: 'chan_generic_ai',
        topics: ['ai'],
      );

      final candidateDirectPair = buildTestVideo(
        id: 'counter_pair_vid',
        title: 'Direct Counter Debate: Why AI Acceleration Must Pause',
        channelId: 'chan_ethics_council',
        coinBattlePairVideoId: basePlayingVideo.id,
        coinBattleStance: 'Pro-Safety',
      );

      final candidateConceptual = buildTestVideo(
        id: 'safety_conceptual',
        title: 'AI Safety Protocols and Human Workforce Dignity',
        channelId: 'chan_labor_safety',
        topics: ['safety', 'regulation'],
      );

      final ranked = algorithm.rankVideosForCurrentVideoOpposite(
        basePlayingVideo,
        [candidateSameSide, candidateDirectPair, candidateConceptual],
      );

      expect(ranked.isNotEmpty, isTrue);
      expect(ranked.first.video.id, equals('counter_pair_vid'), reason: 'Direct counter-debate pair must be #1');
      expect(ranked.any((s) => s.video.id == 'safety_conceptual'), isTrue);
      expect(ranked.any((s) => s.video.id == 'same_side_pro'), isFalse);
    });

    // =========================================================================
    // 5. CLEAN FLIPPED FEED (NO ADS, NO COMMUNITY POSTS IN FLIP COIN)
    // =========================================================================
    test('9. Verified: recommendedItems in Flip Coin mode only returns clean video candidates without ads or posts', () {
      final controller = VideoRecommendationsController(
        getVideo: () => basePlayingVideo,
      );

      final oppositeVid = buildTestVideo(
        id: 'opp_vid',
        title: 'AI Safety Framework',
        channelId: 'chan_safety',
      );
      controller.recommendedVideos.add(oppositeVid);

      final post = CommunityPostModel(
        id: 'post_1',
        title: 'Promotional Post',
        description: 'Check out our merch',
        ownerId: 'u1',
        channelId: 'c1',
        channelName: 'Channel',
        channelImage: '',
        uploadedAt: DateTime.now(),
      );
      controller.communityPosts.add(post);

      // Normal Mode: includes mixed content (videos + community posts)
      controller.selectedRecommendationFilter.value = 'All';
      final normalItems = controller.recommendedItems;
      expect(normalItems.any((item) => item is CommunityPostModel), isTrue);

      // Flip Coin Mode: ONLY pure video list, zero interleaved community posts or ads
      controller.selectedRecommendationFilter.value = 'Flip Coin';
      final flippedItems = controller.recommendedItems;
      expect(flippedItems.every((item) => item is Video), isTrue);
      expect(flippedItems.any((item) => item is CommunityPostModel), isFalse);
    });

    // =========================================================================
    // 6. SEARCH QUERY CONTRARIAN INVERSION
    // =========================================================================
    test('10. Verified: flipSearchQuery produces accurate opposite search viewpoints', () {
      expect(
        flipService.flipSearchQuery('risks of ai'),
        equals('breakthroughs and benefits of ai'),
      );
      expect(
        flipService.flipSearchQuery('advantages of electric cars'),
        equals('disadvantages of electric cars'),
      );
      expect(
        flipService.flipSearchQuery('pro'),
        equals('anti'),
      );
    });
  });
}
