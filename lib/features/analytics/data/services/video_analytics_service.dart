import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';

/// Date range presets for analytics filtering
enum AnalyticsDateRange {
  last7Days('7 days', 7),
  last28Days('28 days', 28),
  last90Days('90 days', 90),
  last365Days('1 year', 365),
  allTime('All time', 0),
  custom('Custom', -1);

  final String label;
  final int days;

  const AnalyticsDateRange(this.label, this.days);
}

/// Service for managing video analytics.
///
/// Architecture:
/// - Raw events written by Cloud Function → `watch_events_raw/{eventId}`
/// - Cloud Function aggregates into → `video_stats_daily/{videoId_date}`
/// - Cloud Function aggregates into → `channel_stats_daily/{channelId_date}`
/// - This service READS from aggregated tables (cost-efficient)
/// - Live counters in `videos/{videoId}` for real-time view count
class VideoAnalyticsService extends GetxService {
  static const String _tag = 'VideoAnalyticsService';
  static const int _cacheExpiryMinutes = 15;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _dateFormat = DateFormat('yyyy_MM_dd');

  /// Cache for video analytics snapshots
  final Map<String, _CachedAnalytics> _analyticsCache = {};

  @override
  void onInit() {
    super.onInit();
    logger.info('Video Analytics Service initialized', tag: _tag);
  }

  // ===========================================================================
  // VIDEO-LEVEL ANALYTICS (reads from video_stats_daily)
  // ===========================================================================

