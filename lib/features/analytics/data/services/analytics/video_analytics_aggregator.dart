import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';

/// Pure aggregation engine transforming raw DailyVideoStats and HourlyVideoStats into VideoAnalyticsSnapshot.
class VideoAnalyticsAggregator {
  const VideoAnalyticsAggregator();

  /// Utility to merge map count metrics.
  static void mergeInto(Map<String, int> target, Map<String, int> source) {
    for (final e in source.entries) {
      target[e.key] = (target[e.key] ?? 0) + e.value;
    }
  }

  /// Aggregates a list of daily stats into a comprehensive VideoAnalyticsSnapshot.
  VideoAnalyticsSnapshot aggregateVideoStats(
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

      mergeInto(stateTraffic, day.stateTraffic);
      mergeInto(cityTraffic, day.cityTraffic);
      mergeInto(countryTraffic, day.countryTraffic);
      mergeInto(deviceBreakdown, day.deviceBreakdown);
      mergeInto(qualityBreakdown, day.qualityBreakdown);
      mergeInto(trafficSources, day.trafficSourceBreakdown);
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

    // Avg watch percentage
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

  /// Merges hourly stats into a video snapshot for partial real-time view.
  VideoAnalyticsSnapshot mergeHourlyIntoSnapshot(
    VideoAnalyticsSnapshot snapshot,
    HourlyVideoStats hourly,
  ) {
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
    mergeInto(updatedTrafficSources, hourly.trafficSourceBreakdown);

    return VideoAnalyticsSnapshot(
      videoId: snapshot.videoId,
      title: snapshot.title,
      totalViews: snapshot.totalViews + hourly.totalViews,
      totalUniqueViewers: snapshot.totalUniqueViewers + hourly.uniqueViewers,
      totalImpressions: snapshot.totalImpressions,
      averageWatchDuration:
          (snapshot.totalWatchTimeSeconds + hourly.totalWatchTimeSeconds) /
          (snapshot.totalUniqueViewers + hourly.uniqueViewers),
      averageWatchPercentage: snapshot.averageWatchPercentage,
      totalWatchTimeSeconds:
          snapshot.totalWatchTimeSeconds + hourly.totalWatchTimeSeconds,
      usersCompletedVideo:
          snapshot.usersCompletedVideo + hourly.watched100Percent,
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

  /// Creates a clean zero-state video snapshot.
  VideoAnalyticsSnapshot createEmptyVideoAnalytics(
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
}
