import 'package:truthworld/core/network/result.dart';

/// Repository interface for analytics operations.
///
/// Provides data access for creator analytics dashboard,
/// video performance metrics, and audience insights.
abstract class AnalyticsRepository {
  /// Fetch overview analytics for a channel.
  Future<Result<Map<String, dynamic>>> getChannelOverview(
    String channelId, {
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Fetch views analytics with time-series data.
  Future<Result<Map<String, dynamic>>> getViewsAnalytics(
    String channelId, {
    required DateTime startDate,
    required DateTime endDate,
    String granularity = 'day',
  });

  /// Fetch watch time analytics with time-series data.
  Future<Result<Map<String, dynamic>>> getWatchTimeAnalytics(
    String channelId, {
    required DateTime startDate,
    required DateTime endDate,
    String granularity = 'day',
  });

  /// Fetch subscriber growth analytics.
  Future<Result<Map<String, dynamic>>> getSubscriberAnalytics(
    String channelId, {
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Fetch geographic distribution of viewers.
  Future<Result<Map<String, dynamic>>> getGeographicData(String channelId);

  /// Fetch top performing videos for a channel.
  Future<Result<List<Map<String, dynamic>>>> getTopVideos(
    String channelId, {
    int limit = 10,
    String sortBy = 'views',
  });

  /// Fetch real-time viewers count.
  Future<Result<int>> getRealTimeViewers(String channelId);
}
