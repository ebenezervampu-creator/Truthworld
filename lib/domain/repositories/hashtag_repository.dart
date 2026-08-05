import 'package:truthworld/core/network/result.dart';

/// Repository interface for hashtag operations.
abstract class HashtagRepository {
  /// Fetch trending hashtags.
  Future<Result<List<Map<String, dynamic>>>> getTrendingHashtags({
    int limit = 20,
  });

  /// Fetch videos for a specific hashtag.
  Future<Result<List<Map<String, dynamic>>>> getVideosByHashtag(
    String hashtag, {
    int page = 1,
    int limit = 20,
  });

  /// Search hashtags by query.
  Future<Result<List<String>>> searchHashtags(String query, {int limit = 10});
}
