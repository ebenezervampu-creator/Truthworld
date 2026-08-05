import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Repository interface for home feed and discovery operations.
///
/// Controllers depend on this interface, not on Firestore directly.
/// This enables testing with mock implementations and decouples
/// the data layer from the presentation layer.
abstract class HomeRepository {
  /// Fetch the personalized home feed with pagination.
  Future<Result<List<Video>>> getHomeFeed({
    int page = 1,
    int limit = 20,
    String? category,
  });

  /// Fetch videos filtered by category.
  Future<Result<List<Video>>> getVideosByCategory(
    String category, {
    int page = 1,
    int limit = 20,
  });

  /// Fetch featured/trending topics for discovery.
  Future<Result<List<Topic>>> getFeaturedTopics({int limit = 10});

  /// Fetch videos by topic.
  Future<Result<List<Video>>> getVideosByTopic(
    String topicId, {
    int page = 1,
    int limit = 20,
  });

  /// Fetch community posts for home feed.
  Future<Result<List<Map<String, dynamic>>>> getCommunityPosts({
    int page = 1,
    int limit = 10,
  });
}
