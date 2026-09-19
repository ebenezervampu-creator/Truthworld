import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/video_entity.dart';

/// Repository contract for video CRUD operations, view count tracking, and engagement metrics.
/// Domain pure: uses [VideoEntity], never data layer models.
abstract class VideoRepository {
  /// Fetch a video by unique ID.
  Future<Result<VideoEntity>> getVideoById(String id);

  /// Fetch a list of recommended or feed videos.
  Future<Result<List<VideoEntity>>> getFeedVideos({int limit = 10});

  /// Record a view count for a video.
  Future<Result<void>> recordView(String videoId);

  /// Toggle like status on a video.
  Future<Result<void>> toggleLike({required String videoId, required String userId});

  /// Fetch videos by channel ID.
  Future<Result<List<VideoEntity>>> getVideosByChannel(String channelId);
}
