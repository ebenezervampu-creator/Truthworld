import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/watch_time_formatter.dart';
import 'package:truthworld/features/analytics/data/models/watch_event/analytics_mapping_helpers.dart';

/// Channel-level aggregated analytics
class ChannelAnalyticsSnapshot {
  ChannelAnalyticsSnapshot({
    required this.channelId,
    required this.channelName,
    required this.totalVideoWatches,
    required this.totalUniqueViewers,
    required this.averageWatchDuration,
    required this.averageWatchPercentage,
    required this.stateTraffic,
    required this.stateTrafficPercentage,
    required this.generatedAt,
    required this.videoCount,
    required this.totalEngagementScore,
    this.totalImpressions = 0,
    this.totalWatchTimeSeconds = 0,
    this.cityTraffic = const {},
    this.cityTrafficPercentage = const {},
    this.countryTraffic = const {},
    this.countryTrafficPercentage = const {},
    this.urbanViewers = 0,
    this.ruralViewers = 0,
    this.trafficSourceBreakdown = const {},
    this.dailyWatchTime = const {},
    this.dailyViews = const {},
    this.dailySubscribers = const {},
    this.subscriberViews = 0,
    this.nonSubscriberViews = 0,
    this.returningViewers = 0,
    this.subscribersGained = 0,
    this.subscribersLost = 0,
    this.liveViewerCount = 0,
  });

  factory ChannelAnalyticsSnapshot.fromMap(
    Map<String, dynamic> map,
  ) => ChannelAnalyticsSnapshot(
    channelId: map['channelId'] as String? ?? '',
    channelName: map['channelName'] as String? ?? '',
    totalVideoWatches: (map['totalVideoWatches'] as num?)?.toInt() ?? 0,
    totalUniqueViewers: (map['totalUniqueViewers'] as num?)?.toInt() ?? 0,
    totalImpressions: (map['totalImpressions'] as num?)?.toInt() ?? 0,
    averageWatchDuration:
        (map['averageWatchDuration'] as num?)?.toDouble() ?? 0,
    averageWatchPercentage:
        (map['averageWatchPercentage'] as num?)?.toDouble() ?? 0,
    totalWatchTimeSeconds: (map['totalWatchTimeSeconds'] as num?)?.toInt() ?? 0,
    stateTraffic: castIntMap(map['stateTraffic']),
    stateTrafficPercentage: castDoubleMap(map['stateTrafficPercentage']),
    cityTraffic: castIntMap(map['cityTraffic']),
    cityTrafficPercentage: castDoubleMap(map['cityTrafficPercentage']),
    countryTraffic: castIntMap(map['countryTraffic']),
    countryTrafficPercentage: castDoubleMap(map['countryTrafficPercentage']),
    urbanViewers: (map['urbanViewers'] as num?)?.toInt() ?? 0,
    ruralViewers: (map['ruralViewers'] as num?)?.toInt() ?? 0,
    trafficSourceBreakdown: castIntMap(map['trafficSourceBreakdown']),
    dailyWatchTime: castDateIntMap(map['dailyWatchTime']),
    dailyViews: castDateIntMap(map['dailyViews']),
    dailySubscribers: castDateIntMap(map['dailySubscribers']),
    generatedAt: map['generatedAt'] is Timestamp
        ? (map['generatedAt'] as Timestamp).toDate()
        : DateTime.now(),
    videoCount: (map['videoCount'] as num?)?.toInt() ?? 0,
    totalEngagementScore:
        (map['totalEngagementScore'] as num?)?.toDouble() ?? 0,
    subscriberViews: (map['subscriberViews'] as num?)?.toInt() ?? 0,
    nonSubscriberViews: (map['nonSubscriberViews'] as num?)?.toInt() ?? 0,
    returningViewers: (map['returningViewers'] as num?)?.toInt() ?? 0,
    subscribersGained: (map['subscribersGained'] as num?)?.toInt() ?? 0,
    subscribersLost: (map['subscribersLost'] as num?)?.toInt() ?? 0,
    liveViewerCount: (map['liveViewerCount'] as num?)?.toInt() ?? 0,
  );

  final String channelId;
  final String channelName;
  final int totalVideoWatches;
  final int totalUniqueViewers;
  final int totalImpressions;
  final double averageWatchDuration;
  final double averageWatchPercentage;
  final int totalWatchTimeSeconds;
  final Map<String, int> stateTraffic;
  final Map<String, double> stateTrafficPercentage;
  final Map<String, int> cityTraffic;
  final Map<String, double> cityTrafficPercentage;
  final Map<String, int> countryTraffic;
  final Map<String, double> countryTrafficPercentage;
  final int urbanViewers;
  final int ruralViewers;
  final Map<String, int> trafficSourceBreakdown;
  final Map<DateTime, int> dailyWatchTime;
  final Map<DateTime, int> dailyViews;
  final Map<DateTime, int> dailySubscribers;
  final DateTime generatedAt;
  final int videoCount;
  final double totalEngagementScore;
  final int subscriberViews;
  final int nonSubscriberViews;
  final int returningViewers;
  final int subscribersGained;
  final int subscribersLost;
  final int liveViewerCount;

  /// Total watch hours across channel
  double get totalWatchHours => totalWatchTimeSeconds / 3600;

  /// Formatted total watch time
  String get totalWatchTimeFormatted =>
      WatchTimeFormatter.format(totalWatchTimeSeconds);

  /// CTR
  double get ctr =>
      totalImpressions > 0 ? (totalVideoWatches / totalImpressions) * 100 : 0;

