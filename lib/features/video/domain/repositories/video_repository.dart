import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Repository contract for video CRUD operations, view count tracking, and engagement metrics.
abstract class VideoRepository {
  /// Fetch a video by unique ID.
  Future<Result<Video>> getVideoById(String id);

  /// Fetch a list of recommended or feed videos.
  Future<Result<List<Video>>> getFeedVideos({int limit = 10});

  /// Record a view count for a video.
  Future<Result<void>> recordView(String videoId);

  /// Toggle like status on a video.
  Future<Result<void>> toggleLike({required String videoId, required String userId});

  /// Fetch videos by channel ID.
  Future<Result<List<Video>>> getVideosByChannel(String channelId);
}
