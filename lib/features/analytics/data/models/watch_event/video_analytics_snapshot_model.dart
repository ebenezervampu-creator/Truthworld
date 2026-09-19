import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/watch_time_formatter.dart';
import 'package:truthworld/features/analytics/data/models/watch_event/analytics_mapping_helpers.dart';
import 'package:truthworld/features/analytics/data/models/watch_event/watch_event_types.dart';

/// Video-level analytics snapshot (computed from daily aggregates)
class VideoAnalyticsSnapshot {
  VideoAnalyticsSnapshot({
    required this.videoId,
    required this.title,
    required this.totalViews,
    required this.totalUniqueViewers,
    required this.averageWatchDuration,
    required this.averageWatchPercentage,
    required this.usersCompletedVideo,
    required this.watchtimeCategoryCount,
    required this.stateTraffic,
    required this.stateTrafficPercentage,
    required this.deviceTypeBreakdown,
    required this.qualityBreakdown,
    required this.generatedAt,
    required this.estimatedReadCount,
    this.totalImpressions = 0,
    this.totalWatchTimeSeconds = 0,
    this.cityTraffic = const {},
    this.cityTrafficPercentage = const {},
    this.countryTraffic = const {},
    this.countryTrafficPercentage = const {},
    this.urbanViewers = 0,
    this.ruralViewers = 0,
    this.trafficSourceBreakdown = const {},
    this.subscriberViews = 0,
    this.nonSubscriberViews = 0,
    this.returningViewers = 0,
    this.subscribersGained = 0,
    this.subscribersLost = 0,
    this.liveViewerCount = 0,
    this.nextUpdateAt,
    this.dailyWatchTime = const {},
    this.dailyViews = const {},
    this.dailySubscribers = const {},
    this.suspectedFraudViews = 0,
    this.confirmedFraudViews = 0,
  });

