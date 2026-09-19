import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/data/services/analytics/analytics_barrel.dart';
import 'package:truthworld/features/analytics/data/services/video_presence_service.dart';

export 'package:truthworld/features/analytics/data/services/analytics/analytics_barrel.dart';

/// Service coordinating video, channel, fraud, and presence analytics.
///
/// Architecture:
/// - Reads from pre-aggregated Firestore collections (`video_stats_daily`, `channel_stats_daily`)
/// - Real-time hourly trend merging from `video_stats_hourly`
/// - Live counters fallback from `videos/{id}` and `channels/{id}`
/// - In-memory TTL caching managed by [AnalyticsCacheManager]
class VideoAnalyticsService extends GetxService {
  VideoAnalyticsService({
    AnalyticsFirestoreClient? firestoreClient,
    AnalyticsCacheManager? cacheManager,
    VideoAnalyticsAggregator? videoAggregator,
    ChannelAnalyticsAggregator? channelAggregator,
    FirebaseFirestore? firestore,
  })  : _firestoreClient = firestoreClient ??
            AnalyticsFirestoreClient(firestore: firestore),
        _cacheManager = cacheManager ?? AnalyticsCacheManager(),
        _videoAggregator = videoAggregator ?? const VideoAnalyticsAggregator(),
        _channelAggregator =
            channelAggregator ?? const ChannelAnalyticsAggregator();

  static const String _tag = 'VideoAnalyticsService';

  final AnalyticsFirestoreClient _firestoreClient;
  final AnalyticsCacheManager _cacheManager;
  final VideoAnalyticsAggregator _videoAggregator;
  final ChannelAnalyticsAggregator _channelAggregator;

  @override
  void onInit() {
    super.onInit();
    logger.info('Video Analytics Service initialized', tag: _tag);
  }

  /// Record a qualified view event for analytics tracking.
  void recordQualifiedView(String videoId, {String? trafficSource}) {
    logger.info(
      'Qualified view recorded for $videoId (Source: $trafficSource)',
      tag: _tag,
    );
  }

  // ===========================================================================
  // VIDEO-LEVEL ANALYTICS
  // ===========================================================================

