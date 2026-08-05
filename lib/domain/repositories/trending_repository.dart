import 'package:truthworld/core/network/result.dart';

/// Repository interface for trending content operations.
abstract class TrendingRepository {
  /// Fetch trending videos with pagination.
  Future<Result<List<Map<String, dynamic>>>> getTrendingVideos({
    int page = 1,
    int limit = 20,
    String? country,
    String? category,
  });

  /// Fetch trending topics.
  Future<Result<List<Map<String, dynamic>>>> getTrendingTopics({
    int limit = 10,
  });

  /// Fetch trending creators.
  Future<Result<List<Map<String, dynamic>>>> getTrendingCreators({
    int limit = 10,
  });
}
