import 'dart:math';

import 'package:truthworld/core/services/algorithm/diversity_config.dart';
import 'package:truthworld/core/services/algorithm/exploration_budget.dart';
import 'package:truthworld/core/services/algorithm/scored_video.dart';
import 'package:truthworld/core/services/algorithm/session_interest_tracker.dart';
import 'package:truthworld/core/services/algorithm/truthworld_algorithm.dart';
import 'package:truthworld/core/services/algorithm/user_interest_profile.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Task payload for background isolate ranking execution.
class AlgorithmRankingTask {
  final List<Video> candidates;
  final RecommendationSurface surface;
  final Map<String, double> baseWeights;
  final UserInterestProfile? profile;
  final List<SessionEvent> sessionEvents;
  final Map<String, int> sessionCreatorExposure;
  final DiversityConfig? diversityConfig;

  const AlgorithmRankingTask({
    required this.candidates,
    required this.surface,
    required this.baseWeights,
    required this.sessionEvents,
    required this.sessionCreatorExposure,
    this.profile,
    this.diversityConfig,
  });
}

/// Top-level worker function safe for compute() / Isolate.run().
List<ScoredVideo> rankVideosWorker(AlgorithmRankingTask task) {
  final sessionTracker = SessionInterestTracker(task.sessionEvents);
  final explorationBudget = ExplorationBudget();
  final weights = Map<String, double>.from(task.baseWeights);

  // Adapt surface weights dynamically based on user's inferred cognitive archetype
  final psychology = task.profile?.psychologyProfile;
  final archetype =
      psychology?.archetype ?? CognitiveArchetype.balancedInquirer;

  switch (archetype) {
    case CognitiveArchetype.analyticalDeepDiver:
      weights['knowledgeQuality'] =
          (weights['knowledgeQuality'] ?? 0.0) * 1.5;
      weights['watchCompletion'] =
          (weights['watchCompletion'] ?? 0.0) * 1.3;
      weights['trending'] = (weights['trending'] ?? 0.0) * 0.7;
    case CognitiveArchetype.curiousExplorer:
      weights['freshness'] = (weights['freshness'] ?? 0.0) * 1.4;
      weights['trending'] = (weights['trending'] ?? 0.0) * 1.3;
      weights['topicAffinity'] = (weights['topicAffinity'] ?? 0.0) * 0.85;
    case CognitiveArchetype.focusedSpecialist:
      weights['topicAffinity'] = (weights['topicAffinity'] ?? 0.0) * 1.4;
      weights['channelAffinity'] = (weights['channelAffinity'] ?? 0.0) * 1.3;
      weights['freshness'] = (weights['freshness'] ?? 0.0) * 0.8;
    case CognitiveArchetype.actionOrientedConsumer:
      weights['engagement'] = (weights['engagement'] ?? 0.0) * 1.35;
      weights['watchCompletion'] =
          (weights['watchCompletion'] ?? 0.0) * 1.25;
    case CognitiveArchetype.balancedInquirer:
      break;
  }

  final scored = <ScoredVideo>[];

  for (final video in task.candidates) {
    final scoredVideo = AlgorithmEngine.scoreSingleVideo(
      video: video,
      surface: task.surface,
      weights: weights,
      profile: task.profile,
      sessionTracker: sessionTracker,
      explorationBudget: explorationBudget,
      sessionCreatorExposure: task.sessionCreatorExposure,
      diversityConfig: task.diversityConfig,
    );
    if (scoredVideo != null) {
      scored.add(scoredVideo);
    }
  }

  scored.sort((a, b) => b.score.compareTo(a.score));

  if (task.diversityConfig != null) {
    return AlgorithmEngine.applyDiversity(
      scored,
      task.diversityConfig!,
      task.profile,
      explorationBudget,
    );
  }
  return scored;
}

