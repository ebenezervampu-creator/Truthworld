import 'package:truthworld/core/network/result.dart';

/// Repository interface for creator dashboard operations.
///
/// Covers video management, analytics, comments, subtitles,
/// chapters, audio tracks, and channel customization.
abstract class DashboardRepository {
  /// Fetch all videos for a channel with pagination.
  Future<Result<List<Map<String, dynamic>>>> getChannelVideos(
    String channelId, {
    int page = 1,
    int limit = 20,
    String? status,
  });

  /// Fetch dashboard analytics summary for a channel.
  Future<Result<Map<String, dynamic>>> getChannelAnalytics(
    String channelId, {
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Fetch comments for a specific video.
  Future<Result<List<Map<String, dynamic>>>> getVideoComments(
    String videoId, {
    int page = 1,
    int limit = 20,
    String? filter,
  });

  /// Reply to a comment as the channel owner.
  Future<Result<void>> replyToComment(
    String videoId,
    String commentId,
    String replyText, {
    required String channelId,
    required String channelName,
    required String channelImageUrl,
  });

  /// Fetch subtitles for a video.
  Future<Result<Map<String, String>>> getVideoSubtitles(String videoId);

  /// Save subtitles for a video.
  Future<Result<void>> saveVideoSubtitles(
    String videoId,
    Map<String, String> subtitles,
  );

  /// Fetch chapters for a video.
  Future<Result<List<Map<String, dynamic>>>> getVideoChapters(String videoId);

  /// Save chapters for a video.
  Future<Result<void>> saveVideoChapters(
    String videoId,
    List<Map<String, dynamic>> chapters,
  );

  /// Fetch audio tracks for a video.
  Future<Result<List<Map<String, dynamic>>>> getAudioTracks(String videoId);

  /// Move a video to trash.
  Future<Result<void>> trashVideo(String videoId);

  /// Restore a video from trash.
  Future<Result<void>> restoreVideo(String videoId);

  /// Permanently delete a video.
  Future<Result<void>> permanentlyDeleteVideo(String videoId);

  /// Fetch audience demographics for a channel.
  Future<Result<Map<String, dynamic>>> getAudienceDemographics(
    String channelId,
  );
}
