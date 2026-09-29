import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/algorithm/algorithm_engine.dart';
import 'package:truthworld/core/services/algorithm/algorithm_remote_config.dart';
import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/exploration_budget.dart';
import 'package:truthworld/core/services/algorithm/flip_coin_service.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/session_interest_tracker.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile_service.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

export 'package:truthworld/core/services/algorithm/algorithm_engine.dart';

class SessionEvent {
  final String videoId;
  final String category;
  final List<String> topics;
  final String channelId;
  final String type; // 'watch', 'like', 'skip', etc.
  final double watchProgress;

  SessionEvent({
    required this.videoId,
    required this.category,
    required this.channelId, required this.type, this.topics = const [],
    this.watchProgress = 0.0,
  });
}

/// Truthworld's unified personalization algorithm.
///
/// Single scoring engine used by ALL 11 recommendation surfaces.
/// Each surface uses different weight profiles but the same signal computation.
///
/// Score = Σ(Signal_i × Weight_i × SurfaceMultiplier_i) + SessionBoost - Penalties
class TruthworldAlgorithm extends GetxService with WidgetsBindingObserver {
  UserInterestProfile? _explicitProfile;
  UserInterestProfile? get _profile =>
      _explicitProfile ??
      (Get.isRegistered<UserInterestProfileService>()
          ? UserInterestProfileService.to.currentProfile
          : null);

  /// Access current active profile
  UserInterestProfile? get currentProfile => _profile;

  final SessionInterestTracker _sessionTracker = SessionInterestTracker();
  final ExplorationBudget _explorationBudget = ExplorationBudget();

  /// Per-creator exposure tracking for fair recommendation distribution.
  /// Ensures new creators get opportunities and established ones don't monopolize.
  final Map<String, int> _sessionCreatorExposure = {};

