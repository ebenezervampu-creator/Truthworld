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
  UserInterestProfile? _profile;
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
    final weights = config.getWeightProfile(surface);

    final topicAffinity = _computeTopicAffinity(video);
    final channelAffinity = _computeChannelAffinity(video);
    final engagementQuality = _computeEngagementQuality(video);
    final freshness = _computeFreshness(video, surface);
    final trendingMomentum = _computeTrendingMomentum(video);
    final watchCompletion = _computeWatchCompletion(video);
    final sessionBoost = _computeSessionBoost(video);
    final penalty = _computePenalty(video);
    final knowledgeQuality = _computeKnowledgeQuality(video);
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

  /// Channel Affinity: Subscription + watch frequency + session recency
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

    if (_profile!.recentlyLikedVideoIds.contains(video.id)) {
      return 0.4; // Slightly indirect indication
    }

    const watchCount = 0;
    // Approximation for 'watched 3+' or 'watched 1-2'
    // Assuming watch count tracking by channel is needed, for now use base logic.
    // We mock the count since we don't have full history object mapping
    if (watchCount >= 3) return 0.6;
    if (watchCount > 0) return 0.3;

    return 0.0;
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

  /// Trending Momentum: View velocity, like velocity
  double _computeTrendingMomentum(Video video) {
    // Simplified placeholder for velocity logic
    final views = video.viewCount;
    if (views > 100000) return 1.0;
    if (views > 10000) return 0.8;
    if (views > 1000) return 0.5;
    return 0.2;
  }

  /// Watch Completion: Average completion rate
  double _computeWatchCompletion(Video video) {
    // Mocked from video properties if available, otherwise neutral
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
  /// v12.1 FIX: Distinguish between "unscored" (trustScore == 0, not yet fact-checked)
  /// and "genuinely dangerous" (trustScore < 1.0 after fact-checking).
  /// Unscored videos get neutral treatment (1.0×) instead of being hard-gated.
  double _computeCredibilityGate(Video video) {
    final score = video.trustScore;

    // Unscored / pending verification: treat as neutral (not penalized, not boosted)
    // A trustScore of 0.0 with isFactChecked == false means scoring hasn't run yet.
    if (score == 0.0 && !video.isFactChecked) return 1.0;

    if (score >= 4.0) return 1.2; // High credibility → 20% boost
    if (score >= 3.0) return 1.1; // Good credibility → 10% boost
    if (score >= 2.0) return 1.0; // Medium → neutral
    if (score >= 1.0) return 0.3; // Low → 70% suppression
    return 0.0; // Very low (scored & fact-checked) → hard gate
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
    final finalFeed = <ScoredVideo>[];
    final creatorCounts = <String, int>{};
    String? lastChannelId;
    var consecutiveChannelCount = 0;

    for (final item in ranked) {
      final channelId = item.video.channelId;

      // Enforce max consecutive same channel
      if (channelId == lastChannelId) {
        consecutiveChannelCount++;
        if (consecutiveChannelCount > config.maxConsecutiveSameChannel) {
          continue; // Skip this one for diversity
        }
      } else {
        lastChannelId = channelId;
        consecutiveChannelCount = 1;
      }

      // Creator exposure budget (max 18% per creator)
      if (_isCreatorOverExposed(channelId, config, ranked.length)) {
        continue;
      }

      creatorCounts[channelId] = (creatorCounts[channelId] ?? 0) + 1;
      finalFeed.add(item);
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

    final exposureCount = _profile!.channelExposureCounts[channelId] ?? 0;
    final maxExposure = (totalSlots * config.maxCreatorExposurePercent).ceil();

    return exposureCount >= maxExposure;
  }

  // === Profile Management ===

  void updateProfile(UserInterestProfile profile) {
    _profile = profile;
  }

  void recordSessionEvent(SessionEvent event) {
    _sessionTracker.recordEvent(event);
  }

  /// Score and rank topics for explore
  List<Topic> rankTopics(List<Topic> topicsList) {
    if (_profile == null || topicsList.isEmpty) return topicsList;

    final scored = topicsList.map((t) {
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
  /// Prioritizes content outside or opposite to user's usual interest profile.
  List<ScoredVideo> rankVideosOpposite(
    List<Video> candidates,
    RecommendationSurface surface, {
    DiversityConfig? diversityConfig,
  }) {
    final scored = <ScoredVideo>[];

    for (final video in candidates) {
      if (_computeCredibilityGate(video) == 0.0) continue;

      // Invert topic affinity: videos in user's NON-top categories score HIGHER
      final topicAffinity = _computeTopicAffinity(video);
      final oppositeScore = (1.0 - topicAffinity) * 10.0;

      // High quality/engagement still matters (we want QUALITY opposite views)
      final engagement = _computeEngagementQuality(video);
      final totalOppositeScore = (oppositeScore * 0.7) + (engagement * 3.0);

      scored.add(
        ScoredVideo(
          video: video,
          score: totalOppositeScore,
          recommendationReason: RecommendationReasons.inYourTopics,
          recommendationExplanation: 'The Other Side (Opposite Perspective)',
          surface: surface,
        ),
      );
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }

  /// Rank videos to find OPPOSITE PERSPECTIVE for a currently playing video
  /// (e.g. Iran President video -> Israel President / Opposing diplomatic views)
  List<ScoredVideo> rankVideosForCurrentVideoOpposite(
    Video currentVideo,
    List<Video> candidates,
  ) {
    if (Get.isRegistered<FlipCoinService>()) {
      final flipService = Get.find<FlipCoinService>();
      final scored = candidates
          .map((candidate) {
            final contrastScore = flipService.calculateContrastScore(
              currentVideo,
              candidate,
            );
            final engagement = _computeEngagementQuality(candidate);
            final totalScore = (contrastScore * 10.0) + (engagement * 2.0);

            return ScoredVideo(
              video: candidate,
              score: totalScore,
              recommendationReason: RecommendationReasons.factChecked,
              recommendationExplanation:
                  'Opposite Perspective to current video',
              surface: RecommendationSurface.videoRelated,
            );
          })
          .where((s) => s.score > 0)
          .toList();

      scored.sort((a, b) => b.score.compareTo(a.score));
      return scored;
    }

    return rankVideosOpposite(candidates, RecommendationSurface.videoRelated);
  }
}