  /// Get analytics for a single video within a date range.
  /// Reads from pre-aggregated `video_stats_daily` collection.
  Future<VideoAnalyticsSnapshot> getVideoAnalytics(
    String videoId, {
    String? videoTitle,
    AnalyticsDateRange dateRange = AnalyticsDateRange.last28Days,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    try {
      final cacheKey = '${videoId}_${dateRange.name}';

      // Check cache
      if (_analyticsCache.containsKey(cacheKey)) {
        final cached = _analyticsCache[cacheKey]!;
        if (DateTime.now().difference(cached.createdAt).inMinutes <
            _cacheExpiryMinutes) {
          return cached.snapshot;
        }
      }

      logger.info(
        'Loading video analytics: $videoId (${dateRange.label})',
        tag: _tag,
      );

      // Calculate date range
      final now = DateTime.now();
      DateTime startDate;
      var endDate = now;

      if (dateRange == AnalyticsDateRange.custom &&
          customStart != null &&
          customEnd != null) {
        startDate = customStart;
        endDate = customEnd;
      } else if (dateRange == AnalyticsDateRange.allTime) {
        startDate = DateTime(2020); // Platform start
      } else {
        startDate = now.subtract(Duration(days: dateRange.days));
      }

      // Query daily stats for this video in the date range
      final dailyStats = await _fetchDailyVideoStats(
        videoId,
        startDate,
        endDate,
      );

      // Aggregate daily stats into snapshot
      VideoAnalyticsSnapshot snapshot;
      if (dailyStats.isEmpty) {
        // Fall back to reading live counters from video doc
        snapshot = await _buildFromLiveCounters(
          videoId,
          videoTitle ?? 'Unknown',
        );
      } else {
        snapshot = _aggregateVideoStats(
          videoId,
          videoTitle ?? 'Unknown',
          dailyStats,
        );
      }

      // Real-time supplement: Merge today's hourly data if end date is today
      final isEndDateToday =
          endDate.year == now.year &&
          endDate.month == now.month &&
          endDate.day == now.day;

      if (isEndDateToday) {
        final todayHourly = await getTodayAggregatedHourly(videoId);
        if (todayHourly != null) {
          snapshot = _mergeHourlyIntoSnapshot(snapshot, todayHourly);
        }
      }

      // Fetch live viewer count
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
          const Duration(minutes: _cacheExpiryMinutes),
        ),
        estimatedReadCount: dailyStats.length + 1,
      );

      // Cache
      _analyticsCache[cacheKey] = _CachedAnalytics(
        snapshot: finalSnapshot,
        createdAt: DateTime.now(),
      );

      return finalSnapshot;
    } catch (e, stackTrace) {
      logger.error(
        'Error getting video analytics: $e',
        stackTrace: stackTrace,
        tag: _tag,
      );
      return _createEmptyVideoAnalytics(videoId, videoTitle ?? 'Unknown');
    }
  }

  /// Fetch DailyVideoStats documents for a video in a date range
  Future<List<DailyVideoStats>> _fetchDailyVideoStats(
    String videoId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final startKey = _dateFormat.format(start);
      final endKey = _dateFormat.format(end);

      // Fetch all stats for this video and filter locally to avoid composite index
      final snapshot = await _firestore
          .collection('video_stats_daily')
          .where('videoId', isEqualTo: videoId)
          .get();

      final allStats = snapshot.docs
          .map((doc) => DailyVideoStats.fromMap(doc.data()))
          .toList();

      // Filter by date range and sort locally
      final filteredStats = allStats.where((stats) {
        return stats.dateKey.compareTo(startKey) >= 0 &&
            stats.dateKey.compareTo(endKey) <= 0;
      }).toList();

      filteredStats.sort((a, b) => b.dateKey.compareTo(a.dateKey));

      return filteredStats.take(365).toList();
    } catch (e) {
      logger.warning('Error fetching daily video stats: $e', tag: _tag);
      return [];
    }
  }

  /// Aggregate list of daily stats into a single VideoAnalyticsSnapshot
  VideoAnalyticsSnapshot _aggregateVideoStats(
    String videoId,
    String title,
    List<DailyVideoStats> dailyStats,
  ) {
    var totalViews = 0;
    var totalImpressions = 0;
    var totalUnique = 0;
    var totalWatchTime = 0;
    var subViews = 0;
    var nonSubViews = 0;
    var returning = 0;
    var subGained = 0;
    var subLost = 0;
    var bounced = 0;
    var w25 = 0;
    var w50 = 0;
    var w75 = 0;
    var w100 = 0;
    var urban = 0;
    var rural = 0;
    final stateTraffic = <String, int>{};
    final cityTraffic = <String, int>{};
    final countryTraffic = <String, int>{};
    final deviceBreakdown = <String, int>{};
    final qualityBreakdown = <String, int>{};
    final trafficSources = <String, int>{};
    final dailyWatchTime = <DateTime, int>{};
    final dailyViews = <DateTime, int>{};
    final dailySubscribers = <DateTime, int>{};

    for (final day in dailyStats) {
      totalViews += day.totalViews;
      totalImpressions += day.totalImpressions;
      totalUnique += day.uniqueViewers;
      totalWatchTime += day.totalWatchTimeSeconds;
      subViews += day.subscriberViews;
      nonSubViews += day.nonSubscriberViews;
      returning += day.returningViewers;
      subGained += day.subscribersGained;
      subLost += day.subscribersLost;
      bounced += day.bouncedUnder20s;
      w25 += day.watched25Percent;
      w50 += day.watched50Percent;
      w75 += day.watched75Percent;
      w100 += day.watched100Percent;
      urban += day.urbanViewers;
      rural += day.ruralViewers;

      dailyWatchTime[day.date] = day.totalWatchTimeSeconds;
      dailyViews[day.date] = day.totalViews;
      dailySubscribers[day.date] = day.subscribersGained - day.subscribersLost;

      _mergeInto(stateTraffic, day.stateTraffic);
      _mergeInto(cityTraffic, day.cityTraffic);
      _mergeInto(countryTraffic, day.countryTraffic);
      _mergeInto(deviceBreakdown, day.deviceBreakdown);
      _mergeInto(qualityBreakdown, day.qualityBreakdown);
      _mergeInto(trafficSources, day.trafficSourceBreakdown);
    }

    // Build category counts
    final catCount = <WatchtimeCategory, int>{
      WatchtimeCategory.lessThan20: bounced,
      WatchtimeCategory.lessThan25: w25,
      WatchtimeCategory.lessThan50: w50,
      WatchtimeCategory.lessThan75: w75,
      WatchtimeCategory.complete: w100,
    };

    // State percentages
    final stateTotal = stateTraffic.values.fold<int>(0, (a, b) => a + b);
    final statePct = <String, double>{};
    for (final e in stateTraffic.entries) {
      statePct[e.key] = stateTotal > 0 ? (e.value / stateTotal) * 100 : 0;
    }

    // City percentages
    final cityTotal = cityTraffic.values.fold<int>(0, (a, b) => a + b);
    final cityPct = <String, double>{};
    for (final e in cityTraffic.entries) {
      cityPct[e.key] = cityTotal > 0 ? (e.value / cityTotal) * 100 : 0;
    }

    // Country percentages
    final countryTotal = countryTraffic.values.fold<int>(0, (a, b) => a + b);
    final countryPct = <String, double>{};
    for (final e in countryTraffic.entries) {
      countryPct[e.key] = countryTotal > 0 ? (e.value / countryTotal) * 100 : 0;
    }

    // Avg watch duration
    final avgDuration = totalUnique > 0 ? totalWatchTime / totalUnique : 0.0;

    // Avg watch percentage (approximate: assume avg video is same duration)
    final firstDayDuration = dailyStats.isNotEmpty
        ? dailyStats.first.avgWatchDuration
        : 0.0;
    final avgPct = firstDayDuration > 0
        ? (avgDuration / firstDayDuration) * 100
        : 0.0;

    return VideoAnalyticsSnapshot(
      videoId: videoId,
      title: title,
      totalViews: totalViews,
      totalUniqueViewers: totalUnique,
      totalImpressions: totalImpressions,
      averageWatchDuration: avgDuration,
      averageWatchPercentage: avgPct.clamp(0, 100),
      totalWatchTimeSeconds: totalWatchTime,
      usersCompletedVideo: w100,
      watchtimeCategoryCount: catCount,
      stateTraffic: stateTraffic,
      stateTrafficPercentage: statePct,
      cityTraffic: cityTraffic,
      cityTrafficPercentage: cityPct,
      countryTraffic: countryTraffic,
      countryTrafficPercentage: countryPct,
      urbanViewers: urban,
      ruralViewers: rural,
      deviceTypeBreakdown: deviceBreakdown,
      qualityBreakdown: qualityBreakdown,
      trafficSourceBreakdown: trafficSources,
      subscriberViews: subViews,
      nonSubscriberViews: nonSubViews,
      returningViewers: returning,
      subscribersGained: subGained,
      subscribersLost: subLost,
      dailyWatchTime: dailyWatchTime,
      dailyViews: dailyViews,
      dailySubscribers: dailySubscribers,
      generatedAt: DateTime.now(),
      estimatedReadCount: dailyStats.length,
    );
  }

  /// Build analytics from live video doc counters (fallback)
  Future<VideoAnalyticsSnapshot> _buildFromLiveCounters(
    String videoId,
    String title,
  ) async {
    try {
      final doc = await _firestore.collection('videos').doc(videoId).get();
      if (!doc.exists) {
        return _createEmptyVideoAnalytics(videoId, title);
      }

      final data = doc.data()!;
      final viewCount = (data['viewCount'] as num?)?.toInt() ?? 0;
      final watchTime = (data['totalWatchTimeSeconds'] as num?)?.toInt() ?? 0;

      return VideoAnalyticsSnapshot(
        videoId: videoId,
        title: data['title'] as String? ?? title,
        totalViews: viewCount,
        totalUniqueViewers: viewCount,
        averageWatchDuration: viewCount > 0 ? watchTime / viewCount : 0,
        averageWatchPercentage: 0,
        totalWatchTimeSeconds: watchTime,
        usersCompletedVideo: 0,
        watchtimeCategoryCount: {
          for (final cat in WatchtimeCategory.values) cat: 0,
        },
        stateTraffic: {},
        stateTrafficPercentage: {},
        deviceTypeBreakdown: {},
        qualityBreakdown: {},
        generatedAt: DateTime.now(),
        estimatedReadCount: 1,
        dailyViews: {DateTime.now(): viewCount},
        dailyWatchTime: {DateTime.now(): watchTime},
      );
    } catch (e) {
      return _createEmptyVideoAnalytics(videoId, title);
    }
  }

  // ===========================================================================
  // CHANNEL-LEVEL ANALYTICS (reads from channel_stats_daily)
  // ===========================================================================

  /// Get channel-level analytics from pre-aggregated daily stats
  Future<ChannelAnalyticsSnapshot> getChannelAnalytics(
    String channelId, {
    String? channelName,
    AnalyticsDateRange dateRange = AnalyticsDateRange.last28Days,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    try {
      logger.info(
        'Loading channel analytics: $channelId (${dateRange.label})',
        tag: _tag,
      );

      final now = DateTime.now();
      DateTime startDate;
      var endDate = now;

      if (dateRange == AnalyticsDateRange.custom &&
          customStart != null &&
          customEnd != null) {
        startDate = customStart;
        endDate = customEnd;
      } else if (dateRange == AnalyticsDateRange.allTime) {
        startDate = DateTime(2020);
      } else {
        startDate = now.subtract(Duration(days: dateRange.days));
      }

      // Try channel_stats_daily first
      final dailyStats = await _fetchDailyChannelStats(
        channelId,
        startDate,
        endDate,
      );

      if (dailyStats.isNotEmpty) {
        final snapshot = _aggregateChannelStats(
          channelId,
          channelName ?? 'Unknown',
          dailyStats,
        );

        // Fetch live viewer count for channel
        final liveCount = await getChannelLiveViewerCount(channelId);

        return ChannelAnalyticsSnapshot(
          channelId: snapshot.channelId,
          channelName: snapshot.channelName,
          totalVideoWatches: snapshot.totalVideoWatches,
          totalUniqueViewers: snapshot.totalUniqueViewers,
          totalImpressions: snapshot.totalImpressions,
          averageWatchDuration: snapshot.averageWatchDuration,
          averageWatchPercentage: snapshot.averageWatchPercentage,
          totalWatchTimeSeconds: snapshot.totalWatchTimeSeconds,
          stateTraffic: snapshot.stateTraffic,
          stateTrafficPercentage: snapshot.stateTrafficPercentage,
          cityTraffic: snapshot.cityTraffic,
          cityTrafficPercentage: snapshot.cityTrafficPercentage,
          countryTraffic: snapshot.countryTraffic,
          countryTrafficPercentage: snapshot.countryTrafficPercentage,
          urbanViewers: snapshot.urbanViewers,
          ruralViewers: snapshot.ruralViewers,
          trafficSourceBreakdown: snapshot.trafficSourceBreakdown,
          dailyWatchTime: snapshot.dailyWatchTime,
          dailyViews: snapshot.dailyViews,
          dailySubscribers: snapshot.dailySubscribers,
          generatedAt: snapshot.generatedAt,
          videoCount: snapshot.videoCount,
          totalEngagementScore: snapshot.totalEngagementScore,
          subscriberViews: snapshot.subscriberViews,
          nonSubscriberViews: snapshot.nonSubscriberViews,
          returningViewers: snapshot.returningViewers,
          subscribersGained: snapshot.subscribersGained,
          subscribersLost: snapshot.subscribersLost,
          liveViewerCount: liveCount,
        );
      }

      // Fallback: aggregate from video_stats_daily
      final snapshot = await _buildChannelFromVideoStats(
        channelId,
        channelName ?? 'Unknown',
        startDate,
        endDate,
      );

      // Fetch live viewer count for channel
      final liveCount = await getChannelLiveViewerCount(channelId);

      return ChannelAnalyticsSnapshot(
        channelId: snapshot.channelId,
        channelName: snapshot.channelName,
        totalVideoWatches: snapshot.totalVideoWatches,
        totalUniqueViewers: snapshot.totalUniqueViewers,
        totalImpressions: snapshot.totalImpressions,
        averageWatchDuration: snapshot.averageWatchDuration,
        averageWatchPercentage: snapshot.averageWatchPercentage,
        totalWatchTimeSeconds: snapshot.totalWatchTimeSeconds,
        stateTraffic: snapshot.stateTraffic,
        stateTrafficPercentage: snapshot.stateTrafficPercentage,
        cityTraffic: snapshot.cityTraffic,
        cityTrafficPercentage: snapshot.cityTrafficPercentage,
        countryTraffic: snapshot.countryTraffic,
        countryTrafficPercentage: snapshot.countryTrafficPercentage,
        urbanViewers: snapshot.urbanViewers,
        ruralViewers: snapshot.ruralViewers,
        trafficSourceBreakdown: snapshot.trafficSourceBreakdown,
        dailyWatchTime: snapshot.dailyWatchTime,
        dailyViews: snapshot.dailyViews,
        dailySubscribers: snapshot.dailySubscribers,
        generatedAt: snapshot.generatedAt,
        videoCount: snapshot.videoCount,
        totalEngagementScore: snapshot.totalEngagementScore,
        subscriberViews: snapshot.subscriberViews,
        nonSubscriberViews: snapshot.nonSubscriberViews,
        returningViewers: snapshot.returningViewers,
        subscribersGained: snapshot.subscribersGained,
        subscribersLost: snapshot.subscribersLost,
        liveViewerCount: liveCount,
      );
    } catch (e, stackTrace) {
      logger.error(
        'Error getting channel analytics: $e',
        stackTrace: stackTrace,
        tag: _tag,
      );
      return _createEmptyChannelAnalytics(channelId, channelName ?? 'Unknown');
    }
  }

  /// Fetch daily channel stats
  Future<List<DailyChannelStats>> _fetchDailyChannelStats(
    String channelId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final startKey = _dateFormat.format(start);
      final endKey = _dateFormat.format(end);

      // Fetch all stats for this channel and filter locally to avoid composite index
      final snapshot = await _firestore
          .collection('channel_stats_daily')
          .where('channelId', isEqualTo: channelId)
          .get();

      final allStats = snapshot.docs
          .map((doc) => DailyChannelStats.fromMap(doc.data()))
          .toList();

      // Filter by date range and sort locally
      final filteredStats = allStats.where((stats) {
        return stats.dateKey.compareTo(startKey) >= 0 &&
            stats.dateKey.compareTo(endKey) <= 0;
      }).toList();

      filteredStats.sort((a, b) => b.dateKey.compareTo(a.dateKey));

      return filteredStats.take(365).toList();
    } catch (e) {
      logger.warning('Error fetching daily channel stats: $e', tag: _tag);
      return [];
    }
  }

  /// Aggregate daily channel stats into snapshot
  ChannelAnalyticsSnapshot _aggregateChannelStats(
    String channelId,
    String channelName,
    List<DailyChannelStats> dailyStats,
  ) {
    var totalViews = 0;
    var totalImpressions = 0;
    var totalUnique = 0;
    var totalWatchTime = 0;
    var subViews = 0;
    var nonSubViews = 0;
    var returning = 0;
    var subGained = 0;
    var subLost = 0;
    var urban = 0;
    var rural = 0;
    var videoCount = 0;
    final stateTraffic = <String, int>{};
    final cityTraffic = <String, int>{};
    final countryTraffic = <String, int>{};
    final trafficSources = <String, int>{};
    final dailyWatchTime = <DateTime, int>{};
    final dailyViews = <DateTime, int>{};
    final dailySubscribers = <DateTime, int>{};

    for (final day in dailyStats) {
      totalViews += day.totalViews;
      totalImpressions += day.totalImpressions;
      totalUnique += day.uniqueViewers;
      totalWatchTime += day.totalWatchTimeSeconds;
      subViews += day.subscriberViews;
      nonSubViews += day.nonSubscriberViews;
      returning += day.returningViewers;
      subGained += day.subscribersGained;
      subLost += day.subscribersLost;
      urban += day.urbanViewers;
      rural += day.ruralViewers;
      videoCount += day.videoCount;

      dailyWatchTime[day.date] = day.totalWatchTimeSeconds;
      dailyViews[day.date] = day.totalViews;
      dailySubscribers[day.date] = day.subscribersGained - day.subscribersLost;

      _mergeInto(stateTraffic, day.stateTraffic);
      _mergeInto(cityTraffic, day.cityTraffic);
      _mergeInto(countryTraffic, day.countryTraffic);
      _mergeInto(trafficSources, day.trafficSourceBreakdown);
    }

    // Percentages
    final stateTotal = stateTraffic.values.fold<int>(0, (a, b) => a + b);
    final statePct = <String, double>{};
    for (final e in stateTraffic.entries) {
      statePct[e.key] = stateTotal > 0 ? (e.value / stateTotal) * 100 : 0;
    }

    final cityTotal = cityTraffic.values.fold<int>(0, (a, b) => a + b);
    final cityPct = <String, double>{};
    for (final e in cityTraffic.entries) {
      cityPct[e.key] = cityTotal > 0 ? (e.value / cityTotal) * 100 : 0;
    }

    // Country percentages
    final countryTotal = countryTraffic.values.fold<int>(0, (a, b) => a + b);
    final countryPct = <String, double>{};
    for (final e in countryTraffic.entries) {
      countryPct[e.key] = countryTotal > 0 ? (e.value / countryTotal) * 100 : 0;
    }

    final avgDuration = totalUnique > 0 ? totalWatchTime / totalUnique : 0.0;

    return ChannelAnalyticsSnapshot(
      channelId: channelId,
      channelName: channelName,
      totalVideoWatches: totalViews,
      totalUniqueViewers: totalUnique,
      totalImpressions: totalImpressions,
      averageWatchDuration: avgDuration,
      averageWatchPercentage: 0, // Needs video-level data
      totalWatchTimeSeconds: totalWatchTime,
      stateTraffic: stateTraffic,
      stateTrafficPercentage: statePct,
      cityTraffic: cityTraffic,
      cityTrafficPercentage: cityPct,
      countryTraffic: countryTraffic,
      countryTrafficPercentage: countryPct,
      urbanViewers: urban,
      ruralViewers: rural,
      trafficSourceBreakdown: trafficSources,
      dailyWatchTime: dailyWatchTime,
      dailyViews: dailyViews,
      dailySubscribers: dailySubscribers,
      generatedAt: DateTime.now(),
      videoCount: videoCount,
      totalEngagementScore: 0,
      subscriberViews: subViews,
      nonSubscriberViews: nonSubViews,
      returningViewers: returning,
      subscribersGained: subGained,
      subscribersLost: subLost,
    );
  }

  /// Fallback: build channel analytics from video-level daily stats
  Future<ChannelAnalyticsSnapshot> _buildChannelFromVideoStats(
    String channelId,
    String channelName,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final startKey = _dateFormat.format(start);
      final endKey = _dateFormat.format(end);

      // Fetch stats for this channel and filter locally to avoid composite index
      final snapshot = await _firestore
          .collection('video_stats_daily')
          .where('channelId', isEqualTo: channelId)
          .get();

      final allStats = snapshot.docs
          .map((doc) => DailyVideoStats.fromMap(doc.data()))
          .toList();

      // Filter by date range locally
      final filteredStats = allStats.where((stats) {
        return stats.dateKey.compareTo(startKey) >= 0 &&
            stats.dateKey.compareTo(endKey) <= 0;
      }).toList();

      if (filteredStats.isEmpty) {
        // Second level fallback: Read from live channel counters
        return await _buildChannelFromLiveCounters(channelId, channelName);
      }

      final dailyStats = filteredStats.take(500).toList();

      // Aggregate all video stats into channel-level
      var totalViews = 0;
      var totalUnique = 0;
      var totalWatchTime = 0;
      var subViews = 0;
      var nonSubViews = 0;
      var subGained = 0;
      var urban = 0;
      var rural = 0;
      final stateTraffic = <String, int>{};
      final cityTraffic = <String, int>{};
      final trafficSources = <String, int>{};
      final videoIds = <String>{};
      final dailySubscribers = <DateTime, int>{};

      for (final day in dailyStats) {
        totalViews += day.totalViews;
        totalUnique += day.uniqueViewers;
        totalWatchTime += day.totalWatchTimeSeconds;
        subViews += day.subscriberViews;
        nonSubViews += day.nonSubscriberViews;
        subGained += day.subscribersGained;
        urban += day.urbanViewers;
        rural += day.ruralViewers;
        videoIds.add(day.videoId);

        final existing = dailySubscribers[day.date] ?? 0;
        dailySubscribers[day.date] =
            existing + (day.subscribersGained - day.subscribersLost);

        _mergeInto(stateTraffic, day.stateTraffic);
        _mergeInto(cityTraffic, day.cityTraffic);
        _mergeInto(trafficSources, day.trafficSourceBreakdown);
      }

      final stateTotal = stateTraffic.values.fold<int>(0, (a, b) => a + b);
      final statePct = <String, double>{};
      for (final e in stateTraffic.entries) {
        statePct[e.key] = stateTotal > 0 ? (e.value / stateTotal) * 100 : 0;
      }

      final cityTotal = cityTraffic.values.fold<int>(0, (a, b) => a + b);
      final cityPct = <String, double>{};
      for (final e in cityTraffic.entries) {
        cityPct[e.key] = cityTotal > 0 ? (e.value / cityTotal) * 100 : 0;
      }

      return ChannelAnalyticsSnapshot(
        channelId: channelId,
        channelName: channelName,
        totalVideoWatches: totalViews,
        totalUniqueViewers: totalUnique,
        averageWatchDuration: totalUnique > 0
            ? totalWatchTime / totalUnique
            : 0,
        averageWatchPercentage: 0,
        totalWatchTimeSeconds: totalWatchTime,
        stateTraffic: stateTraffic,
        stateTrafficPercentage: statePct,
        cityTraffic: cityTraffic,
        cityTrafficPercentage: cityPct,
        urbanViewers: urban,
        ruralViewers: rural,
        trafficSourceBreakdown: trafficSources,
        dailySubscribers: dailySubscribers,
        generatedAt: DateTime.now(),
        videoCount: videoIds.length,
        totalEngagementScore: 0,
        subscriberViews: subViews,
        nonSubscriberViews: nonSubViews,
        subscribersGained: subGained,
      );
    } catch (e) {
      logger.error('Error building channel from video stats: $e', tag: _tag);
      return _buildChannelFromLiveCounters(channelId, channelName);
    }
  }

  /// Build channel analytics from live document counters (fallback)
  Future<ChannelAnalyticsSnapshot> _buildChannelFromLiveCounters(
    String channelId,
    String channelName,
  ) async {
    try {
      final doc = await _firestore.collection('channels').doc(channelId).get();
      if (!doc.exists) {
        return _createEmptyChannelAnalytics(channelId, channelName);
      }

      final data = doc.data()!;
      final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
      final views =
          (metrics['totalViews'] as num?)?.toInt() ??
          (data['viewCount'] as num?)?.toInt() ??
          0;
      final watchTime =
          (metrics['totalWatchTimeMinutes'] as num?)?.toInt() ?? 0;
      final subCount = (data['subscriberCount'] as num?)?.toInt() ?? 0;

      return ChannelAnalyticsSnapshot(
        channelId: channelId,
        channelName: data['name'] as String? ?? channelName,
        totalVideoWatches: views,
        totalUniqueViewers: views,
        averageWatchDuration: views > 0 ? (watchTime * 60) / views : 0,
        averageWatchPercentage: 0,
        totalWatchTimeSeconds: watchTime * 60,
        stateTraffic: {},
        stateTrafficPercentage: {},
        countryTraffic: {},
        countryTrafficPercentage: {},
        dailySubscribers: {DateTime.now(): subCount},
        dailyViews: {DateTime.now(): views},
        dailyWatchTime: {DateTime.now(): watchTime * 60},
        generatedAt: DateTime.now(),
        videoCount: (data['videoCount'] as num?)?.toInt() ?? 0,
        totalEngagementScore: 0,
        subscribersGained:
            subCount, // Fallback: show total as gained if no history
      );
    } catch (e) {
      logger.error('Error building channel from live counters: $e', tag: _tag);
      return _createEmptyChannelAnalytics(channelId, channelName);
    }
  }

  /// Helper to merge hourly stats into a video snapshot for real-time view
  VideoAnalyticsSnapshot _mergeHourlyIntoSnapshot(
    VideoAnalyticsSnapshot snapshot,
    HourlyVideoStats hourly,
  ) {
    // Only merge if hourly has data
    if (hourly.totalViews == 0) return snapshot;

    final updatedDailyViews = Map<DateTime, int>.from(snapshot.dailyViews);
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    updatedDailyViews[today] =
        (updatedDailyViews[today] ?? 0) + hourly.totalViews;

    final updatedDailyWatchTime = Map<DateTime, int>.from(
      snapshot.dailyWatchTime,
    );
    updatedDailyWatchTime[today] =
        (updatedDailyWatchTime[today] ?? 0) + hourly.totalWatchTimeSeconds;

    final updatedTrafficSources = Map<String, int>.from(
      snapshot.trafficSourceBreakdown,
    );
    _mergeInto(updatedTrafficSources, hourly.trafficSourceBreakdown);

    return VideoAnalyticsSnapshot(
      videoId: snapshot.videoId,
      title: snapshot.title,
      totalViews: snapshot.totalViews + hourly.totalViews,
      totalUniqueViewers: snapshot.totalUniqueViewers + hourly.uniqueViewers,
      totalImpressions:
          snapshot.totalImpressions, // Hourly doesn't track impressions yet
      averageWatchDuration:
          (snapshot.totalWatchTimeSeconds + hourly.totalWatchTimeSeconds) /
          (snapshot.totalUniqueViewers + hourly.uniqueViewers),
      averageWatchPercentage: snapshot.averageWatchPercentage,
      totalWatchTimeSeconds:
          snapshot.totalWatchTimeSeconds + hourly.totalWatchTimeSeconds,
      usersCompletedVideo:
          snapshot.usersCompletedVideo + hourly.watched100Percent,
      watchtimeCategoryCount: snapshot.watchtimeCategoryCount, // Approximate
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
      trafficSourceBreakdown: updatedTrafficSources,
      subscriberViews: snapshot.subscriberViews + hourly.subscriberViews,
      nonSubscriberViews:
          snapshot.nonSubscriberViews + hourly.nonSubscriberViews,
      returningViewers: snapshot.returningViewers,
      subscribersGained: snapshot.subscribersGained,
      subscribersLost: snapshot.subscribersLost,
      dailyWatchTime: updatedDailyWatchTime,
      dailyViews: updatedDailyViews,
      dailySubscribers: snapshot.dailySubscribers,
      liveViewerCount: snapshot.liveViewerCount,
      generatedAt: snapshot.generatedAt,
      nextUpdateAt: snapshot.nextUpdateAt,
      estimatedReadCount: snapshot.estimatedReadCount,
    );
  }

  // ===========================================================================
  // LIVE VIEWER COUNT
  // ===========================================================================

  /// Get count of users currently watching a video.
  /// Reads from `live_sessions/{videoId}/viewers` where lastPing > now - 60s
  Future<int> getLiveViewerCount(String videoId) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(seconds: 90));

      final snapshot = await _firestore
          .collection('live_sessions')
          .doc(videoId)
          .collection('viewers')
          .where('lastPing', isGreaterThan: Timestamp.fromDate(cutoff))
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      // Collection might not exist yet
      return 0;
    }
  }

  /// Get total live viewers across all channel's videos
  Future<int> getChannelLiveViewerCount(String channelId) async {
    try {
      // Read from channel-level counter
      final doc = await _firestore.collection('channels').doc(channelId).get();
      return (doc.data()?['liveViewerCount'] as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  void _mergeInto(Map<String, int> target, Map<String, int> source) {
    for (final e in source.entries) {
      target[e.key] = (target[e.key] ?? 0) + e.value;
    }
  }

  VideoAnalyticsSnapshot _createEmptyVideoAnalytics(
    String videoId,
    String title,
  ) {
    return VideoAnalyticsSnapshot(
      videoId: videoId,
      title: title,
      totalViews: 0,
      totalUniqueViewers: 0,
      averageWatchDuration: 0,
      averageWatchPercentage: 0,
      usersCompletedVideo: 0,
      watchtimeCategoryCount: {
        for (final cat in WatchtimeCategory.values) cat: 0,
      },
      stateTraffic: {},
      stateTrafficPercentage: {},
      countryTraffic: {},
      countryTrafficPercentage: {},
      deviceTypeBreakdown: {},
      qualityBreakdown: {},
      dailySubscribers: {},
      generatedAt: DateTime.now(),
      estimatedReadCount: 0,
    );
  }

  ChannelAnalyticsSnapshot _createEmptyChannelAnalytics(
    String channelId,
    String channelName,
  ) {
    return ChannelAnalyticsSnapshot(
      channelId: channelId,
      channelName: channelName,
      totalVideoWatches: 0,
      totalUniqueViewers: 0,
      averageWatchDuration: 0,
      averageWatchPercentage: 0,
      stateTraffic: {},
      stateTrafficPercentage: {},
      countryTraffic: {},
      countryTrafficPercentage: {},
      dailySubscribers: {},
      generatedAt: DateTime.now(),
      videoCount: 0,
      totalEngagementScore: 0,
    );
  }

  /// Invalidate all caches
  void clearAnalyticsCache() {
    _analyticsCache.clear();
    logger.info('Analytics cache cleared', tag: _tag);
  }

  /// Invalidate cache for specific video
  void invalidateVideoCache(String videoId) {
    _analyticsCache.removeWhere((key, _) => key.startsWith(videoId));
  }

  // ===========================================================================
  // HOURLY STATS (Real-time recent trends for fresh uploads)
  // ===========================================================================

  /// Fetch last N hours of stats for a video.
  /// Used for real-time trend graphs when daily aggregates haven't rolled up yet.
  /// Reads from `video_stats_hourly` collection.
  Future<List<HourlyVideoStats>> getRecentHourlyStats(
    String videoId, {
    int hours = 24,
  }) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(hours: hours));
      final cutoffKey = _hourFormat.format(cutoff);

      final snapshot = await _firestore
          .collection('video_stats_hourly')
          .where('videoId', isEqualTo: videoId)
          .where('hourKey', isGreaterThanOrEqualTo: cutoffKey)
          .orderBy('hourKey', descending: true)
          .limit(hours.clamp(1, 72)) // Max 72h
          .get();

      return snapshot.docs
          .map((doc) => HourlyVideoStats.fromMap(doc.data()))
          .toList();
    } catch (e) {
      logger.warning('Error fetching hourly stats: $e', tag: _tag);
      return [];
    }
  }

  /// Get aggregated stats for today by summing hourly docs.
  /// Useful for supplementing daily stats with today's partial data.
  Future<HourlyVideoStats?> getTodayAggregatedHourly(String videoId) async {
    try {
      final today = _dateFormat.format(DateTime.now());

      final snapshot = await _firestore
          .collection('video_stats_hourly')
          .where('videoId', isEqualTo: videoId)
          .where('hourKey', isGreaterThanOrEqualTo: '${today}_00')
          .where('hourKey', isLessThanOrEqualTo: '${today}_23')
          .get();

      if (snapshot.docs.isEmpty) return null;

      final hourlyStats = snapshot.docs
          .map((doc) => HourlyVideoStats.fromMap(doc.data()))
          .toList();

      // Aggregate all hourly docs into one
      var views = 0, unique = 0, watchTime = 0, subViews = 0, nonSubViews = 0;
      var bounced = 0;
      var w25 = 0;
      var w50 = 0;
      var w75 = 0;
      var w100 = 0;
      var flagged = 0;
      final trafficSources = <String, int>{};

      for (final h in hourlyStats) {
        views += h.totalViews;
        unique += h.uniqueViewers;
        watchTime += h.totalWatchTimeSeconds;
        subViews += h.subscriberViews;
        nonSubViews += h.nonSubscriberViews;
        bounced += h.bouncedUnder20s;
        w25 += h.watched25Percent;
        w50 += h.watched50Percent;
        w75 += h.watched75Percent;
        w100 += h.watched100Percent;
        flagged += h.flaggedFraudViews;
        _mergeInto(trafficSources, h.trafficSourceBreakdown);
      }

      return HourlyVideoStats(
        videoId: videoId,
        channelId: hourlyStats.first.channelId,
        hourKey: '${today}_aggregated',
        totalViews: views,
        uniqueViewers: unique,
        totalWatchTimeSeconds: watchTime,
        subscriberViews: subViews,
        nonSubscriberViews: nonSubViews,
        bouncedUnder20s: bounced,
        watched25Percent: w25,
        watched50Percent: w50,
        watched75Percent: w75,
        watched100Percent: w100,
        trafficSourceBreakdown: trafficSources,
        flaggedFraudViews: flagged,
        hour: DateTime.now(),
      );
    } catch (e) {
      logger.warning('Error fetching today hourly stats: $e', tag: _tag);
      return null;
    }
  }

  // ===========================================================================
  // SERVER-SIDE VIEW DEDUP (Anti-fraud: check dedup key exists)
  // ===========================================================================

  /// Check if a qualified view was already recorded for this user+video today.
  /// Uses `qualified_views/{videoId}_{userHash}_{YYYYMMDD}` collection.
  ///
  /// This is the SERVER-SIDE enforcement layer.
  /// The client-side GetStorage cooldown is a UX gate only.
  Future<bool> hasQualifiedViewToday(String videoId, String userId) async {
    try {
      final today = _dateFormat.format(DateTime.now());
      final dedupKey = '${videoId}_${userId}_$today';
      final doc = await _firestore
          .collection('qualified_views')
          .doc(dedupKey)
          .get();
      return doc.exists;
    } catch (e) {
      logger.warning('Error checking dedup: $e', tag: _tag);
      return false; // Allow on error (server Cloud Function is the real gate)
    }
  }

  // ===========================================================================
  // FRAUD ANALYTICS (Read flagged event counts)
  // ===========================================================================

  /// Get fraud overview for a video (flagged view count, fraud rate)
  Future<FraudOverview> getFraudOverview(
    String videoId, {
    int days = 28,
  }) async {
    try {
      final startKey = _dateFormat.format(
        DateTime.now().subtract(Duration(days: days)),
      );
      final endKey = _dateFormat.format(DateTime.now());

      // Read from hourly stats which carry flaggedFraudViews
      final snapshot = await _firestore
          .collection('video_stats_hourly')
          .where('videoId', isEqualTo: videoId)
          .where('hourKey', isGreaterThanOrEqualTo: '${startKey}_00')
          .where('hourKey', isLessThanOrEqualTo: '${endKey}_23')
          .limit(672) // 28 days * 24 hours
          .get();

      var totalViews = 0;
      var flaggedViews = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalViews += (data['totalViews'] as num?)?.toInt() ?? 0;
        flaggedViews += (data['flaggedFraudViews'] as num?)?.toInt() ?? 0;
      }

      return FraudOverview(
        totalViews: totalViews,
        flaggedViews: flaggedViews,
        cleanViews: totalViews - flaggedViews,
        fraudRate: totalViews > 0 ? (flaggedViews / totalViews) * 100 : 0,
      );
    } catch (e) {
      return FraudOverview.clean;
    }
  }

  // Private hour format
  final _hourFormat = DateFormat('yyyy_MM_dd_HH');
}

/// Internal class for caching analytics with timestamp
class _CachedAnalytics {
  _CachedAnalytics({required this.snapshot, required this.createdAt});
  final VideoAnalyticsSnapshot snapshot;
  final DateTime createdAt;
}

/// Fraud overview summary
class FraudOverview {
  // percentage

  const FraudOverview({
    required this.totalViews,
    required this.flaggedViews,
    required this.cleanViews,
    required this.fraudRate,
  });
  final int totalViews;
  final int flaggedViews;
  final int cleanViews;
  final double fraudRate;

  static const clean = FraudOverview(
    totalViews: 0,
    flaggedViews: 0,
    cleanViews: 0,
    fraudRate: 0,
  );
}