  factory VideoAnalyticsSnapshot.fromMap(Map<String, dynamic> map) {
    final wtcCount = <WatchtimeCategory, int>{};
    (map['watchtimeCategoryCount'] as Map<String, dynamic>?)?.forEach((
      key,
      value,
    ) {
      final category = WatchtimeCategory.values.firstWhere(
        (e) => e.name == key,
        orElse: () => WatchtimeCategory.lessThan20,
      );
      wtcCount[category] = (value as num).toInt();
    });

    return VideoAnalyticsSnapshot(
      videoId: map['videoId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      totalViews: (map['totalViews'] as num?)?.toInt() ?? 0,
      totalUniqueViewers: (map['totalUniqueViewers'] as num?)?.toInt() ?? 0,
      totalImpressions: (map['totalImpressions'] as num?)?.toInt() ?? 0,
      averageWatchDuration:
          (map['averageWatchDuration'] as num?)?.toDouble() ?? 0,
      averageWatchPercentage:
          (map['averageWatchPercentage'] as num?)?.toDouble() ?? 0,
      totalWatchTimeSeconds:
          (map['totalWatchTimeSeconds'] as num?)?.toInt() ?? 0,
      usersCompletedVideo: (map['usersCompletedVideo'] as num?)?.toInt() ?? 0,
      watchtimeCategoryCount: wtcCount,
      stateTraffic: castIntMap(map['stateTraffic']),
      stateTrafficPercentage: castDoubleMap(map['stateTrafficPercentage']),
      cityTraffic: castIntMap(map['cityTraffic']),
      cityTrafficPercentage: castDoubleMap(map['cityTrafficPercentage']),
      countryTraffic: castIntMap(map['countryTraffic']),
      countryTrafficPercentage: castDoubleMap(map['countryTrafficPercentage']),
      urbanViewers: (map['urbanViewers'] as num?)?.toInt() ?? 0,
      ruralViewers: (map['ruralViewers'] as num?)?.toInt() ?? 0,
      deviceTypeBreakdown: castIntMap(map['deviceTypeBreakdown']),
      qualityBreakdown: castIntMap(map['qualityBreakdown']),
      trafficSourceBreakdown: castIntMap(map['trafficSourceBreakdown']),
      subscriberViews: (map['subscriberViews'] as num?)?.toInt() ?? 0,
      nonSubscriberViews: (map['nonSubscriberViews'] as num?)?.toInt() ?? 0,
      returningViewers: (map['returningViewers'] as num?)?.toInt() ?? 0,
      subscribersGained: (map['subscribersGained'] as num?)?.toInt() ?? 0,
      subscribersLost: (map['subscribersLost'] as num?)?.toInt() ?? 0,
      liveViewerCount: (map['liveViewerCount'] as num?)?.toInt() ?? 0,
      generatedAt: map['generatedAt'] is Timestamp
          ? (map['generatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      nextUpdateAt:
          map['nextUpdateAt'] != null && map['nextUpdateAt'] is Timestamp
          ? (map['nextUpdateAt'] as Timestamp).toDate()
          : null,
      estimatedReadCount: (map['estimatedReadCount'] as num?)?.toInt() ?? 0,
      dailyWatchTime: castDateIntMap(map['dailyWatchTime']),
      dailyViews: castDateIntMap(map['dailyViews']),
      dailySubscribers: castDateIntMap(map['dailySubscribers']),
      suspectedFraudViews: (map['suspectedFraudViews'] as num?)?.toInt() ?? 0,
      confirmedFraudViews: (map['confirmedFraudViews'] as num?)?.toInt() ?? 0,
    );
  }

  final String videoId;
  final String title;
  final int totalViews;
  final int totalUniqueViewers;
  final int totalImpressions;
  final double averageWatchDuration; // Seconds
  final double averageWatchPercentage; // 0-100
  final int totalWatchTimeSeconds; // Absolute total
  final int usersCompletedVideo;
  final Map<WatchtimeCategory, int> watchtimeCategoryCount;
  final Map<String, int> stateTraffic;
  final Map<String, double> stateTrafficPercentage;
  final Map<String, int> cityTraffic;
  final Map<String, double> cityTrafficPercentage;
  final Map<String, int> countryTraffic;
  final Map<String, double> countryTrafficPercentage;
  final int urbanViewers;
  final int ruralViewers;
  final Map<String, int> deviceTypeBreakdown;
  final Map<String, int> qualityBreakdown;
  final Map<String, int> trafficSourceBreakdown;
  final int subscriberViews;
  final int nonSubscriberViews;
  final int returningViewers;
  final int subscribersGained;
  final int subscribersLost;
  final int liveViewerCount; // Current concurrent viewers
  final DateTime generatedAt;
  final DateTime? nextUpdateAt;
  final int estimatedReadCount;
  final Map<DateTime, int> dailyWatchTime; // Date -> Seconds watched
  final Map<DateTime, int> dailyViews; // Date -> Views count
  final Map<DateTime, int>
  dailySubscribers; // Date -> Net subscribers (Gained - Lost)

  // Multi-tier fraud metric separation
  final int suspectedFraudViews; // Views flagged with fraudScore > 0.5
  final int confirmedFraudViews;

  /// CTR = (views / impressions) * 100
  double get ctr =>
      totalImpressions > 0 ? (totalViews / totalImpressions) * 100 : 0;

  /// Clean views = total - suspected - confirmed fraud
  int get cleanViews => (totalViews - suspectedFraudViews - confirmedFraudViews)
      .clamp(0, totalViews);

  /// Fraud rate = (suspected + confirmed) / total * 100
  double get fraudRate => totalViews > 0
      ? ((suspectedFraudViews + confirmedFraudViews) / totalViews) * 100
      : 0;

  /// View quality score (0-100): percentage of views that are clean
  double get viewQualityScore =>
      totalViews > 0 ? (cleanViews / totalViews) * 100 : 100;

  /// Get top N states by traffic
  List<MapEntry<String, double>> getTopStates({int limit = 5}) {
    final sorted = stateTrafficPercentage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  /// Get top N cities by traffic
  List<MapEntry<String, double>> getTopCities({int limit = 10}) {
    final total = cityTraffic.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return [];
    final sorted = cityTraffic.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) {
      return MapEntry(e.key, (e.value / total) * 100);
    }).toList();
  }

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

  /// Formatted total watch time
  String get totalWatchTimeFormatted =>
      WatchTimeFormatter.format(totalWatchTimeSeconds);

  /// Get completion rate percentage
  double getCompletionRate() => totalUniqueViewers > 0
      ? (usersCompletedVideo / totalUniqueViewers) * 100
      : 0;

  /// Get engagement score (0-100)
  double getEngagementScore() {
    final completionRate = getCompletionRate();
    final avgWatchRate = averageWatchPercentage;
    return (completionRate * 0.6) + (avgWatchRate * 0.4);
  }

  /// Subscriber conversion rate
  double get subscriberConversionRate =>
      totalViews > 0 ? (subscribersGained / totalViews) * 100 : 0;

  Map<String, dynamic> toMap() => {
    'videoId': videoId,
    'title': title,
    'totalViews': totalViews,
    'totalUniqueViewers': totalUniqueViewers,
    'totalImpressions': totalImpressions,
    'averageWatchDuration': averageWatchDuration,
    'averageWatchPercentage': averageWatchPercentage,
    'totalWatchTimeSeconds': totalWatchTimeSeconds,
    'usersCompletedVideo': usersCompletedVideo,
    'watchtimeCategoryCount': watchtimeCategoryCount.map(
      (k, v) => MapEntry(k.name, v),
    ),
    'stateTraffic': stateTraffic,
    'stateTrafficPercentage': stateTrafficPercentage,
    'cityTraffic': cityTraffic,
    'cityTrafficPercentage': cityTrafficPercentage,
    'countryTraffic': countryTraffic,
    'countryTrafficPercentage': countryTrafficPercentage,
    'urbanViewers': urbanViewers,
    'ruralViewers': ruralViewers,
    'deviceTypeBreakdown': deviceTypeBreakdown,
    'qualityBreakdown': qualityBreakdown,
    'trafficSourceBreakdown': trafficSourceBreakdown,
    'subscriberViews': subscriberViews,
    'nonSubscriberViews': nonSubscriberViews,
    'returningViewers': returningViewers,
    'subscribersGained': subscribersGained,
    'subscribersLost': subscribersLost,
    'liveViewerCount': liveViewerCount,
    'generatedAt': Timestamp.fromDate(generatedAt),
    'nextUpdateAt': nextUpdateAt != null
        ? Timestamp.fromDate(nextUpdateAt!)
        : null,
    'estimatedReadCount': estimatedReadCount,
    'dailyWatchTime': dailyWatchTime.map(
      (k, v) => MapEntry(k.toIso8601String(), v),
    ),
    'dailyViews': dailyViews.map((k, v) => MapEntry(k.toIso8601String(), v)),
    'dailySubscribers': dailySubscribers.map(
      (k, v) => MapEntry(k.toIso8601String(), v),
    ),
    'suspectedFraudViews': suspectedFraudViews,
    'confirmedFraudViews': confirmedFraudViews,
  };
}