  /// Average engagement score per video
  double getAverageEngagementScore() =>
      videoCount > 0 ? totalEngagementScore / videoCount : 0;

  /// Urban percentage
  double get urbanPercentage {
    final total = urbanViewers + ruralViewers;
    return total > 0 ? (urbanViewers / total) * 100 : 0;
  }

  /// Rural percentage
  double get ruralPercentage {
    final total = urbanViewers + ruralViewers;
    return total > 0 ? (ruralViewers / total) * 100 : 0;
  }

  /// Subscriber conversion rate
  double get subscriberConversionRate =>
      totalVideoWatches > 0 ? (subscribersGained / totalVideoWatches) * 100 : 0;

  Map<String, dynamic> toMap() => {
    'channelId': channelId,
    'channelName': channelName,
    'totalVideoWatches': totalVideoWatches,
    'totalUniqueViewers': totalUniqueViewers,
    'totalImpressions': totalImpressions,
    'averageWatchDuration': averageWatchDuration,
    'averageWatchPercentage': averageWatchPercentage,
    'totalWatchTimeSeconds': totalWatchTimeSeconds,
    'stateTraffic': stateTraffic,
    'stateTrafficPercentage': stateTrafficPercentage,
    'cityTraffic': cityTraffic,
    'cityTrafficPercentage': cityTrafficPercentage,
    'countryTraffic': countryTraffic,
    'countryTrafficPercentage': countryTrafficPercentage,
    'urbanViewers': urbanViewers,
    'ruralViewers': ruralViewers,
    'trafficSourceBreakdown': trafficSourceBreakdown,
    'dailyWatchTime': dailyWatchTime.map(
      (k, v) => MapEntry(k.toIso8601String(), v),
    ),
    'dailyViews': dailyViews.map((k, v) => MapEntry(k.toIso8601String(), v)),
    'dailySubscribers': dailySubscribers.map(
      (k, v) => MapEntry(k.toIso8601String(), v),
    ),
    'generatedAt': Timestamp.fromDate(generatedAt),
    'videoCount': videoCount,
    'totalEngagementScore': totalEngagementScore,
    'subscriberViews': subscriberViews,
    'nonSubscriberViews': nonSubscriberViews,
    'returningViewers': returningViewers,
    'subscribersGained': subscribersGained,
    'subscribersLost': subscribersLost,
    'liveViewerCount': liveViewerCount,
  };

  ChannelAnalyticsSnapshot copyWith({
    String? channelId,
    String? channelName,
    int? totalVideoWatches,
    int? totalUniqueViewers,
    int? totalImpressions,
    double? averageWatchDuration,
    double? averageWatchPercentage,
    int? totalWatchTimeSeconds,
    Map<String, int>? stateTraffic,
    Map<String, double>? stateTrafficPercentage,
    Map<String, int>? cityTraffic,
    Map<String, double>? cityTrafficPercentage,
    Map<String, int>? countryTraffic,
    Map<String, double>? countryTrafficPercentage,
    int? urbanViewers,
    int? ruralViewers,
    Map<String, int>? trafficSourceBreakdown,
    Map<DateTime, int>? dailyWatchTime,
    Map<DateTime, int>? dailyViews,
    Map<DateTime, int>? dailySubscribers,
    DateTime? generatedAt,
    int? videoCount,
    double? totalEngagementScore,
    int? subscriberViews,
    int? nonSubscriberViews,
    int? returningViewers,
    int? subscribersGained,
    int? subscribersLost,
    int? liveViewerCount,
  }) {
    return ChannelAnalyticsSnapshot(
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      totalVideoWatches: totalVideoWatches ?? this.totalVideoWatches,
      totalUniqueViewers: totalUniqueViewers ?? this.totalUniqueViewers,
      totalImpressions: totalImpressions ?? this.totalImpressions,
      averageWatchDuration: averageWatchDuration ?? this.averageWatchDuration,
      averageWatchPercentage: averageWatchPercentage ?? this.averageWatchPercentage,
      totalWatchTimeSeconds: totalWatchTimeSeconds ?? this.totalWatchTimeSeconds,
      stateTraffic: stateTraffic ?? this.stateTraffic,
      stateTrafficPercentage: stateTrafficPercentage ?? this.stateTrafficPercentage,
      cityTraffic: cityTraffic ?? this.cityTraffic,
      cityTrafficPercentage: cityTrafficPercentage ?? this.cityTrafficPercentage,
      countryTraffic: countryTraffic ?? this.countryTraffic,
      countryTrafficPercentage: countryTrafficPercentage ?? this.countryTrafficPercentage,
      urbanViewers: urbanViewers ?? this.urbanViewers,
      ruralViewers: ruralViewers ?? this.ruralViewers,
      trafficSourceBreakdown: trafficSourceBreakdown ?? this.trafficSourceBreakdown,
      dailyWatchTime: dailyWatchTime ?? this.dailyWatchTime,
      dailyViews: dailyViews ?? this.dailyViews,
      dailySubscribers: dailySubscribers ?? this.dailySubscribers,
      generatedAt: generatedAt ?? this.generatedAt,
      videoCount: videoCount ?? this.videoCount,
      totalEngagementScore: totalEngagementScore ?? this.totalEngagementScore,
      subscriberViews: subscriberViews ?? this.subscriberViews,
      nonSubscriberViews: nonSubscriberViews ?? this.nonSubscriberViews,
      returningViewers: returningViewers ?? this.returningViewers,
      subscribersGained: subscribersGained ?? this.subscribersGained,
      subscribersLost: subscribersLost ?? this.subscribersLost,
      liveViewerCount: liveViewerCount ?? this.liveViewerCount,
    );
  }
}
