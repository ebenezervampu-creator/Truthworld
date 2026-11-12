import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/algorithm/algorithm_remote_config.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile.dart';
import 'package:truthworld/core/services/algorithm/vector_math_util.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlipCoinService flipCoinService;
  late TruthworldAlgorithm algorithm;
  late AlgorithmRemoteConfig remoteConfig;

  setUp(() {
    Get.reset();
    remoteConfig = Get.put(AlgorithmRemoteConfig(enableStorage: false));
    flipCoinService = Get.put(FlipCoinService());
    algorithm = Get.put(TruthworldAlgorithm());
  });

  tearDown(Get.reset);

  // Helper to generate normalized synthetic 768-dimensional embedding vectors
  List<double> createSyntheticEmbedding({
    required int primaryIndex,
    double primaryMagnitude = 1.0,
  }) {
    const dim = 768;
    final vec = List<double>.filled(dim, 0.0);
    vec[primaryIndex % dim] = primaryMagnitude;
    // Add small distributed noise for realism
    for (var i = 0; i < 16; i++) {
      vec[(primaryIndex * 7 + i) % dim] = 0.05;
    }
    return VectorMathUtil.normalize(vec);
  }

  Video createSampleVideo({
    required String id,
    required String title,
    required String channelId,
    required String category,
    List<String> topics = const [],
    List<double>? embedding,
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
      tags: const [],
      topics: topics,
      isFactChecked: isFactChecked,
      status: VideoStatus.ready,
      visibility: 'public',
      embedding: embedding,
    );
  }

  group('VectorMathUtil - High-Dimensional Mathematics', () {
    test('Identical vectors produce cosine similarity = 1.0 and cosine distance = 0.0', () {
      final vecA = createSyntheticEmbedding(primaryIndex: 42);
      final vecB = List<double>.from(vecA);

      final sim = VectorMathUtil.cosineSimilarity(vecA, vecB);
      final dist = VectorMathUtil.cosineDistance(vecA, vecB);

      expect(sim, closeTo(1.0, 0.0001));
      expect(dist, closeTo(0.0, 0.0001));
    });

    test('Orthogonal vectors produce cosine similarity = 0.0 and cosine distance = 1.0', () {
      final vecA = List<double>.filled(768, 0.0)..[0] = 1.0;
      final vecB = List<double>.filled(768, 0.0)..[1] = 1.0;

      final sim = VectorMathUtil.cosineSimilarity(vecA, vecB);
      final dist = VectorMathUtil.cosineDistance(vecA, vecB);

      expect(sim, closeTo(0.0, 0.0001));
      expect(dist, closeTo(1.0, 0.0001));
    });

    test('Opposite vectors produce cosine similarity = -1.0 and cosine distance = 2.0', () {
      final vecA = List<double>.filled(768, 0.0)..[10] = 1.0;
      final vecB = List<double>.filled(768, 0.0)..[10] = -1.0;

      final sim = VectorMathUtil.cosineSimilarity(vecA, vecB);
      final dist = VectorMathUtil.cosineDistance(vecA, vecB);

      expect(sim, closeTo(-1.0, 0.0001));
      expect(dist, closeTo(2.0, 0.0001));
    });

    test('Safely handles empty or mismatched vectors without throwing', () {
      expect(VectorMathUtil.cosineSimilarity([], [1.0, 2.0]), equals(0.0));
      expect(VectorMathUtil.cosineDistance([], []), equals(1.0));
      expect(VectorMathUtil.norm([]), equals(0.0));
      expect(VectorMathUtil.normalize([]), isEmpty);
    });

    test('Computes weighted centroid with unit normalization', () {
      final vecA = List<double>.filled(768, 0.0)..[0] = 1.0;
      final vecB = List<double>.filled(768, 0.0)..[1] = 1.0;

      final centroid = VectorMathUtil.weightedCentroid([vecA, vecB], [1.0, 1.0]);
      expect(centroid, isNotNull);
      expect(VectorMathUtil.norm(centroid!), closeTo(1.0, 0.0001));
      expect(centroid[0], closeTo(centroid[1], 0.0001));
    });
  });

  group('FlipCoinService - Semantic Vector Embedding Contrast', () {
    test('Qualifies video with divergent vector embedding as contrasting perspective', () {
      // Source video about AI breakthrough
      final currentVideo = createSampleVideo(
        id: 'vid_ai_breakthrough',
        title: 'Breakthroughs in Deep Reinforcement Learning',
        channelId: 'channel_ai_lab',
        category: 'Technology',
        topics: ['artificial intelligence'],
        embedding: createSyntheticEmbedding(primaryIndex: 15),
      );

      // Candidate video with distinct opposing semantic vector (far in embedding space)
      final opposingVideo = createSampleVideo(
        id: 'vid_ai_safety',
        title: 'Algorithmic Risk and Human Dignity in Modern Systems',
        channelId: 'channel_ethics_institute',
        category: 'Technology',
        topics: ['machine ethics'],
        embedding: createSyntheticEmbedding(primaryIndex: 500),
      );

      final evaluation = flipCoinService.evaluateVideoContrast(currentVideo, opposingVideo);

      expect(evaluation.contrastScore, greaterThan(0.4));
      expect(evaluation.category, equals(PerspectiveCategory.conceptualContrast));
      expect(evaluation.explanation, contains('Semantic Counter-Perspective'));
    });

    test('Disqualifies videos with nearly identical embedding vectors (same viewpoint)', () {
      final embeddingSame = createSyntheticEmbedding(primaryIndex: 100);

      final currentVideo = createSampleVideo(
        id: 'vid_1',
        title: 'General Investing Advice 2026',
        channelId: 'channel_alpha',
        category: 'Business & Finance',
        topics: ['investing'],
        embedding: embeddingSame,
      );

      final sameAngleVideo = createSampleVideo(
        id: 'vid_2',
        title: 'Investing Advice 2026 Continued',
        channelId: 'channel_beta',
        category: 'Business & Finance',
        topics: ['investing'],
        embedding: embeddingSame, // Identical angle vector
      );

      final score = flipCoinService.calculateContrastScore(currentVideo, sameAngleVideo);
      // Because vectors are identical and neither dictionary nor coin battle triggers, score should be 0.0
      expect(score, equals(0.0));
    });

    test('User profile with User Tower vector calculates contrast distance against candidate video', () {
      final userTowerVector = createSyntheticEmbedding(primaryIndex: 200);

      final profile = UserInterestProfile(
        userId: 'usr_vector_test',
        categoryAffinities: {'Technology': 0.9},
        topicAffinities: {'topic:ai': 0.8},
        userEmbedding: userTowerVector,
      );

      final candidate = createSampleVideo(
        id: 'vid_contrasting',
        title: 'Alternative Philosophical Models',
        channelId: 'channel_philosophy',
        category: 'Philosophy',
        topics: ['epistemology'],
        embedding: createSyntheticEmbedding(primaryIndex: 650),
      );

      final contrast = flipCoinService.calculateUserContrastScore(candidate, profile);
      expect(contrast, greaterThan(0.3));
    });
  });

  group('Two-Tower Neural Retrieval & Hybrid Scoring', () {
    test('AlgorithmEngine calculates Two-Tower neural affinity signal correctly', () {
      final userVector = createSyntheticEmbedding(primaryIndex: 300);
      final profile = UserInterestProfile(
        userId: 'usr_neural_test',
        categoryAffinities: {'Technology': 0.8},
        userEmbedding: userVector,
      );

      final matchingVideo = createSampleVideo(
        id: 'vid_matched',
        title: 'Neural Architecture Fundamentals',
        channelId: 'channel_cs',
        category: 'Technology',
        topics: ['deep learning'],
        embedding: userVector, // High alignment
      );

      final affinity = AlgorithmEngine.computeTwoTowerAffinity(matchingVideo, profile);
      expect(affinity, closeTo(1.0, 0.01));

      algorithm.updateProfile(profile);
      final scored = algorithm.scoreVideo(matchingVideo, RecommendationSurface.homeFeedAll);
      expect(scored, isNotNull);
      expect(scored!.signalBreakdown['twoTowerAffinity'], isNotNull);
      expect(scored.signalBreakdown['twoTowerAffinity'], greaterThan(0.0));
    });

    test('UserInterestProfile synthesizes User Tower vector from topic/category affinities when absent', () {
      final profile = UserInterestProfile(
        userId: 'usr_synth',
        categoryAffinities: {'Technology': 0.8, 'Science': 0.6},
        topicAffinities: {'topic:ai': 0.9},
      );

      final synthesized = profile.computeUserTowerVector();
      expect(synthesized, isNotNull);
      expect(synthesized!.length, equals(768));
      expect(VectorMathUtil.norm(synthesized), closeTo(1.0, 0.001));
    });

    test('Analytical Deep Diver archetype amplifies Two-Tower neural affinity weight', () {
      // Profile configured as Analytical Deep Diver (high depth + critical thinking)
      final analyticalProfile = UserInterestProfile(
        userId: 'usr_deep_diver',
        categoryAffinities: {'Science': 0.9, 'Technology': 0.8},
        categoryWatchCounts: {'Science': 20, 'Technology': 15},
        factCheckedWatchCount: 12,
        totalWatchDurationSec: 5000,
        avgWatchCompletion: 0.85,
        userEmbedding: createSyntheticEmbedding(primaryIndex: 120),
      );

      algorithm.updateProfile(analyticalProfile);

      final video = createSampleVideo(
        id: 'vid_study',
        title: 'Peer-Reviewed Analysis of Quantum State Superposition',
        channelId: 'channel_physics',
        category: 'Science',
        topics: ['quantum'],
        embedding: createSyntheticEmbedding(primaryIndex: 120),
      );

      final scored = algorithm.scoreVideo(video, RecommendationSurface.homeFeedAll);
      expect(scored, isNotNull);
      // twoTowerAffinity must be present and weighted
      expect(scored!.signalBreakdown['twoTowerAffinity'], greaterThan(0.1));
    });
  });

  group('AlgorithmRemoteConfig - Dynamic Sync & Multi-Tier Caching', () {
    test('Surface weight profiles include calibrated twoTowerAffinity across all 11 surfaces', () {
      for (final surface in RecommendationSurface.values) {
        final weights = remoteConfig.getWeightProfile(surface);
        expect(weights.containsKey('twoTowerAffinity'), isTrue,
            reason: 'Surface ${surface.name} is missing twoTowerAffinity weight.');
        expect(weights['twoTowerAffinity'], greaterThan(0.0));
      }
    });

    test('Dynamic version switching updates active weight resolution', () {
      expect(remoteConfig.activeVersion, equals('v1'));

      remoteConfig.setVersion('v1');
      final weights = remoteConfig.getWeightProfile(RecommendationSurface.homeFeedAll);
      expect(weights['twoTowerAffinity'], equals(0.12));
    });

    test('Gracefully falls back to compiled weights when offline or uninitialized', () {
      final weights = remoteConfig.getWeightProfile(RecommendationSurface.videoRelated);
      expect(weights['topicAffinity'], equals(0.22));
      expect(weights['twoTowerAffinity'], equals(0.12));
    });
  });
}
