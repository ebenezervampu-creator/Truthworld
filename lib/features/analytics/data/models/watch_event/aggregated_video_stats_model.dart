import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/features/analytics/data/models/watch_event/analytics_mapping_helpers.dart';

/// Daily aggregated stats for a single video.
/// Document ID format: `{videoId}_{YYYY_MM_DD}`
/// Collection: `video_stats_daily`
class DailyVideoStats {
  DailyVideoStats({
    required this.videoId,
    required this.channelId,
    required this.dateKey,
    required this.totalViews,
    required this.uniqueViewers,
    required this.totalWatchTimeSeconds,
    required this.date,
    this.totalImpressions = 0,
    this.subscriberViews = 0,
    this.nonSubscriberViews = 0,
    this.returningViewers = 0,
    this.newViewers = 0,
    this.bouncedUnder20s = 0,
    this.watched25Percent = 0,
    this.watched50Percent = 0,
    this.watched75Percent = 0,
    this.watched100Percent = 0,
    this.stateTraffic = const {},
    this.cityTraffic = const {},
    this.countryTraffic = const {},
    this.urbanViewers = 0,
    this.ruralViewers = 0,
    this.deviceBreakdown = const {},
    this.qualityBreakdown = const {},
    this.trafficSourceBreakdown = const {},
    this.subscribersGained = 0,
    this.subscribersLost = 0,
  });

  factory DailyVideoStats.fromMap(Map<String, dynamic> map) => DailyVideoStats(
    videoId: map['videoId'] as String? ?? '',
    channelId: map['channelId'] as String? ?? '',
    dateKey: map['dateKey'] as String? ?? '',
    totalViews: (map['totalViews'] as num?)?.toInt() ??
        (map['views'] as num?)?.toInt() ?? 0,
    totalImpressions: (map['totalImpressions'] as num?)?.toInt() ?? 0,
    uniqueViewers: (map['uniqueViewers'] as num?)?.toInt() ?? 0,
    totalWatchTimeSeconds: (map['totalWatchTimeSeconds'] as num?)?.toInt() ??
        (map['totalWatchSeconds'] as num?)?.toInt() ?? 0,
    subscriberViews: (map['subscriberViews'] as num?)?.toInt() ?? 0,
    nonSubscriberViews: (map['nonSubscriberViews'] as num?)?.toInt() ?? 0,
    returningViewers: (map['returningViewers'] as num?)?.toInt() ?? 0,
    newViewers: (map['newViewers'] as num?)?.toInt() ?? 0,
    bouncedUnder20s: (map['bouncedUnder20s'] as num?)?.toInt() ?? 0,
    watched25Percent: (map['watched25Percent'] as num?)?.toInt() ?? 0,
    watched50Percent: (map['watched50Percent'] as num?)?.toInt() ?? 0,
    watched75Percent: (map['watched75Percent'] as num?)?.toInt() ?? 0,
    watched100Percent: (map['watched100Percent'] as num?)?.toInt() ?? 0,
    stateTraffic: castIntMap(map['stateTraffic']),
    cityTraffic: castIntMap(map['cityTraffic']),
    countryTraffic: castIntMap(map['countryTraffic']),
    urbanViewers: (map['urbanViewers'] as num?)?.toInt() ?? 0,
    ruralViewers: (map['ruralViewers'] as num?)?.toInt() ?? 0,
    deviceBreakdown: castIntMap(map['deviceBreakdown']),
    qualityBreakdown: castIntMap(map['qualityBreakdown']),
    trafficSourceBreakdown: castIntMap(map['trafficSourceBreakdown']),
    subscribersGained: (map['subscribersGained'] as num?)?.toInt() ?? 0,
    subscribersLost: (map['subscribersLost'] as num?)?.toInt() ?? 0,
    date: map['date'] is Timestamp
        ? (map['date'] as Timestamp).toDate()
        : DateTime.now(),
  );

  final String videoId;
  final String channelId;
  final String dateKey; // YYYY_MM_DD
  final int totalViews; // Qualified views (20s+)
  final int totalImpressions; // Thumbnail shown count
  final int uniqueViewers;
  final int totalWatchTimeSeconds;
  final int subscriberViews;
  final int nonSubscriberViews;
  final int returningViewers;
  final int newViewers;

