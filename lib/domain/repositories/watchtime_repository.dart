import 'package:truthworld/core/network/result.dart';

/// Repository interface for watch time tracking and reporting.
abstract class WatchTimeRepository {
  /// Record watch time for a session.
  Future<Result<void>> recordWatchTime({
    required String userId,
    required String videoId,
    required int watchedSeconds,
    required int totalSeconds,
    required DateTime watchedAt,
    String? channelId,
  });

  /// Fetch total watch time for a user in a time range.
  Future<Result<Map<String, dynamic>>> getUserWatchTimeSummary(
    String userId, {
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Fetch watch time analytics for a channel (creator view).
  Future<Result<Map<String, dynamic>>> getChannelWatchTime(
    String channelId, {
    required DateTime startDate,
    required DateTime endDate,
    String granularity = 'day',
  });

  /// Fetch average watch duration per video for a channel.
  Future<Result<Map<String, double>>> getAverageWatchDuration(
    String channelId, {
    int limit = 20,
  });
}
