import 'dart:math';
import 'package:truthworld/features/video/data/models/video.dart';
import 'scored_video.dart';
import 'diversity_config.dart';

/// Manages the exploration budget for recommendation diversity.
/// Ensures users discover new topics and creators they haven't seen before.
///
/// Design: 90-95% of recommendations are interest-based, 5-10% are exploratory.
class ExplorationBudget {
  static const double defaultExplorationRate = 0.08; // 8%

  /// Calculate novelty penalty for repeated sub-topic recommendations
  /// (e.g. if user watched 3 AI News videos, penalize AI News #4)
  double getNoveltyPenalty(Video video, List<dynamic> recentEvents) {
    if (recentEvents.isEmpty) return 0.0;

    // Count consecutive same-category events (from most recent)
    int consecutiveSameCategory = 0;
    for (final event in recentEvents.reversed) {
      // Handle both SessionEvent types
      final eventCategory = (event is Map) ? event['category'] : event.category;
      if (eventCategory == video.category) {
        consecutiveSameCategory++;
      } else {
        break;
      }
    }

    // Exponential category penalty
    final categoryPenalty = consecutiveSameCategory >= 2
        ? min(0.8, pow(consecutiveSameCategory - 1, 1.5) * 0.05)
        : 0.0;

    // Topic-level penalty (stricter - look at last 5 events)
    final videoTopics = video.topics;
    int topicOverlap = 0;
    for (final event in recentEvents.take(5)) {
      final eventTopics = (event is Map)
          ? (event['topics'] as List?)
          : event.topics;
      if (eventTopics != null &&
          eventTopics.any((t) => videoTopics.contains(t))) {
        topicOverlap++;
      }
    }
    final topicPenalty = topicOverlap >= 3
        ? min(0.6, (topicOverlap - 2) * 0.2)
        : 0.0;

    return min(0.8, categoryPenalty + topicPenalty);
  }

  /// Returns 0.0-0.4 bonus for content from unexplored areas.
  /// Positive exploration performs better than only penalizing repetition.
  double calculateDiscoveryBonus({
    required Video video,
    required Set<String> userKnownCategories,
    required Set<String> userFollowedTopics,
    required Map<String, double> channelAffinities,
  }) {
    double bonus = 0.0;

    // 1. New category the user hasn't explored
    if (!userKnownCategories.contains(video.category)) {
      bonus += 0.2;
    }

    // 2. New creator the user hasn't watched
    if (!channelAffinities.containsKey(video.channelId)) {
      bonus += 0.1;
    }

    // 3. Cross-topic bridging: video spans topics user knows + topics they don't
    final videoTopics = video.topics.toSet();
    final knownOverlap = videoTopics.intersection(userFollowedTopics);
    final newTopics = videoTopics.difference(userFollowedTopics);
    if (knownOverlap.isNotEmpty && newTopics.isNotEmpty) {
      bonus += 0.1; // Bridges known → unknown
    }

    return min(0.4, bonus);
  }

  /// Insert exploration candidates into final feed at designated slots
  List<ScoredVideo> insertExplorationCandidates(
    List<ScoredVideo> finalFeed,
    DiversityConfig config,
  ) {
    if (finalFeed.isEmpty || config.explorationRate <= 0.0) {
      return finalFeed;
    }

    final totalSlots = finalFeed.length;
    final explorationCount = (totalSlots * config.explorationRate).round();

    if (explorationCount == 0) return finalFeed;

    // Every Nth position is an exploration slot (e.g. every 12th item)
    final interval = max(5, (totalSlots / explorationCount).floor());
    final result = List<ScoredVideo>.from(finalFeed);

    // Identify candidate positions to inject diversity
    for (var i = interval - 1; i < result.length; i += interval) {
      if (i < result.length) {
        final item = result[i];
        // Mark as exploration candidate reason if not already specified
        result[i] = ScoredVideo(
          video: item.video,
          score: item.score,
          recommendationReason: RecommendationReasons.newCreator,
          recommendationExplanation: 'Discover something new',
          surface: item.surface,
          signalBreakdown: item.signalBreakdown,
        );
      }
    }

    return result;
  }

  /// Calculate novelty score for a video (higher score = more novel to user)
  double calculateNoveltyScore({
    required String category,
    required List<String> topics,
    required Set<String> userKnownCategories,
    required Set<String> userFollowedTopics,
  }) {
    double score = 1.0; // Base score for fully novel content

    if (userKnownCategories.contains(category)) {
      score -= 0.4;
    }

    for (final topic in topics) {
      if (userFollowedTopics.contains(topic)) {
        score -= 0.3;
      }
    }

    return max(0.0, score);
  }

  /// Calculate novelty penalty when same sub-topic is repeated in feed
  double calculateNoveltyPenalty({
    required String category,
    required List<String> topics,
    required Map<String, int> recentTopicCounts,
  }) {
    double penalty = 0.0;

    final categoryCount = recentTopicCounts[category] ?? 0;
    if (categoryCount >= 3) {
      penalty += (categoryCount - 2) * 0.2;
    }

    for (final topic in topics) {
      final topicCount = recentTopicCounts['topic:$topic'] ?? 0;
      if (topicCount >= 2) {
        penalty += (topicCount - 1) * 0.3;
      }
    }

    return min(penalty, 0.8);
  }
}