  // Completion buckets
  final int bouncedUnder20s;
  final int watched25Percent;
  final int watched50Percent;
  final int watched75Percent;
  final int watched100Percent;

  // Geographic
  final Map<String, int> stateTraffic; // State -> count
  final Map<String, int> cityTraffic; // City -> count
  final Map<String, int> countryTraffic; // Country -> count
  final int urbanViewers;
  final int ruralViewers;

  // Device & Quality
  final Map<String, int> deviceBreakdown;
  final Map<String, int> qualityBreakdown;

  // Traffic sources
  final Map<String, int> trafficSourceBreakdown;

  // Subscriber conversion
  final int subscribersGained;
  final int subscribersLost;

  final DateTime date;

  /// CTR = (views / impressions) * 100
  double get ctr =>
      totalImpressions > 0 ? (totalViews / totalImpressions) * 100 : 0;

  /// Average watch duration in seconds
  double get avgWatchDuration =>
      uniqueViewers > 0 ? totalWatchTimeSeconds / uniqueViewers : 0;

  /// Completion rate = (watched100% / uniqueViewers) * 100
  double get completionRate =>
      uniqueViewers > 0 ? (watched100Percent / uniqueViewers) * 100 : 0;

  Map<String, dynamic> toMap() => {
    'videoId': videoId,
    'channelId': channelId,
    'dateKey': dateKey,
    'totalViews': totalViews,
    'totalImpressions': totalImpressions,
    'uniqueViewers': uniqueViewers,
    'totalWatchTimeSeconds': totalWatchTimeSeconds,
    'subscriberViews': subscriberViews,
    'nonSubscriberViews': nonSubscriberViews,
    'returningViewers': returningViewers,
    'newViewers': newViewers,
    'bouncedUnder20s': bouncedUnder20s,
    'watched25Percent': watched25Percent,
    'watched50Percent': watched50Percent,
    'watched75Percent': watched75Percent,
    'watched100Percent': watched100Percent,
    'stateTraffic': stateTraffic,
    'cityTraffic': cityTraffic,
    'countryTraffic': countryTraffic,
    'urbanViewers': urbanViewers,
    'ruralViewers': ruralViewers,
    'deviceBreakdown': deviceBreakdown,
    'qualityBreakdown': qualityBreakdown,
    'trafficSourceBreakdown': trafficSourceBreakdown,
    'subscribersGained': subscribersGained,
    'subscribersLost': subscribersLost,
    'date': Timestamp.fromDate(date),
  };

  /// Merge two daily stats (for aggregation across date ranges)
  DailyVideoStats merge(DailyVideoStats other) {
    return DailyVideoStats(
      videoId: videoId,
      channelId: channelId,
      dateKey: dateKey,
      totalViews: totalViews + other.totalViews,
      totalImpressions: totalImpressions + other.totalImpressions,
      uniqueViewers: uniqueViewers + other.uniqueViewers,
      totalWatchTimeSeconds:
          totalWatchTimeSeconds + other.totalWatchTimeSeconds,
      subscriberViews: subscriberViews + other.subscriberViews,
      nonSubscriberViews: nonSubscriberViews + other.nonSubscriberViews,
      returningViewers: returningViewers + other.returningViewers,
      newViewers: newViewers + other.newViewers,
      bouncedUnder20s: bouncedUnder20s + other.bouncedUnder20s,
      watched25Percent: watched25Percent + other.watched25Percent,
      watched50Percent: watched50Percent + other.watched50Percent,
      watched75Percent: watched75Percent + other.watched75Percent,
      watched100Percent: watched100Percent + other.watched100Percent,
      stateTraffic: mergeMaps(stateTraffic, other.stateTraffic),
      cityTraffic: mergeMaps(cityTraffic, other.cityTraffic),
      countryTraffic: mergeMaps(countryTraffic, other.countryTraffic),
      urbanViewers: urbanViewers + other.urbanViewers,
      ruralViewers: ruralViewers + other.ruralViewers,
      deviceBreakdown: mergeMaps(deviceBreakdown, other.deviceBreakdown),
      qualityBreakdown: mergeMaps(qualityBreakdown, other.qualityBreakdown),
      trafficSourceBreakdown: mergeMaps(
        trafficSourceBreakdown,
        other.trafficSourceBreakdown,
      ),
      subscribersGained: subscribersGained + other.subscribersGained,
      subscribersLost: subscribersLost + other.subscribersLost,
      date: date,
    );
  }
}

