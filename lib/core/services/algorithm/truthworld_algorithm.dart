import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
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
    final archetype = psychology?.archetype ?? CognitiveArchetype.balancedInquirer;

    switch (archetype) {
      case CognitiveArchetype.analyticalDeepDiver:
        // Deep divers value knowledge quality, credibility, and watch completion
        weights['knowledgeQuality'] = (weights['knowledgeQuality'] ?? 0.0) * 1.5;
        weights['watchCompletion'] = (weights['watchCompletion'] ?? 0.0) * 1.3;
        weights['trending'] = (weights['trending'] ?? 0.0) * 0.7;
      case CognitiveArchetype.curiousExplorer:
        // Explorers value novelty, freshness, and trending discovery
        weights['freshness'] = (weights['freshness'] ?? 0.0) * 1.4;
        weights['trending'] = (weights['trending'] ?? 0.0) * 1.3;
        weights['topicAffinity'] = (weights['topicAffinity'] ?? 0.0) * 0.85;
      case CognitiveArchetype.focusedSpecialist:
        // Specialists value high topic and channel consistency
        weights['topicAffinity'] = (weights['topicAffinity'] ?? 0.0) * 1.4;
        weights['channelAffinity'] = (weights['channelAffinity'] ?? 0.0) * 1.3;
        weights['freshness'] = (weights['freshness'] ?? 0.0) * 0.8;
      case CognitiveArchetype.actionOrientedConsumer:
        // Action-oriented consumers value engagement quality and watch completion
        weights['engagement'] = (weights['engagement'] ?? 0.0) * 1.35;
        weights['watchCompletion'] = (weights['watchCompletion'] ?? 0.0) * 1.25;
      case CognitiveArchetype.balancedInquirer:
        // Standard balanced distribution
        break;
    }

    final topicAffinity = _computeTopicAffinity(video);
    final channelAffinity = _computeChannelAffinity(video);
    final engagementQuality = _computeEngagementQuality(video);
    final freshness = _computeFreshness(video, surface);
    final trendingMomentum = _computeTrendingMomentum(video);
    final watchCompletion = _computeWatchCompletion(video);
    final sessionBoost = _computeSessionBoost(video);
    final penalty = _computePenalty(video);
    final knowledgeQuality = _computeKnowledgeQuality(video);
    final loveAffinity = _computeLoveAffinity(video);
    final loveBoost = loveAffinity * 2.5;
    final creatorFairness = diversityConfig != null
        ? _computeCreatorFairness(video, diversityConfig)
        : 0.0;

    final rawScore =
        (topicAffinity * (weights['topicAffinity'] ?? 0.0)) +
        (channelAffinity * (weights['channelAffinity'] ?? 0.0)) +
        (engagementQuality * (weights['engagement'] ?? 0.0)) +
        (freshness * (weights['freshness'] ?? 0.0)) +
        (trendingMomentum * (weights['trending'] ?? 0.0)) +
        (watchCompletion * (weights['watchCompletion'] ?? 0.0)) +
        (knowledgeQuality * (weights['knowledgeQuality'] ?? 0.0)) +
        loveBoost +
        creatorFairness;

    // Apply session boost and penalties
    var finalScore =
        rawScore +
        (sessionBoost * (weights['sessionBoost'] ?? 0.0)) -
        (penalty * (weights['penalty'] ?? 0.0));

    finalScore = max(0.0, finalScore * credibilityMultiplier);

    if (finalScore == 0.0) return null;

    final breakdown = {
      'topicAffinity': topicAffinity * (weights['topicAffinity'] ?? 0.0),
      'channelAffinity': channelAffinity * (weights['channelAffinity'] ?? 0.0),
      'engagement': engagementQuality * (weights['engagement'] ?? 0.0),
      'freshness': freshness * (weights['freshness'] ?? 0.0),
      'trending': trendingMomentum * (weights['trending'] ?? 0.0),
      'watchCompletion': watchCompletion * (weights['watchCompletion'] ?? 0.0),
      'knowledgeQuality':
          knowledgeQuality * (weights['knowledgeQuality'] ?? 0.0),
      'loveAffinity': loveBoost,
      'sessionBoost': sessionBoost * (weights['sessionBoost'] ?? 0.0),
      'penalty': penalty * (weights['penalty'] ?? 0.0),
      'creatorFairness': creatorFairness,
    };

    return ScoredVideo(
      video: video,
      score: finalScore,
      signalBreakdown: breakdown,
      surface: surface,
      explanation: RecommendationExplanation(
        reason: 'Recommended for you',
        confidence: min(1.0, finalScore / 10.0),
        signalBreakdown: breakdown,
      ),
    );
  }

  /// Score and rank a list of videos with diversity enforcement
  List<ScoredVideo> rankVideos(
    List<Video> candidates,
    RecommendationSurface surface, {
    DiversityConfig? diversityConfig,
  }) {
    final scored = <ScoredVideo>[];

    for (final video in candidates) {
      final scoredVideo = scoreVideo(
        video,
        surface,
        diversityConfig: diversityConfig,
      );
      if (scoredVideo != null) {
        scored.add(scoredVideo);
      }
    }

    // Sort by score descending
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

  // === Individual Signal Computations ===

  /// Topic Affinity: Combines long-term interests + session interests + interest graph
  double _computeTopicAffinity(Video video) {
    if (_profile == null) return 0.0;

    final longTermTopicAffinity = _profile!.getCombinedTopicAffinity(
      video.topics.cast<String>(),
    );
    final longTermCategoryAffinity =
        _profile!.categoryAffinities[video.category] ?? 0.0;
    final double longTermScore = max(longTermTopicAffinity, longTermCategoryAffinity);

    final sessionAffinity = _sessionTracker.getSessionTopicAffinity(
      video.topics.cast<String>(),
    );

    // Session interests have 2x multiplier
    return min(longTermScore + (sessionAffinity * 2.0), 1.0);
  }

  /// Channel Affinity: Subscription + watch frequency + session recency + channel exploration
  double _computeChannelAffinity(Video video) {
    if (_profile == null) return 0.0;

    if (_profile!.subscribedChannelIds.contains(video.channelId)) {
      return 1.0;
    }

    if (_sessionTracker.getRecentlyWatchedChannels().contains(
      video.channelId,
    )) {
      return 0.8;
    }

    if (_profile!.channelExploreCounts.containsKey(video.channelId)) {
      final explores = _profile!.channelExploreCounts[video.channelId]!;
      if (explores >= 3) return 0.7;
      if (explores >= 1) return 0.55;
    } else if (_profile!.discoveredChannelIds.contains(video.channelId)) {
      return 0.45;
    }

    if (_profile!.recentlyLikedVideoIds.contains(video.id)) {
      return 0.4; // Indirect indication
    }

    return 0.0;
  }

  /// Love Affinity: Multi-signal score identifying content the user genuinely loves
  /// based on searches, topic exploration, channel discovery, watch completion, and likes.
  double _computeLoveAffinity(Video video) {
    if (_profile == null) return 0.0;
    return _profile!.psychologyProfile.calculateLoveScore(
      category: video.category,
      topics: video.topics.cast<String>(),
      channelId: video.channelId,
    );
  }

  /// Engagement Quality: Like ratio, comments, shares, normalized
  double _computeEngagementQuality(Video video) {
    final likes = video.likeCount;
    final dislikes = video.dislikeCount;
    final views = video.viewCount == 0 ? 1 : video.viewCount; // avoid div by 0

    if (views == 0) return 0.5; // Neutral for new videos

    final likeRatio = likes / (likes + dislikes + 1);
    final viewLikeRatio = likes / views;

    return min((likeRatio * 0.7) + (viewLikeRatio * 10 * 0.3), 1.0);
  }

  /// Freshness: Exponential decay, surface-specific half-life
  double _computeFreshness(Video video, RecommendationSurface surface) {
    final createdAt = (video.createdAt as dynamic).toDate();
    final ageHours = DateTime.now().difference(createdAt).inHours.toDouble();

    var halfLife = 168.0; // default 1 week
    if (surface == RecommendationSurface.trending) halfLife = 48.0;
    if (surface == RecommendationSurface.shortsFeed) halfLife = 72.0;

    return exp(-ageHours / halfLife);
  }

  /// Trending Momentum: View velocity smoothed by publication recency
  double _computeTrendingMomentum(Video video) {
    final views = max(0, video.viewCount > 0 ? video.viewCount : video.views);
    if (views == 0) return 0.2;

    DateTime? createdAt;
    try {
      createdAt = (video.createdAt as dynamic).toDate();
    } catch (_) {
      createdAt = null;
    }

    final ageHours = createdAt != null
        ? max(0.5, DateTime.now().difference(createdAt).inMinutes / 60.0)
        : 24.0;

    // Continuous velocity: views per hour (with Laplace smoothing +2h)
    final velocity = views / (ageHours + 2.0);

    // Continuous log curve normalized across 0.2 to 1.0
    final score = (log(velocity + 1.0) / log(10000.0)).clamp(0.2, 1.0);
    return score;
  }

  /// Watch Completion: Completion rate derived from user history and profile telemetry
  double _computeWatchCompletion(Video video) {
    if (_profile != null) {
      // 1. Direct watch history progress for this specific video if previously watched/started
      if (_profile!.watchProgress.containsKey(video.id)) {
        final progress = _profile!.watchProgress[video.id] ?? 0.0;
        if (progress > 0.0) {
          return progress.clamp(0.0, 1.0);
        }
      }

      // 2. User's overall average completion rate as baseline engagement expectation
      if (_profile!.avgWatchCompletion > 0.0) {
        return _profile!.avgWatchCompletion.clamp(0.1, 1.0);
      }
    }

    // Baseline fallback if user engagement telemetry is unavailable
    return 0.5;
  }

  /// Session Boost: Current session interest match (HIGH weight)
  double _computeSessionBoost(Video video) {
    if (_sessionTracker.currentSessionDominantCategory == video.category) {
      return 10.0;
    }

    for (final topic in video.topics) {
      if (_sessionTracker.currentSessionDominantTopics.contains(
        topic,
      )) {
        return 8.0;
      }
    }
    return 0.0;
  }

  /// Penalty: Already watched, disliked, not-interested, novelty, negative feedback
  double _computePenalty(Video video) {
    if (_profile == null) return 0.0;

    var penalty = 0.0;

    // Watched logic
    if (_profile!.recentlyWatchedVideoIds.contains(video.id)) {
      final progress = _profile!.watchProgress[video.id] ?? 0.0;
      if (progress > 0.8) {
        penalty += 0.8;
      } else if (progress < 0.5) {
        penalty += 0.3;
      }
    }

    // Dislikes & Negative Signals
    if (_profile!.recentlyDislikedVideoIds.contains(video.id)) {
      penalty += 1.0;
    }
    if (_profile!.notInterestedVideoIds.contains(video.id)) {
      penalty += 1.0;
    }

    penalty += _profile!.getNegativeSignalStrength(
      video.id,
      video.category,
      video.channelId,
    );

    // Novelty Penalty from Exploration Budget (don't repeat same sub-topic)
    penalty += _explorationBudget.getNoveltyPenalty(
      video,
      _sessionTracker.recentEvents,
    );

    return min(penalty, 1.0);
  }

  /// Credibility Gate: Returns 0.0 if video fails credibility check
  /// This is an ELIGIBILITY GATE, not a small bonus
  ///
  /// v12.1 FIX: Distinguish between "unscored" (trustScore == 0, not yet fact-checked or score deprecated in v12)
  /// and "genuinely dangerous" (trustScore < 1.0 after fact-checking).
  /// Unscored videos get neutral treatment (1.0×) instead of being hard-gated.
  double _computeCredibilityGate(Video video) {
    final score = video.trustScore;

    // Unscored or pending verification: treat as neutral baseline (1.0)
    // In v12+, fact checking verifies claims but does not produce a composite numeric score
    if (score == 0.0) return 1.0;

    if (score >= 4.0) return 1.2; // High credibility → 20% boost
    if (score >= 3.0) return 1.1; // Good credibility → 10% boost
    if (score >= 2.0) return 1.0; // Medium → neutral
    if (score >= 1.0) return 0.6; // Low / developing evidence → soft modifier
    return 0.3; // Contested or limited evidence → soft modifier (preserves perspective existence)
  }

  /// Computes a knowledge quality score as a weighted composite of 8 sub-signals.
  /// This is Truthworld's competitive moat: optimizing for knowledge quality,
  /// not just watch time.
  double _computeKnowledgeQuality(Video video) {
    var score = 0.0;

    // 1. Evidence quality: does the video cite sources?
    final sourceCount = video.sourceLinks?.length ?? 0;
    final evidenceQuality = min(1.0, sourceCount * 0.25); // 4+ sources = max
    score += evidenceQuality * 0.15;

    // 2. Source diversity: sources from different domains
    score += min(0.1, sourceCount * 0.02);

    // 3. Fact-check confidence: trustScore normalized
    final factCheckConfidence = video.trustScore / 5.0;
    score += factCheckConfidence * 0.20;

    // 4. Primary sources: has the video been fact-checked at all?
    if (video.isFactChecked) score += 0.15;

    // 5. Expert consensus: verified channel + high trust score
    if (video.isVerified && video.trustScore >= 3.5) score += 0.10;

    // 6. Recency of verification
    // Use trustScore as proxy — higher = more recently verified
    score += min(0.05, video.trustScore * 0.01);

    // 7. Counter-arguments available (coin battle pair)
    if (video.coinBattlePairVideoId != null &&
        video.coinBattlePairVideoId!.isNotEmpty) {
      score += 0.10;
    }

    // 8. Transparency: video has description with sources
    final hasDescription = video.description.length > 100;
    if (hasDescription) score += 0.05;

    return min(1.0, score);
  }

  double _computeCreatorFairness(Video video, DiversityConfig config) {
    final channelId = video.channelId;
    final currentExposure = _sessionCreatorExposure[channelId] ?? 0;

    // Small creator boost: channels with low historical view counts
    final avgViews = video.viewCount > 0 ? video.viewCount : 100;
    var fairnessScore = 0.0;

    if (avgViews < 1000) {
      fairnessScore +=
          0.3 * config.smallCreatorBoostFactor; // New creator boost
    } else if (avgViews < 10000) {
      fairnessScore += 0.1 * config.smallCreatorBoostFactor;
    }

    // Over-exposure penalty
    if (currentExposure >= 3) {
      fairnessScore -= min(0.5, (currentExposure - 2) * 0.15);
    }

    return fairnessScore;
  }

  /// Call after a video is added to the feed to track creator exposure
  void _trackCreatorExposure(String channelId) {
    _sessionCreatorExposure[channelId] =
        (_sessionCreatorExposure[channelId] ?? 0) + 1;
  }

  // === Diversity & Fairness ===

  /// Apply diversity rules + creator exposure budget + exploration insertion
  List<ScoredVideo> _applyDiversity(
    List<ScoredVideo> ranked,
    DiversityConfig config,
  ) {
    if (ranked.isEmpty) return [];

    final finalFeed = <ScoredVideo>[];
    final deferred = <ScoredVideo>[];
    final creatorCounts = <String, int>{};
    String? lastChannelId;
    var consecutiveChannelCount = 0;

    for (final item in ranked) {
      final channelId = item.video.channelId;

      // Enforce max consecutive same channel
      if (channelId == lastChannelId) {
        consecutiveChannelCount++;
        if (consecutiveChannelCount > config.maxConsecutiveSameChannel) {
          deferred.add(item); // Defer rather than discard to preserve catalog availability
          continue;
        }
      } else {
        lastChannelId = channelId;
        consecutiveChannelCount = 1;
      }

      // Creator exposure budget (e.g. max 18% per creator in large pools)
      if (_isCreatorOverExposed(channelId, config, ranked.length)) {
        deferred.add(item);
        continue;
      }

      creatorCounts[channelId] = (creatorCounts[channelId] ?? 0) + 1;
      finalFeed.add(item);
    }

    // Zero Catalog Drop: append deferred items so all valid platform videos remain discoverable
    if (deferred.isNotEmpty) {
      final existingIds = finalFeed.map((e) => e.video.id).toSet();
      for (final item in deferred) {
        if (!existingIds.contains(item.video.id)) {
          finalFeed.add(item);
          existingIds.add(item.video.id);
        }
      }
    }

    return _explorationBudget.insertExplorationCandidates(finalFeed, config);
  }

  /// Check if a creator has exceeded their exposure budget
  bool _isCreatorOverExposed(
    String channelId,
    DiversityConfig config,
    int totalSlots,
  ) {
    if (_profile == null) return false;
    // Don't enforce creator exposure cap if the total candidate pool is small (< 15)
    // to prevent small catalogs or single-channel categories from starving.
    if (totalSlots < 15) return false;

    final exposureCount = _profile!.channelExposureCounts[channelId] ?? 0;
    final maxExposure = (totalSlots * config.maxCreatorExposurePercent).ceil();

    return exposureCount >= maxExposure;
  }

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