  /// Get analytics for a single video within a date range.
  Future<VideoAnalyticsSnapshot> getVideoAnalytics(
    String videoId, {
    String? videoTitle,
    AnalyticsDateRange dateRange = AnalyticsDateRange.last28Days,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    if (videoId.isEmpty) {
      return _videoAggregator.createEmptyVideoAnalytics(
        '',
        videoTitle ?? 'Unknown',
      );
    }
    try {
      final cacheKey = '${videoId}_${dateRange.name}';
      final cached = _cacheManager.get(cacheKey);
      if (cached != null) return cached;

      logger.info(
        'Loading video analytics: $videoId (${dateRange.label})',
        tag: _tag,
      );

      final range = dateRange.calculateRange(
        customStart: customStart,
        customEnd: customEnd,
      );

      final dailyStats = await _firestoreClient.fetchDailyVideoStats(
        videoId,
        range.start,
        range.end,
      );

      VideoAnalyticsSnapshot snapshot;
      if (dailyStats.isEmpty) {
        snapshot = await _firestoreClient.buildFromLiveVideoCounters(
          videoId,
          videoTitle ?? 'Unknown',
        );
      } else {
        snapshot = _videoAggregator.aggregateVideoStats(
          videoId,
          videoTitle ?? 'Unknown',
          dailyStats,
        );
      }

      // Real-time supplement: Merge today's hourly data if end date is today
      final now = DateTime.now();
      final isEndDateToday = range.end.year == now.year &&
          range.end.month == now.month &&
          range.end.day == now.day;

      if (isEndDateToday) {
        final todayHourly = await getTodayAggregatedHourly(videoId);
        if (todayHourly != null) {
          snapshot = _videoAggregator.mergeHourlyIntoSnapshot(
            snapshot,
            todayHourly,
          );
        }
      }

      final liveCount = await getLiveViewerCount(videoId);

      final finalSnapshot = VideoAnalyticsSnapshot(
        videoId: snapshot.videoId,
        title: snapshot.title,
        totalViews: snapshot.totalViews,
        totalUniqueViewers: snapshot.totalUniqueViewers,
        totalImpressions: snapshot.totalImpressions,
        averageWatchDuration: snapshot.averageWatchDuration,
        averageWatchPercentage: snapshot.averageWatchPercentage,
        totalWatchTimeSeconds: snapshot.totalWatchTimeSeconds,
        usersCompletedVideo: snapshot.usersCompletedVideo,
        watchtimeCategoryCount: snapshot.watchtimeCategoryCount,
        stateTraffic: snapshot.stateTraffic,
        stateTrafficPercentage: snapshot.stateTrafficPercentage,
        cityTraffic: snapshot.cityTraffic,
        cityTrafficPercentage: snapshot.cityTrafficPercentage,
        countryTraffic: snapshot.countryTraffic,
        countryTrafficPercentage: snapshot.countryTrafficPercentage,
        urbanViewers: snapshot.urbanViewers,
        ruralViewers: snapshot.ruralViewers,
        deviceTypeBreakdown: snapshot.deviceTypeBreakdown,
        qualityBreakdown: snapshot.qualityBreakdown,
        trafficSourceBreakdown: snapshot.trafficSourceBreakdown,
        subscriberViews: snapshot.subscriberViews,
        nonSubscriberViews: snapshot.nonSubscriberViews,
        returningViewers: snapshot.returningViewers,
        subscribersGained: snapshot.subscribersGained,
        subscribersLost: snapshot.subscribersLost,
        dailyWatchTime: snapshot.dailyWatchTime,
        dailyViews: snapshot.dailyViews,
        dailySubscribers: snapshot.dailySubscribers,
        liveViewerCount: liveCount,
        generatedAt: DateTime.now(),
        nextUpdateAt: DateTime.now().add(
          Duration(minutes: _cacheManager.cacheExpiryMinutes),
        ),
        estimatedReadCount: dailyStats.length + 1,
      );

      _cacheManager.put(cacheKey, finalSnapshot);
      return finalSnapshot;
    } catch (e, stackTrace) {
      logger.error(
        'Error getting video analytics: $e',
        stackTrace: stackTrace,
        tag: _tag,
      );
      return _videoAggregator.createEmptyVideoAnalytics(
        videoId,
        videoTitle ?? 'Unknown',
      );
    }
  }

  // ===========================================================================
  // CHANNEL-LEVEL ANALYTICS
  // ===========================================================================

  /// Get channel-level analytics from pre-aggregated daily stats or fallbacks.
  Future<ChannelAnalyticsSnapshot> getChannelAnalytics(
    String channelId, {
    String? channelName,
    AnalyticsDateRange dateRange = AnalyticsDateRange.last28Days,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    if (channelId.isEmpty) {
      return _channelAggregator.createEmptyChannelAnalytics(
        '',
        channelName ?? 'Unknown',
      );
    }
    try {
      logger.info(
        'Loading channel analytics: $channelId (${dateRange.label})',
        tag: _tag,
      );

      final range = dateRange.calculateRange(
        customStart: customStart,
        customEnd: customEnd,
      );

      final dailyStats = await _firestoreClient.fetchDailyChannelStats(
        channelId,
        range.start,
        range.end,
      );

      final liveCount = await getChannelLiveViewerCount(channelId);

      if (dailyStats.isNotEmpty) {
        return _channelAggregator.aggregateDailyChannelStats(
          channelId,
          channelName ?? 'Unknown',
          dailyStats,
          liveViewerCount: liveCount,
        );
      }

      // Fallback 1: aggregate from video_stats_daily
      final videoStats = await _firestoreClient.fetchChannelVideoDailyStats(
        channelId,
        range.start,
        range.end,
      );

      if (videoStats.isNotEmpty) {
        return _channelAggregator.buildChannelFromVideoDailyStats(
          channelId,
          channelName ?? 'Unknown',
          videoStats,
          liveViewerCount: liveCount,
        );
      }

      // Fallback 2: aggregate from live channel counters
      return await _firestoreClient.buildChannelFromLiveCounters(
        channelId,
        channelName ?? 'Unknown',
      );
    } catch (e, stackTrace) {
      logger.error(
        'Error getting channel analytics: $e',
        stackTrace: stackTrace,
        tag: _tag,
      );
      return _channelAggregator.createEmptyChannelAnalytics(
        channelId,
        channelName ?? 'Unknown',
      );
    }
  }

  // ===========================================================================
  // LIVE PRESENCE & HOURLY TRENDS
  // ===========================================================================

  /// Get count of users currently watching a video via RTDB liveStats.
  Future<int> getLiveViewerCount(String videoId) async {
    try {
      return await VideoPresenceService.to.getLiveViewerCount(videoId);
    } catch (_) {
      return 0;
    }
  }

  /// Get total live viewers across all channel's videos.
  Future<int> getChannelLiveViewerCount(String channelId) async {
    return _firestoreClient.getChannelLiveViewerCount(channelId);
  }

  /// Invalidate all in-memory caches.
  void clearAnalyticsCache() => _cacheManager.clear();

  /// Invalidate cache for a specific video.
  void invalidateVideoCache(String videoId) =>
      _cacheManager.invalidateVideo(videoId);

  /// Fetch last N hours of stats for a video.
  Future<List<HourlyVideoStats>> getRecentHourlyStats(
    String videoId, {
    int hours = 24,
  }) async {
    return _firestoreClient.getRecentHourlyStats(videoId, hours: hours);
  }

  /// Get aggregated stats for today by summing hourly docs.
  Future<HourlyVideoStats?> getTodayAggregatedHourly(String videoId) async {
    return _firestoreClient.getTodayAggregatedHourly(videoId);
  }

  /// Server-side view dedup check against qualified_views.
  Future<bool> hasQualifiedViewToday(String videoId, String userId) async {
    return _firestoreClient.hasQualifiedViewToday(videoId, userId);
  }

  /// Get fraud overview for a video.
  Future<FraudOverview> getFraudOverview(
    String videoId, {
    int days = 28,
  }) async {
    return _firestoreClient.getFraudOverview(videoId, days: days);
  }
}