/// Hourly aggregated stats for a single video.
/// Document ID format: `{videoId}_{YYYY_MM_DD_HH}`
/// Collection: `video_stats_hourly`
///
/// Purpose: For videos uploaded today, creators can see real-time trends
/// without waiting for daily rollup. Hourly docs are auto-TTL'd after 72h
/// by a Cloud Function cleanup job.
class HourlyVideoStats {
  HourlyVideoStats({
    required this.videoId,
    required this.channelId,
    required this.hourKey,
    required this.totalViews,
    required this.uniqueViewers,
    required this.totalWatchTimeSeconds,
    required this.hour,
    this.subscriberViews = 0,
    this.nonSubscriberViews = 0,
    this.bouncedUnder20s = 0,
    this.watched25Percent = 0,
    this.watched50Percent = 0,
    this.watched75Percent = 0,
    this.watched100Percent = 0,
    this.trafficSourceBreakdown = const {},
    this.flaggedFraudViews = 0,
  });

  factory HourlyVideoStats.fromMap(Map<String, dynamic> map) =>
      HourlyVideoStats(
        videoId: map['videoId'] as String? ?? '',
        channelId: map['channelId'] as String? ?? '',
        hourKey: map['hourKey'] as String? ?? '',
        totalViews: (map['totalViews'] as num?)?.toInt() ?? 0,
        uniqueViewers: (map['uniqueViewers'] as num?)?.toInt() ?? 0,
        totalWatchTimeSeconds:
            (map['totalWatchTimeSeconds'] as num?)?.toInt() ?? 0,
        subscriberViews: (map['subscriberViews'] as num?)?.toInt() ?? 0,
        nonSubscriberViews: (map['nonSubscriberViews'] as num?)?.toInt() ?? 0,
        bouncedUnder20s: (map['bouncedUnder20s'] as num?)?.toInt() ?? 0,
        watched25Percent: (map['watched25Percent'] as num?)?.toInt() ?? 0,
        watched50Percent: (map['watched50Percent'] as num?)?.toInt() ?? 0,
        watched75Percent: (map['watched75Percent'] as num?)?.toInt() ?? 0,
        watched100Percent: (map['watched100Percent'] as num?)?.toInt() ?? 0,
        trafficSourceBreakdown: castIntMap(map['trafficSourceBreakdown']),
        flaggedFraudViews: (map['flaggedFraudViews'] as num?)?.toInt() ?? 0,
        hour: map['hour'] is Timestamp
            ? (map['hour'] as Timestamp).toDate()
            : DateTime.now(),
      );

  final String videoId;
  final String channelId;
  final String hourKey; // YYYY_MM_DD_HH (24h format)
  final int totalViews;
  final int uniqueViewers;
  final int totalWatchTimeSeconds;
  final int subscriberViews;
  final int nonSubscriberViews;
  final int bouncedUnder20s;
  final int watched25Percent;
  final int watched50Percent;
  final int watched75Percent;
  final int watched100Percent;
  final Map<String, int> trafficSourceBreakdown;
  final int flaggedFraudViews; // Views with fraudScore > 0.5
  final DateTime hour;

  double get avgWatchDuration =>
      uniqueViewers > 0 ? totalWatchTimeSeconds / uniqueViewers : 0;

  double get completionRate =>
      uniqueViewers > 0 ? (watched100Percent / uniqueViewers) * 100 : 0;

  /// Clean views = total - flagged fraud
  int get cleanViews => (totalViews - flaggedFraudViews).clamp(0, totalViews);

  Map<String, dynamic> toMap() => {
    'videoId': videoId,
    'channelId': channelId,
    'hourKey': hourKey,
    'totalViews': totalViews,
    'uniqueViewers': uniqueViewers,
    'totalWatchTimeSeconds': totalWatchTimeSeconds,
    'subscriberViews': subscriberViews,
    'nonSubscriberViews': nonSubscriberViews,
    'bouncedUnder20s': bouncedUnder20s,
    'watched25Percent': watched25Percent,
    'watched50Percent': watched50Percent,
    'watched75Percent': watched75Percent,
    'watched100Percent': watched100Percent,
    'trafficSourceBreakdown': trafficSourceBreakdown,
    'flaggedFraudViews': flaggedFraudViews,
    'hour': Timestamp.fromDate(hour),
  };
}
