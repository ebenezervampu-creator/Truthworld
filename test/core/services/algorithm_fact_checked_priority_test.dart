import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/app_categories.dart';
import 'package:truthworld/core/services/ai/models/ai_search_intent.dart';
import 'package:truthworld/core/services/ai/search/ai_search_scoring_engine.dart';
import 'package:truthworld/core/services/algorithm/algorithm_engine.dart';
import 'package:truthworld/core/services/algorithm/algorithm_remote_config.dart';
import 'package:truthworld/core/services/algorithm/exploration_budget.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/session_interest_tracker.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/data/services/engine/search_result_ranker.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TruthworldAlgorithm algorithm;
  late AlgorithmRemoteConfig remoteConfig;

  setUp(() {
    Get.reset();
    remoteConfig = Get.put(AlgorithmRemoteConfig());
    algorithm = Get.put(TruthworldAlgorithm());
  });

  tearDown(Get.reset);

  Video createTestVideo({
    required String id,
    required String title,
    required String category,
    required bool isFactChecked,
  }) {
    return Video(
      id: id,
      title: title,
      description: 'Description for $title',
      thumbnailUrl: 'https://example.com/thumb_$id.jpg',
      ownerId: 'owner_$id',
      channelId: 'ch_$id',
      channelName: 'Channel $id',
      category: category,
      tags: const [],
      isFactChecked: isFactChecked,
      status: VideoStatus.ready,
      visibility: 'public',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    );
  }

  group('Algorithm - 10 Fact-Checking Categories Priority', () {
    test('Verifies AppCategories has exactly 10 fact-checking categories', () {
      expect(AppCategories.factCheckingCategories.length, 10);
      const expected10 = [
        'Business',
        'History',
        'News',
        'Education',
        'Science',
        'Technology',
        'Finance',
        'Health',
        'Documentary',
        'Fitness',
      ];
      for (final cat in expected10) {
        expect(AppCategories.isFactCheckRelevant(cat), isTrue,
            reason: '$cat should be recognized as fact-check relevant');
      }
      expect(AppCategories.isFactCheckRelevant('Music'), isFalse);
      expect(AppCategories.isFactCheckRelevant('Entertainment'), isFalse);
      expect(AppCategories.isFactCheckRelevant('Comedy'), isFalse);
    });

    test('Homefeeds (homeFeedAll & homeFeedCategory) push fact-checked videos over normal videos', () {
      for (final category in AppCategories.factCheckingCategories) {
        final normalVideo = createTestVideo(
          id: 'normal_${category.toLowerCase()}',
          title: 'Normal Unverified $category',
          category: category,
          isFactChecked: false,
        );

        final factCheckedVideo = createTestVideo(
          id: 'verified_${category.toLowerCase()}',
          title: 'Verified Fact-Checked $category',
          category: category,
          isFactChecked: true,
        );

        // Test homeFeedAll
        final rankedAll = algorithm.rankVideos(
          [normalVideo, factCheckedVideo],
          RecommendationSurface.homeFeedAll,
        );
        expect(rankedAll.first.video.id, factCheckedVideo.id,
            reason: 'Fact-checked video must rank #1 in homeFeedAll for $category');
        expect(rankedAll.first.recommendationReason, RecommendationReasons.factChecked);

        // Test homeFeedCategory
        final rankedCategory = algorithm.rankVideos(
          [normalVideo, factCheckedVideo],
          RecommendationSurface.homeFeedCategory,
        );
        expect(rankedCategory.first.video.id, factCheckedVideo.id,
            reason: 'Fact-checked video must rank #1 in homeFeedCategory for $category');
      }
    });

    test('Video Screen Related Feeds (videoRelated & autoplayNext) push fact-checked videos', () {
      for (final category in ['Technology', 'Science', 'Health', 'Finance', 'News']) {
        final normalVideo = createTestVideo(
          id: 'normal_${category.toLowerCase()}',
          title: 'Normal Unverified $category',
          category: category,
          isFactChecked: false,
        );

        final factCheckedVideo = createTestVideo(
          id: 'verified_${category.toLowerCase()}',
          title: 'Verified Fact-Checked $category',
          category: category,
          isFactChecked: true,
        );

        // Test videoRelated
        final rankedRelated = algorithm.rankVideos(
          [normalVideo, factCheckedVideo],
          RecommendationSurface.videoRelated,
        );
        expect(rankedRelated.first.video.id, factCheckedVideo.id,
            reason: 'Fact-checked video must rank #1 in videoRelated for $category');

        // Test autoplayNext
        final rankedAutoplay = algorithm.rankVideos(
          [normalVideo, factCheckedVideo],
          RecommendationSurface.autoplayNext,
        );
        expect(rankedAutoplay.first.video.id, factCheckedVideo.id,
            reason: 'Fact-checked video must rank #1 in autoplayNext for $category');
      }
    });

    test('General categories (e.g., Music, Entertainment) do not receive factCheckCategoryBoost', () {
      final music1 = createTestVideo(
        id: 'music_1',
        title: 'Song 1',
        category: 'Music',
        isFactChecked: false,
      );
      final music2 = createTestVideo(
        id: 'music_2',
        title: 'Song 2',
        category: 'Music',
        isFactChecked: true,
      );

      final scored1 = AlgorithmEngine.scoreSingleVideo(
        video: music1,
        surface: RecommendationSurface.homeFeedAll,
        weights: remoteConfig.getWeightProfile(RecommendationSurface.homeFeedAll),
        sessionTracker: SessionInterestTracker(),
        explorationBudget: ExplorationBudget(),
        sessionCreatorExposure: {},
      );

      final scored2 = AlgorithmEngine.scoreSingleVideo(
        video: music2,
        surface: RecommendationSurface.homeFeedAll,
        weights: remoteConfig.getWeightProfile(RecommendationSurface.homeFeedAll),
        sessionTracker: SessionInterestTracker(),
        explorationBudget: ExplorationBudget(),
        sessionCreatorExposure: {},
      );

      expect(scored1?.signalBreakdown['factCheckCategoryBoost'], 0.0);
      expect(scored2?.signalBreakdown['factCheckCategoryBoost'], 0.0);
    });

    test('Searchfeeds in searchpage (SearchResultRanker) push fact-checked videos over normal videos', () {
      const ranker = SearchResultRanker();

      for (final category in AppCategories.factCheckingCategories) {
        final normalResult = SearchResult(
          id: 'search_normal_${category.toLowerCase()}',
          title: 'Deep Analysis of $category Trends',
          thumbnail: 'https://example.com/thumb1.jpg',
          views: 1000,
          channelName: 'General Creator',
          channelImage: 'https://example.com/ch1.jpg',
          createdAt: Timestamp.now(),
          type: ResultType.video,
          category: category,
          isFactChecked: false,
        );

        final factCheckedResult = SearchResult(
          id: 'search_verified_${category.toLowerCase()}',
          title: 'Deep Analysis of $category Trends',
          thumbnail: 'https://example.com/thumb2.jpg',
          views: 1000,
          channelName: 'Verified Authority',
          channelImage: 'https://example.com/ch2.jpg',
          createdAt: Timestamp.now(),
          type: ResultType.video,
          category: category,
          isFactChecked: true,
        );

        final query = '$category Trends';
        final ranked = ranker.rankAndSortResults([normalResult, factCheckedResult], query);

        expect(ranked.first.id, factCheckedResult.id,
            reason: 'Fact-checked search result must rank ahead of unverified result for $category');
        expect(factCheckedResult.relevanceScore, greaterThan(normalResult.relevanceScore + 40.0),
            reason: 'Fact-checked video must receive priority boost in search relevance');
      }
    });

    test('AiSearchScoringEngine pushes fact-checked videos over normal videos in fact-checking categories', () {
      const aiEngine = AiSearchScoringEngine();
      final intent = AiSearchIntent(
        rawQuery: 'latest medical breakthroughs',
        cleanKeywords: ['breakthroughs'],
        detectedCategory: 'Health',
        resultMode: SearchResultMode.ranked,
      );

      final normalHealth = SearchResult(
        id: 'ai_normal_health',
        title: 'Latest Medical Breakthroughs Today',
        thumbnail: 'https://example.com/th1.jpg',
        views: 500,
        channelName: 'Health Daily',
        channelImage: 'https://example.com/ch1.jpg',
        createdAt: Timestamp.now(),
        type: ResultType.video,
        category: 'Health',
        isFactChecked: false,
      );

      final factCheckedHealth = SearchResult(
        id: 'ai_verified_health',
        title: 'Latest Medical Breakthroughs Today',
        thumbnail: 'https://example.com/th2.jpg',
        views: 500,
        channelName: 'Health Daily',
        channelImage: 'https://example.com/ch1.jpg',
        createdAt: Timestamp.now(),
        type: ResultType.video,
        category: 'Health',
        isFactChecked: true,
      );

      final scoreNormal = aiEngine.scoreSearchResult(normalHealth, intent);
      final scoreVerified = aiEngine.scoreSearchResult(factCheckedHealth, intent);

      expect(scoreVerified, greaterThan(scoreNormal + 50.0),
          reason: 'Verified fact-checked health video must score substantially higher than unverified');
    });

    test('SearchResult serialization preserves isFactChecked', () {
      final original = SearchResult(
        id: 'sr_123',
        title: 'Quantum Computing Explained',
        thumbnail: 'https://example.com/qc.jpg',
        views: 2500,
        channelName: 'Tech Physics',
        channelImage: 'https://example.com/tp.jpg',
        createdAt: Timestamp.now(),
        type: ResultType.video,
        category: 'Technology',
        isFactChecked: true,
      );

      final map = original.toMap();
      expect(map['isFactChecked'], isTrue);

      final reconstructed = SearchResult.fromMap(map);
      expect(reconstructed.id, original.id);
      expect(reconstructed.category, 'Technology');
      expect(reconstructed.isFactChecked, isTrue);
    });
  });
}
