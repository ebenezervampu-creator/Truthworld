import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/video_entity.dart';

/// Repository interface for video operations.
///
/// Controllers depend on this interface, not on Firestore directly.
/// This enables testing with mock implementations and decouples
/// the data layer from the presentation layer.
abstract class VideoRepository {
  /// Fetch the home feed with pagination.
  Future<Result<List<VideoEntity>>> getHomeFeed({
    int page = 1,
    int limit = 10,
    dynamic startAfter,
  });

  /// Fetch a single video by its ID.
  Future<Result<VideoEntity>> getVideoById(String id);

  /// Search videos by query string.
  Future<Result<List<VideoEntity>>> searchVideos(
    String query, {
    int page = 1,
    int limit = 20,
    dynamic startAfter,
  });

  /// Fetch videos by channel ID.
  Future<Result<List<VideoEntity>>> getVideosByChannel(
    String channelId, {
    int page = 1,
    int limit = 20,
    dynamic startAfter,
  });

  /// Fetch trending videos.
  Future<Result<List<VideoEntity>>> getTrendingVideos({
    int limit = 20,
  });

  /// Like a video (toggle).
  Future<Result<void>> toggleLike(String videoId, String userId);

  /// Dislike a video (toggle).
  Future<Result<void>> toggleDislike(String videoId, String userId);

  /// Delete a video (owner only).
  Future<Result<void>> deleteVideo(String videoId);

  /// Increment view count for a video.
  Future<Result<void>> incrementViewCount(String videoId);
}
