import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/topic_entity.dart';
import 'package:truthworld/domain/entities/video_entity.dart';

/// Repository interface for home feed and discovery operations.
///
/// Controllers depend on this interface, not on Firestore directly.
/// This enables testing with mock implementations and decouples
/// the data layer from the presentation layer.
abstract class HomeRepository {
  /// Fetch the personalized home feed with pagination.
  Future<Result<List<VideoEntity>>> getHomeFeed({
    int page = 1,
    int limit = 20,
    String? category,
    dynamic startAfter,
  });

  /// Fetch videos filtered by category.
  Future<Result<List<VideoEntity>>> getVideosByCategory(
    String category, {
    int page = 1,
    int limit = 20,
    dynamic startAfter,
  });

  /// Fetch featured/trending topics for discovery.
  Future<Result<List<TopicEntity>>> getFeaturedTopics({int limit = 10});

  /// Fetch videos by topic.
  Future<Result<List<VideoEntity>>> getVideosByTopic(
    String topicId, {
    int page = 1,
    int limit = 20,
    dynamic startAfter,
  });

  /// Fetch community posts for home feed.
  Future<Result<List<Map<String, dynamic>>>> getCommunityPosts({
    int page = 1,
    int limit = 10,
    dynamic startAfter,
  });
}
