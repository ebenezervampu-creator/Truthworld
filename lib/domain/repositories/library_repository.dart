import 'package:truthworld/core/network/result.dart';

/// Repository interface for user library operations — watch history,
/// liked videos, and saved content.
abstract class LibraryRepository {
  /// Fetch liked videos for the current user with pagination.
  Future<Result<List<Map<String, dynamic>>>> getLikedVideos(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  /// Toggle like status for a video.
  Future<Result<void>> toggleLikeVideo(String userId, String videoId);

  /// Fetch watch history for the current user with pagination.
  Future<Result<List<Map<String, dynamic>>>> getWatchHistory(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  /// Add a video to watch history.
  Future<Result<void>> addToWatchHistory(
    String userId,
    String videoId, {
    int watchedSeconds = 0,
    int totalSeconds = 0,
  });

  /// Clear all watch history for a user.
  Future<Result<void>> clearWatchHistory(String userId);

  /// Remove a single entry from watch history.
  Future<Result<void>> removeFromWatchHistory(String userId, String videoId);

  /// Fetch watch later list for the current user.
  Future<Result<List<Map<String, dynamic>>>> getWatchLater(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  /// Toggle watch later status.
  Future<Result<void>> toggleWatchLater(String userId, String videoId);
}