/// Pure, isolate-safe mathematical scoring and diversity engine.
/// Decoupled from GetX and runtime singletons for safe background execution.
class AlgorithmEngine {
  static ScoredVideo? scoreSingleVideo({
    required Video video,
    required RecommendationSurface surface,
    required Map<String, double> weights,
    required SessionInterestTracker sessionTracker,
    required ExplorationBudget explorationBudget,
    required Map<String, int> sessionCreatorExposure,
    UserInterestProfile? profile,
    DiversityConfig? diversityConfig,
  }) {
    final credibilityMultiplier = computeCredibilityGate(video);
    if (credibilityMultiplier == 0.0) {
      return null;
    }

    final topicAffinity = computeTopicAffinity(video, profile, sessionTracker);
    final channelAffinity = computeChannelAffinity(video, profile, sessionTracker);
    final engagementQuality = computeEngagementQuality(video);
    final freshness = computeFreshness(video, surface);
    final trendingMomentum = computeTrendingMomentum(video);
    final watchCompletion = computeWatchCompletion(video, profile);
    final sessionBoost = computeSessionBoost(video, sessionTracker);
    final penalty =
        computePenalty(video, profile, sessionTracker, explorationBudget);
    final knowledgeQuality = computeKnowledgeQuality(video);
    final loveAffinity = computeLoveAffinity(video, profile);
    final loveBoost = loveAffinity * 2.5;
    final creatorFairness = diversityConfig != null
        ? computeCreatorFairness(video, diversityConfig, sessionCreatorExposure)
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

  /// Credibility Gate: Returns 0.0 if video fails credibility check
  static double computeCredibilityGate(Video video) {
    final score = video.trustScore;
    if (score == 0.0) return 1.0;
    if (score >= 4.0) return 1.2;
    if (score >= 3.0) return 1.1;
    if (score >= 2.0) return 1.0;
    if (score >= 1.0) return 0.6;
    return 0.3;
  }

  /// Topic Affinity: Combines long-term interests + session interests + interest graph
  static double computeTopicAffinity(
    Video video,
    UserInterestProfile? profile,
    SessionInterestTracker sessionTracker,
  ) {
    if (profile == null) return 0.0;

    final longTermTopicAffinity = profile.getCombinedTopicAffinity(
      video.topics.cast<String>(),
    );
    final longTermCategoryAffinity =
        profile.categoryAffinities[video.category] ?? 0.0;
    final double longTermScore =
        max(longTermTopicAffinity, longTermCategoryAffinity);

    final sessionAffinity = sessionTracker.getSessionTopicAffinity(
      video.topics.cast<String>(),
    );

    return min(longTermScore + (sessionAffinity * 2.0), 1.0);
  }

  /// Channel Affinity: Subscription + watch frequency + session recency + channel exploration
  static double computeChannelAffinity(
    Video video,
    UserInterestProfile? profile,
    SessionInterestTracker sessionTracker,
  ) {
    if (profile == null) return 0.0;

    if (profile.subscribedChannelIds.contains(video.channelId)) {
      return 1.0;
    }

    if (sessionTracker.getRecentlyWatchedChannels().contains(video.channelId)) {
      return 0.8;
    }

    if (profile.channelExploreCounts.containsKey(video.channelId)) {
      final explores = profile.channelExploreCounts[video.channelId]!;
      if (explores >= 3) return 0.7;
      if (explores >= 1) return 0.55;
    } else if (profile.discoveredChannelIds.contains(video.channelId)) {
      return 0.45;
    }

    if (profile.recentlyLikedVideoIds.contains(video.id)) {
      return 0.4;
    }

    return 0.0;
  }

  /// Love Affinity: Multi-signal score identifying content the user genuinely loves
  static double computeLoveAffinity(
    Video video,
    UserInterestProfile? profile,
  ) {
    if (profile == null) return 0.0;
    return profile.psychologyProfile.calculateLoveScore(
      category: video.category,
      topics: video.topics.cast<String>(),
      channelId: video.channelId,
    );
  }

  /// Engagement Quality: Like ratio, comments, views normalized
  static double computeEngagementQuality(Video video) {
    final likes = video.likeCount;
    final dislikes = video.dislikeCount;
    final views = video.viewCount == 0 ? 1 : video.viewCount;

    if (views == 0) return 0.5;

    final likeRatio = likes / (likes + dislikes + 1);
    final viewLikeRatio = likes / views;

    return min((likeRatio * 0.7) + (viewLikeRatio * 10 * 0.3), 1.0);
  }

  /// Freshness: Exponential decay, surface-specific half-life
  static double computeFreshness(
    Video video,
    RecommendationSurface surface,
  ) {
    final createdAt = (video.createdAt as dynamic).toDate();
    final ageHours = DateTime.now().difference(createdAt).inHours.toDouble();

    var halfLife = 168.0;
    if (surface == RecommendationSurface.trending) halfLife = 48.0;
    if (surface == RecommendationSurface.shortsFeed) halfLife = 72.0;

    return exp(-ageHours / halfLife);
  }

  /// Trending Momentum: View velocity smoothed by publication recency
  static double computeTrendingMomentum(Video video) {
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

    final velocity = views / (ageHours + 2.0);
    final score = (log(velocity + 1.0) / log(10000.0)).clamp(0.2, 1.0);
    return score;
  }

  /// Watch Completion: Completion rate derived from user history and profile telemetry
  static double computeWatchCompletion(
    Video video,
    UserInterestProfile? profile,
  ) {
    if (profile != null) {
      if (profile.watchProgress.containsKey(video.id)) {
        final progress = profile.watchProgress[video.id] ?? 0.0;
        if (progress > 0.0) {
          return progress.clamp(0.0, 1.0);
        }
      }

      if (profile.avgWatchCompletion > 0.0) {
        return profile.avgWatchCompletion.clamp(0.1, 1.0);
      }
    }

    return 0.5;
  }

  /// Session Boost: Current session interest match
  static double computeSessionBoost(
    Video video,
    SessionInterestTracker sessionTracker,
  ) {
    if (sessionTracker.currentSessionDominantCategory == video.category) {
      return 10.0;
    }

    for (final topic in video.topics) {
      if (sessionTracker.currentSessionDominantTopics.contains(topic)) {
        return 8.0;
      }
    }
    return 0.0;
  }

  /// Penalty: Already watched, disliked, not-interested, novelty, negative feedback
  static double computePenalty(
    Video video,
    UserInterestProfile? profile,
    SessionInterestTracker sessionTracker,
    ExplorationBudget explorationBudget,
  ) {
    if (profile == null) return 0.0;

    var penalty = 0.0;

    if (profile.recentlyWatchedVideoIds.contains(video.id)) {
      final progress = profile.watchProgress[video.id] ?? 0.0;
      if (progress > 0.8) {
        penalty += 0.8;
      } else if (progress < 0.5) {
        penalty += 0.3;
      }
    }

    if (profile.recentlyDislikedVideoIds.contains(video.id)) {
      penalty += 1.0;
    }
    if (profile.notInterestedVideoIds.contains(video.id)) {
      penalty += 1.0;
    }

    penalty += profile.getNegativeSignalStrength(
      video.id,
      video.category,
      video.channelId,
    );

    penalty += explorationBudget.getNoveltyPenalty(
      video,
      sessionTracker.recentEvents,
    );

    return min(penalty, 1.0);
  }

  /// Computes a knowledge quality score as a weighted composite of sub-signals
  static double computeKnowledgeQuality(Video video) {
    var score = 0.0;

    final sourceCount = video.sourceLinks?.length ?? 0;
    final evidenceQuality = min(1.0, sourceCount * 0.25);
    score += evidenceQuality * 0.15;

    score += min(0.1, sourceCount * 0.02);

    final factCheckConfidence = video.trustScore / 5.0;
    score += factCheckConfidence * 0.20;

    if (video.isFactChecked) score += 0.15;
    if (video.isVerified && video.trustScore >= 3.5) score += 0.10;
    score += min(0.05, video.trustScore * 0.01);

    if (video.coinBattlePairVideoId != null &&
        video.coinBattlePairVideoId!.isNotEmpty) {
      score += 0.10;
    }

    final hasDescription = video.description.length > 100;
    if (hasDescription) score += 0.05;

    return min(1.0, score);
  }

  /// Creator fairness calculation
  static double computeCreatorFairness(
    Video video,
    DiversityConfig config,
    Map<String, int> sessionCreatorExposure,
  ) {
    final channelId = video.channelId;
    final currentExposure = sessionCreatorExposure[channelId] ?? 0;

    final avgViews = video.viewCount > 0 ? video.viewCount : 100;
    var fairnessScore = 0.0;

    if (avgViews < 1000) {
      fairnessScore += 0.3 * config.smallCreatorBoostFactor;
    } else if (avgViews < 10000) {
      fairnessScore += 0.1 * config.smallCreatorBoostFactor;
    }

    if (currentExposure >= 3) {
      fairnessScore -= min(0.5, (currentExposure - 2) * 0.15);
    }

    return fairnessScore;
  }

  /// Apply diversity rules + creator exposure budget + exploration insertion
  static List<ScoredVideo> applyDiversity(
    List<ScoredVideo> ranked,
    DiversityConfig config,
    UserInterestProfile? profile,
    ExplorationBudget explorationBudget,
  ) {
    if (ranked.isEmpty) return [];

    final finalFeed = <ScoredVideo>[];
    final deferred = <ScoredVideo>[];
    final creatorCounts = <String, int>{};
    String? lastChannelId;
    var consecutiveChannelCount = 0;

    for (final item in ranked) {
      final channelId = item.video.channelId;

      if (channelId == lastChannelId) {
        consecutiveChannelCount++;
        if (consecutiveChannelCount > config.maxConsecutiveSameChannel) {
          deferred.add(item);
          continue;
        }
      } else {
        lastChannelId = channelId;
        consecutiveChannelCount = 1;
      }

      if (isCreatorOverExposed(channelId, config, ranked.length, profile)) {
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

    return explorationBudget.insertExplorationCandidates(finalFeed, config);
  }

  /// Check if a creator has exceeded their exposure budget
  static bool isCreatorOverExposed(
    String channelId,
    DiversityConfig config,
    int totalSlots,
    UserInterestProfile? profile,
  ) {
    if (profile == null) return false;
    if (totalSlots < 15) return false;

    final exposureCount = profile.channelExposureCounts[channelId] ?? 0;
    final maxExposure = (totalSlots * config.maxCreatorExposurePercent).ceil();

    return exposureCount >= maxExposure;
  }
}
