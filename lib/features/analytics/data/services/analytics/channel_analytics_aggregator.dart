import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/data/services/analytics/video_analytics_aggregator.dart';

/// Pure aggregation engine transforming raw DailyChannelStats and DailyVideoStats into ChannelAnalyticsSnapshot.
class ChannelAnalyticsAggregator {
  const ChannelAnalyticsAggregator();

  /// Aggregates a list of DailyChannelStats into a comprehensive ChannelAnalyticsSnapshot.
  ChannelAnalyticsSnapshot aggregateDailyChannelStats(
    String channelId,
    String channelName,
    List<DailyChannelStats> dailyStats, {
    int liveViewerCount = 0,
  }) {
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

      VideoAnalyticsAggregator.mergeInto(stateTraffic, day.stateTraffic);
      VideoAnalyticsAggregator.mergeInto(cityTraffic, day.cityTraffic);
      VideoAnalyticsAggregator.mergeInto(countryTraffic, day.countryTraffic);
      VideoAnalyticsAggregator.mergeInto(trafficSources, day.trafficSourceBreakdown);
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
      averageWatchPercentage: 0,
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
      liveViewerCount: liveViewerCount,
    );
  }

  /// Aggregates video-level daily stats up to the channel level as a fallback.
  ChannelAnalyticsSnapshot buildChannelFromVideoDailyStats(
    String channelId,
    String channelName,
    List<DailyVideoStats> dailyStats, {
    int liveViewerCount = 0,
  }) {
    var totalViews = 0;
    var totalUnique = 0;
    var totalWatchTime = 0;
    var subViews = 0;
    var nonSubViews = 0;
    var subGained = 0;
    var subLost = 0;
    var returning = 0;
    var urban = 0;
    var rural = 0;
    final stateTraffic = <String, int>{};
    final cityTraffic = <String, int>{};
    final countryTraffic = <String, int>{};
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
      subLost += day.subscribersLost;
      returning += day.returningViewers;
      urban += day.urbanViewers;
      rural += day.ruralViewers;
      videoIds.add(day.videoId);

      final existing = dailySubscribers[day.date] ?? 0;
      dailySubscribers[day.date] =
          existing + (day.subscribersGained - day.subscribersLost);

      VideoAnalyticsAggregator.mergeInto(stateTraffic, day.stateTraffic);
      VideoAnalyticsAggregator.mergeInto(cityTraffic, day.cityTraffic);
      VideoAnalyticsAggregator.mergeInto(countryTraffic, day.countryTraffic);
      VideoAnalyticsAggregator.mergeInto(trafficSources, day.trafficSourceBreakdown);
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

    final countryTotal = countryTraffic.values.fold<int>(0, (a, b) => a + b);
    final countryPct = <String, double>{};
    for (final e in countryTraffic.entries) {
      countryPct[e.key] = countryTotal > 0 ? (e.value / countryTotal) * 100 : 0;
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
      countryTraffic: countryTraffic,
      countryTrafficPercentage: countryPct,
      urbanViewers: urban,
      ruralViewers: rural,
      trafficSourceBreakdown: trafficSources,
      dailySubscribers: dailySubscribers,
      generatedAt: DateTime.now(),
      videoCount: videoIds.length,
      totalEngagementScore: 0,
      subscriberViews: subViews,
      nonSubscriberViews: nonSubViews,
      returningViewers: returning,
      subscribersGained: subGained,
      subscribersLost: subLost,
      liveViewerCount: liveViewerCount,
    );
  }

  /// Creates a clean zero-state channel snapshot.
  ChannelAnalyticsSnapshot createEmptyChannelAnalytics(
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
}