  /// Call after a video is added to the feed to track creator exposure
  void _trackCreatorExposure(String channelId) {
    _sessionCreatorExposure[channelId] =
        (_sessionCreatorExposure[channelId] ?? 0) + 1;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _sessionTracker.resetSession();
    }
  }

  // === Core Scoring Methods ===

  /// Score a single video for a specific surface
  ScoredVideo? scoreVideo(
    Video video,
    RecommendationSurface surface, {
    DiversityConfig? diversityConfig,
  }) {
    final credibilityMultiplier = _computeCredibilityGate(video);
    if (credibilityMultiplier == 0.0) {
      return null;
    }

    final config = Get.find<AlgorithmRemoteConfig>();
    final baseWeights = config.getWeightProfile(surface);
    final weights = Map<String, double>.from(baseWeights);

    // Adapt surface weights dynamically based on user's inferred cognitive archetype
    final psychology = _profile?.psychologyProfile;
    final archetype =
        psychology?.archetype ?? CognitiveArchetype.balancedInquirer;

    switch (archetype) {
      case CognitiveArchetype.analyticalDeepDiver:
        weights['knowledgeQuality'] =
            (weights['knowledgeQuality'] ?? 0.0) * 1.5;
        weights['watchCompletion'] =
            (weights['watchCompletion'] ?? 0.0) * 1.3;
        weights['twoTowerAffinity'] =
            (weights['twoTowerAffinity'] ?? 0.0) * 1.25;
        weights['trending'] = (weights['trending'] ?? 0.0) * 0.7;
      case CognitiveArchetype.curiousExplorer:
        weights['freshness'] = (weights['freshness'] ?? 0.0) * 1.4;
        weights['trending'] = (weights['trending'] ?? 0.0) * 1.3;
        weights['topicAffinity'] = (weights['topicAffinity'] ?? 0.0) * 0.85;
      case CognitiveArchetype.focusedSpecialist:
        weights['topicAffinity'] = (weights['topicAffinity'] ?? 0.0) * 1.4;
        weights['channelAffinity'] = (weights['channelAffinity'] ?? 0.0) * 1.3;
        weights['twoTowerAffinity'] =
            (weights['twoTowerAffinity'] ?? 0.0) * 1.30;
        weights['freshness'] = (weights['freshness'] ?? 0.0) * 0.8;
      case CognitiveArchetype.actionOrientedConsumer:
        weights['engagement'] = (weights['engagement'] ?? 0.0) * 1.35;
        weights['watchCompletion'] =
            (weights['watchCompletion'] ?? 0.0) * 1.25;
      case CognitiveArchetype.balancedInquirer:
        break;
    }

    return AlgorithmEngine.scoreSingleVideo(
      video: video,
      surface: surface,
      weights: weights,
      profile: _profile,
      sessionTracker: _sessionTracker,
      explorationBudget: _explorationBudget,
      sessionCreatorExposure: _sessionCreatorExposure,
      diversityConfig: diversityConfig,
    );
  }

  /// Score and rank a list of videos with diversity enforcement (synchronous).
  List<ScoredVideo> rankVideos(
    List<Video> candidates,
    RecommendationSurface surface, {
    DiversityConfig? diversityConfig,
  }) {
    final config = Get.find<AlgorithmRemoteConfig>();
    final baseWeights = config.getWeightProfile(surface);
    final task = AlgorithmRankingTask(
      candidates: candidates,
      surface: surface,
      baseWeights: Map<String, double>.from(baseWeights),
      profile: _profile,
      sessionEvents: _sessionTracker.recentEvents,
      sessionCreatorExposure: Map<String, int>.from(_sessionCreatorExposure),
      diversityConfig: diversityConfig,
    );

    final finalFeed = rankVideosWorker(task);

    for (final item in finalFeed) {
      _trackCreatorExposure(item.video.channelId);
    }

    return finalFeed;
  }

  /// Asynchronously score and rank a list of videos with diversity enforcement.
  /// Automatically offloads large candidate pools (> 15 items) to an isolate via compute()
  /// to eliminate UI thread latency and keep 120fps scrolling completely fluid.
  Future<List<ScoredVideo>> rankVideosAsync(
    List<Video> candidates,
    RecommendationSurface surface, {
    DiversityConfig? diversityConfig,
  }) async {
    if (candidates.length <= 15) {
      return rankVideos(candidates, surface, diversityConfig: diversityConfig);
    }

    final config = Get.find<AlgorithmRemoteConfig>();
    final baseWeights = config.getWeightProfile(surface);
    final task = AlgorithmRankingTask(
      candidates: candidates,
      surface: surface,
      baseWeights: Map<String, double>.from(baseWeights),
      profile: _profile,
      sessionEvents: _sessionTracker.recentEvents,
      sessionCreatorExposure: Map<String, int>.from(_sessionCreatorExposure),
      diversityConfig: diversityConfig,
    );

    final finalFeed = await compute(rankVideosWorker, task);

    for (final item in finalFeed) {
      _trackCreatorExposure(item.video.channelId);
    }

    return finalFeed;
  }

  // === Individual Signal Computations ===

  double _computeCredibilityGate(Video video) =>
      AlgorithmEngine.computeCredibilityGate(video);
  double _computeTopicAffinity(Video video) =>
      AlgorithmEngine.computeTopicAffinity(video, _profile, _sessionTracker);
  double _computeChannelAffinity(Video video) =>
      AlgorithmEngine.computeChannelAffinity(video, _profile, _sessionTracker);
  double _computeLoveAffinity(Video video) =>
      AlgorithmEngine.computeLoveAffinity(video, _profile);
  double _computeEngagementQuality(Video video) =>
      AlgorithmEngine.computeEngagementQuality(video);
  double _computeFreshness(Video video, RecommendationSurface surface) =>
      AlgorithmEngine.computeFreshness(video, surface);
  double _computeTrendingMomentum(Video video) =>
      AlgorithmEngine.computeTrendingMomentum(video);
  double _computeWatchCompletion(Video video) =>
      AlgorithmEngine.computeWatchCompletion(video, _profile);
  double _computeSessionBoost(Video video) =>
      AlgorithmEngine.computeSessionBoost(video, _sessionTracker);
  double _computePenalty(Video video) =>
      AlgorithmEngine.computePenalty(
        video,
        _profile,
        _sessionTracker,
        _explorationBudget,
      );
  double _computeKnowledgeQuality(Video video) =>
      AlgorithmEngine.computeKnowledgeQuality(video);
  double _computeCreatorFairness(Video video, DiversityConfig config) =>
      AlgorithmEngine.computeCreatorFairness(
        video,
        config,
        _sessionCreatorExposure,
      );
  List<ScoredVideo> _applyDiversity(
    List<ScoredVideo> ranked,
    DiversityConfig config,
  ) => AlgorithmEngine.applyDiversity(
    ranked,
    config,
    _profile,
    _explorationBudget,
  );
  bool _isCreatorOverExposed(
    String channelId,
    DiversityConfig config,
    int totalSlots,
  ) => AlgorithmEngine.isCreatorOverExposed(
    channelId,
    config,
    totalSlots,
    _profile,
  );

  // === Profile Management ===

  void updateProfile(UserInterestProfile profile) {
    _explicitProfile = profile;
  }

  void recordSessionEvent(SessionEvent event) {
    _sessionTracker.recordEvent(event);
  }

  /// Score and rank topics for explore
  List<Topic> rankTopics(List<Topic> topicsList) {
    final validTopics = topicsList
        .where((t) => t.isValidTopic && t.videoCount > 0)
        .toList();
    if (_profile == null || validTopics.isEmpty) return validTopics;

    final scored = validTopics.map((t) {
      var score =
          (t.followerCount * 0.4) +
          (t.videoCount * 0.2) +
          (t.trendingScore * 0.4);
      final slug = t.slug.isNotEmpty ? t.slug : t.id;

      // Followed topics boost
      if (_profile!.followedTopicSlugs.contains(slug)) {
        score *= 1.5;
      }

      // Topic affinity boost from user interest profile
      final affinity = _profile!.topicAffinities['topic:$slug'] ?? 0.0;
      score += affinity * 50.0;

      // Category match boost
      if (t.category.isNotEmpty &&
          _profile!.categoryAffinities.containsKey(t.category)) {
        score += (_profile!.categoryAffinities[t.category] ?? 0.0) * 30.0;
      }

      return MapEntry(t, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  /// Rank videos in OPPOSITE / CONTRARIAN order (for "The Other Side" Flip Coin mode)
  /// Returns ONLY videos that represent the opposite side / contrasting perspective to user's profile.
  List<ScoredVideo> rankVideosOpposite(
    List<Video> candidates,
    RecommendationSurface surface, {
    DiversityConfig? diversityConfig,
  }) {
    final scored = <ScoredVideo>[];

    for (final video in candidates) {
      if (_computeCredibilityGate(video) == 0.0) continue;

      // Compute contrast score against user's profile
      var contrastScore = 0.0;
      if (Get.isRegistered<FlipCoinService>()) {
        contrastScore = Get.find<FlipCoinService>().calculateUserContrastScore(
          video,
          _profile,
        );
      } else {
        // Fallback calculation if FlipCoinService is not registered
        final topicAffinity = _computeTopicAffinity(video);
        contrastScore = (1.0 - topicAffinity).clamp(0.0, 1.0);
        if (topicAffinity > 0.6) contrastScore = 0.0;
      }

      // STRICT FILTER: Exclude any video on the user's same side (contrastScore <= 0)
      if (contrastScore <= 0.0) {
        continue;
      }

      // Boost candidate videos in the user's Unexplored Horizon (unexplored categories and topics)
      var unexploredBoost = 0.0;
      if (_profile != null) {
        if (_profile!.isUnexploredCategory(video.category)) {
          unexploredBoost += 3.0; // High boost for unexplored category
        }
        for (final topic in video.topics) {
          final slug = topic.toLowerCase().trim();
          if (!_profile!.exploredTopicSlugs.contains(slug) &&
              !_profile!.topicAffinities.containsKey('topic:$slug')) {
            unexploredBoost += 1.0;
          }
        }
      }

      // Quality & engagement weighting: we want high-quality opposite views
      final engagement = _computeEngagementQuality(video);
      final knowledgeQuality = _computeKnowledgeQuality(video);
      final creatorFairness = diversityConfig != null
          ? _computeCreatorFairness(video, diversityConfig)
          : 0.0;

      final totalOppositeScore = (contrastScore * 10.0) +
          unexploredBoost +
          (knowledgeQuality * 3.0) +
          (engagement * 2.0) +
          creatorFairness;

      scored.add(
        ScoredVideo(
          video: video,
          score: totalOppositeScore,
          recommendationReason: RecommendationReasons.factChecked,
          recommendationExplanation: 'The Other Side (Opposite Perspective)',
          surface: surface,
        ),
      );
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    List<ScoredVideo> finalFeed;
    if (diversityConfig != null) {
      finalFeed = _applyDiversity(scored, diversityConfig);
    } else {
      finalFeed = scored;
    }

    for (final item in finalFeed) {
      _trackCreatorExposure(item.video.channelId);
    }

    return finalFeed;
  }

  /// Rank candidate videos for the "Unexplored" tab according to user behavioral
  /// personalization, psychology profiling, and latent love score prediction
  /// (content the user would love to know, but has not explored yet).
  List<ScoredVideo> rankVideosUnexplored(
    List<Video> candidates,
    RecommendationSurface surface, {
    DiversityConfig? diversityConfig,
  }) {
    final scored = <ScoredVideo>[];
    final profile = _profile;
    final psych = profile?.psychologyProfile;

    // Aggregate watched video IDs from profile and WatchHistoryService
    final watchedVideoIds = <String>{};
    if (profile != null) {
      watchedVideoIds.addAll(profile.recentlyWatchedVideoIds);
      watchedVideoIds.addAll(profile.watchProgress.keys);
    }
    if (Get.isRegistered<WatchHistoryService>()) {
      watchedVideoIds.addAll(WatchHistoryService.to.allWatchedVideoIds);
    }

    for (final video in candidates) {
      if (_computeCredibilityGate(video) == 0.0) continue;

      // Disqualify already watched videos across all tracking tiers
      if (watchedVideoIds.contains(video.id)) continue;
      if (Get.isRegistered<WatchHistoryService>() &&
          WatchHistoryService.to.isVideoWatched(video.id)) {
        continue;
      }

      // Disqualify subscribed channels or user's own channel
      if (profile != null) {
        if (profile.subscribedChannelIds.contains(video.channelId)) continue;
        if (video.channelId == profile.userId) continue;
      }

      // Check unexplored status
      final isUnexpCategory = profile?.isUnexploredCategory(video.category) ?? true;
      var unexploredTopicCount = 0;
      for (final topic in video.topics) {
        final slug = topic.toLowerCase().trim();
        if (profile == null ||
            (!profile.exploredTopicSlugs.contains(slug) &&
                !profile.topicAffinities.containsKey('topic:$slug'))) {
          unexploredTopicCount++;
        }
      }

      // Disqualify comfort-zone videos that are already deeply explored
      if (profile != null) {
        final catAffinity = profile.categoryAffinities[video.category.trim()] ?? 0.0;
        if (catAffinity > 0.45 && unexploredTopicCount == 0 && !isUnexpCategory) {
          continue;
        }
      }

      // 1. Unexplored Horizon Boost
      var unexploredBonus = 0.0;
      if (isUnexpCategory) {
        unexploredBonus += 3.0;
      }
      unexploredBonus += (unexploredTopicCount * 1.0).clamp(0.0, 3.0);

      // 2. Latent Love Score & Psychological Alignment
      final loveAffinity = _computeLoveAffinity(video);
      final knowledgeQuality = _computeKnowledgeQuality(video);
      final engagement = _computeEngagementQuality(video);
      final freshness = _computeFreshness(video, surface);

      // Archetype-specific alignment
      var archetypeBonus = 0.0;
      if (psych != null) {
        switch (psych.archetype) {
          case CognitiveArchetype.analyticalDeepDiver:
            if (video.isFactChecked) archetypeBonus += 2.0;
            if (video.trustScore >= 4.0) archetypeBonus += 1.5;
            archetypeBonus += knowledgeQuality * 3.0;
            if (video.durationValue.inSeconds >= 300) archetypeBonus += 1.0;
          case CognitiveArchetype.curiousExplorer:
            archetypeBonus += freshness * 2.5;
            archetypeBonus += isUnexpCategory ? 2.0 : 0.5;
            archetypeBonus += unexploredTopicCount * 0.8;
          case CognitiveArchetype.focusedSpecialist:
            archetypeBonus += knowledgeQuality * 2.0;
            if (video.trustScore >= 4.0) archetypeBonus += 1.0;
          case CognitiveArchetype.actionOrientedConsumer:
            archetypeBonus += engagement * 2.5;
            archetypeBonus += freshness * 1.5;
          case CognitiveArchetype.balancedInquirer:
            archetypeBonus += knowledgeQuality * 1.5;
            archetypeBonus += freshness * 1.5;
            if (video.isFactChecked) archetypeBonus += 1.0;
        }
      } else {
        // Cold start fallback
        if (video.isFactChecked) archetypeBonus += 1.5;
        if (video.trustScore >= 4.0) archetypeBonus += 1.0;
      }

      final creatorFairness = diversityConfig != null
          ? _computeCreatorFairness(video, diversityConfig)
          : 0.0;

      final totalUnexploredScore = (loveAffinity * 3.5) +
          unexploredBonus +
          archetypeBonus +
          (knowledgeQuality * 2.5) +
          (engagement * 1.5) +
          creatorFairness;

      scored.add(
        ScoredVideo(
          video: video,
          score: totalUnexploredScore,
          recommendationReason: RecommendationReasons.inYourTopics,
          recommendationExplanation: 'Unexplored Horizon (Personalized Latent Love)',
          surface: surface,
          signalBreakdown: {
            'loveAffinity': loveAffinity,
            'unexploredBonus': unexploredBonus,
            'archetypeBonus': archetypeBonus,
            'knowledgeQuality': knowledgeQuality,
            'engagement': engagement,
          },
        ),
      );
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    List<ScoredVideo> finalFeed;
    if (diversityConfig != null) {
      finalFeed = _applyDiversity(scored, diversityConfig);
    } else {
      finalFeed = scored;
    }

    for (final item in finalFeed) {
      _trackCreatorExposure(item.video.channelId);
    }

    return finalFeed;
  }

  /// Rank videos to find OPPOSITE / COUNTER-PERSPECTIVES for a currently playing video
  /// (e.g. Israel President video -> Direct Counterpart / Iran President / UN Ceasefire / Humanitarian Diplomacy)
  List<ScoredVideo> rankVideosForCurrentVideoOpposite(
    Video currentVideo,
    List<Video> candidates,
  ) {
    if (Get.isRegistered<FlipCoinService>()) {
      final flipService = Get.find<FlipCoinService>();
      final categorizedScored = <PerspectiveCategory, List<ScoredVideo>>{};

      for (final candidate in candidates) {
        // TruthWorld Credibility Engine: Independent Evidence & Fact-Check Gate
        if (_computeCredibilityGate(candidate) == 0.0) continue;

        // Flip Coin Perspective Contrast Evaluation
        final evaluation = flipService.evaluateVideoContrast(
          currentVideo,
          candidate,
        );

        // STRICT FILTER: Exclude same-side / non-contrasting videos
        if (!evaluation.qualifies) continue;

        // Evidence & Quality weighting (TruthWorld Credibility Engine)
        final knowledgeQuality = _computeKnowledgeQuality(candidate);
        final engagement = _computeEngagementQuality(candidate);

        // Clear separation: Perspective Diversity (Contrast) + Evidence Quality (Credibility)
        final totalScore = (evaluation.contrastScore * 8.0) +
            (knowledgeQuality * 4.0) +
            (engagement * 1.5);

        final scoredVideo = ScoredVideo(
          video: candidate,
          score: totalScore,
          recommendationReason: RecommendationReasons.factChecked,
          recommendationExplanation: evaluation.explanation,
          surface: RecommendationSurface.videoRelated,
        );

        categorizedScored
            .putIfAbsent(evaluation.category, () => [])
            .add(scoredVideo);
      }

      // Sort each perspective bucket by credibility & evidence quality
      for (final list in categorizedScored.values) {
        list.sort((a, b) => b.score.compareTo(a.score));
      }

      // Perspective Diversity Balancing: Round-robin across distinct perspective frames
      final finalFeed = <ScoredVideo>[];
      final seenIds = <String>{};

      // 1. Direct Debate Counterpart (highest priority if linked)
      if (categorizedScored.containsKey(PerspectiveCategory.directCounterDebate)) {
        for (final item in categorizedScored[PerspectiveCategory.directCounterDebate]!) {
          if (seenIds.add(item.video.id)) {
            finalFeed.add(item);
          }
        }
      }

      // 2. Interleave across remaining perspective categories for rich viewpoint diversity
      final remainingBuckets = [
        PerspectiveCategory.counterpartActor,
        PerspectiveCategory.diplomaticInstitutional,
        PerspectiveCategory.opposingClaim,
        PerspectiveCategory.conceptualContrast,
        PerspectiveCategory.alternativeParadigm,
      ];

      var hasMore = true;
      var round = 0;
      while (hasMore && round < 20) {
        hasMore = false;
        for (final cat in remainingBuckets) {
          final bucket = categorizedScored[cat];
          if (bucket != null && round < bucket.length) {
            final item = bucket[round];
            if (seenIds.add(item.video.id)) {
              finalFeed.add(item);
            }
            hasMore = true;
          }
        }
        round++;
      }

      return finalFeed;
    }

    return rankVideosOpposite(candidates, RecommendationSurface.videoRelated);
  }
}
