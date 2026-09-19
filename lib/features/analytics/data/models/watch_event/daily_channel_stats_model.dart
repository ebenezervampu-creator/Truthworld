import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/features/analytics/data/models/watch_event/analytics_mapping_helpers.dart';

/// Daily aggregated stats for an entire channel.
/// Document ID format: `{channelId}_{YYYY_MM_DD}`
/// Collection: `channel_stats_daily`
class DailyChannelStats {
  DailyChannelStats({
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
    this.subscribersGained = 0,
    this.subscribersLost = 0,
    this.videoCount = 0,
    this.stateTraffic = const {},
    this.cityTraffic = const {},
    this.countryTraffic = const {},
    this.urbanViewers = 0,
    this.ruralViewers = 0,
    this.trafficSourceBreakdown = const {},
  });

  factory DailyChannelStats.fromMap(Map<String, dynamic> map) =>
      DailyChannelStats(
        channelId: map['channelId'] as String? ?? '',
        dateKey: map['dateKey'] as String? ?? '',
        totalViews: (map['totalViews'] as num?)?.toInt() ??
            (map['views'] as num?)?.toInt() ?? 0,
        totalImpressions: (map['totalImpressions'] as num?)?.toInt() ?? 0,
        uniqueViewers: (map['uniqueViewers'] as num?)?.toInt() ?? 0,
        totalWatchTimeSeconds:
            (map['totalWatchTimeSeconds'] as num?)?.toInt() ??
            (map['totalWatchSeconds'] as num?)?.toInt() ?? 0,
        subscriberViews: (map['subscriberViews'] as num?)?.toInt() ?? 0,
        nonSubscriberViews: (map['nonSubscriberViews'] as num?)?.toInt() ?? 0,
        returningViewers: (map['returningViewers'] as num?)?.toInt() ?? 0,
        newViewers: (map['newViewers'] as num?)?.toInt() ?? 0,
        subscribersGained: (map['subscribersGained'] as num?)?.toInt() ?? 0,
        subscribersLost: (map['subscribersLost'] as num?)?.toInt() ?? 0,
        videoCount: (map['videoCount'] as num?)?.toInt() ?? 0,
        stateTraffic: castIntMap(map['stateTraffic']),
        cityTraffic: castIntMap(map['cityTraffic']),
        countryTraffic: castIntMap(map['countryTraffic']),
        urbanViewers: (map['urbanViewers'] as num?)?.toInt() ?? 0,
        ruralViewers: (map['ruralViewers'] as num?)?.toInt() ?? 0,
        trafficSourceBreakdown: castIntMap(map['trafficSourceBreakdown']),
        date: map['date'] is Timestamp
            ? (map['date'] as Timestamp).toDate()
            : DateTime.now(),
      );

  final String channelId;
  final String dateKey;
  final int totalViews;
  final int totalImpressions;
  final int uniqueViewers;
  final int totalWatchTimeSeconds;
  final int subscriberViews;
  final int nonSubscriberViews;
  final int returningViewers;
  final int newViewers;
  final int subscribersGained;
  final int subscribersLost;
  final int videoCount; // Videos with views this day
  final Map<String, int> stateTraffic;
  final Map<String, int> cityTraffic;
  final Map<String, int> countryTraffic;
  final int urbanViewers;
  final int ruralViewers;
  final Map<String, int> trafficSourceBreakdown;
  final DateTime date;

  double get ctr =>
      totalImpressions > 0 ? (totalViews / totalImpressions) * 100 : 0;

  double get avgWatchDuration =>
      uniqueViewers > 0 ? totalWatchTimeSeconds / uniqueViewers : 0;

  double get totalWatchHours => totalWatchTimeSeconds / 3600;

  Map<String, dynamic> toMap() => {
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
    'subscribersGained': subscribersGained,
    'subscribersLost': subscribersLost,
    'videoCount': videoCount,
    'stateTraffic': stateTraffic,
    'cityTraffic': cityTraffic,
    'countryTraffic': countryTraffic,
    'urbanViewers': urbanViewers,
    'ruralViewers': ruralViewers,
    'trafficSourceBreakdown': trafficSourceBreakdown,
    'date': Timestamp.fromDate(date),
  };

  DailyChannelStats merge(DailyChannelStats other) {
    return DailyChannelStats(
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
      subscribersGained: subscribersGained + other.subscribersGained,
      subscribersLost: subscribersLost + other.subscribersLost,
      videoCount: videoCount + other.videoCount,
      stateTraffic: mergeMaps(stateTraffic, other.stateTraffic),
      cityTraffic: mergeMaps(cityTraffic, other.cityTraffic),
      countryTraffic: mergeMaps(countryTraffic, other.countryTraffic),
      urbanViewers: urbanViewers + other.urbanViewers,
      ruralViewers: ruralViewers + other.ruralViewers,
      trafficSourceBreakdown: mergeMaps(
        trafficSourceBreakdown,
        other.trafficSourceBreakdown,
      ),
      date: date,
    );
  }
}
