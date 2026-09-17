import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Every place content is recommended in Truthworld
enum RecommendationSurface {
  homeFeedAll,
  homeFeedCategory,
  videoRelated,
  autoplayNext,
  searchResults,
  subscriptionFeed,
  trending,
  discoverChannels,
  exploreTopics,
  shortsFeed,
  endScreen,
  unexplored,
}

class RecommendationExplanation {
  final String reason;
  final double confidence;
  final Map<String, double> signalBreakdown;

  const RecommendationExplanation({
    required this.reason,
    required this.confidence,
    this.signalBreakdown = const {},
  });

  @override
  String toString() =>
      'Explanation($reason, confidence: ${confidence.toStringAsFixed(2)})';
}

/// A video scored by the Truthworld Algorithm
class ScoredVideo {
  final Video video;
  final double score;
  final String recommendationReason;
  final String recommendationExplanation;
  final RecommendationSurface surface;
  final Map<String, double> signalBreakdown;
  final RecommendationExplanation? explanation;

  ScoredVideo({
    required this.video,
    required this.score,
    this.recommendationReason = RecommendationReasons.forYou,
    this.recommendationExplanation = 'Recommended based on your interests',
    this.surface = RecommendationSurface.homeFeedAll,
    this.signalBreakdown = const {},
    this.explanation,
  });

  @override
  String toString() =>
      'ScoredVideo(id: ${video.id}, title: ${video.title}, score: ${score.toStringAsFixed(2)}, reason: $recommendationReason)';
}

/// A channel scored for discovery
class ScoredChannel {
  final Channel channel;
  final double score;
  final String reason;

  ScoredChannel({
    required this.channel,
    required this.score,
    this.reason = 'Recommended for you',
  });
}

/// A topic scored for explore
class ScoredTopic {
  final Topic topic;
  final double score;
  final String reason;

  ScoredTopic({
    required this.topic,
    required this.score,
    this.reason = 'Popular in your interests',
  });
}

/// Recommendation reason constants
class RecommendationReasons {
  static const following = 'Following';
  static const factChecked = 'Fact-Checked';
  static const risingFast = 'Rising Fast';
  static const inYourTopics = 'In Your Topics';
  static const forYou = 'For You';
  static const newCreator = 'New Creator';
  static const becauseYouFollow = 'Because you follow';
  static const similarToWatched = 'Similar to videos you watched';
  static const trendingInInterests = 'Trending in your interests';
  static const trustedSource = 'Highly trusted source';
  static const popularAmongSimilar = 'Popular among similar viewers';
  static const fromCreatorYouFollow = 'From a creator you follow';
}
