import 'package:truthworld/features/topics/data/models/topic.dart';

/// Data model for topic recommendation relevance results
class TopicRelevanceResult {
  const TopicRelevanceResult({
    required this.topic,
    required this.matchPercentage,
    required this.recommendationReason,
    required this.score,
  });

  final Topic topic;
  final int matchPercentage;
  final String recommendationReason;
  final double score;
}
