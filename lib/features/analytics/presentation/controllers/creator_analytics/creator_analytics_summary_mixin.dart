import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/utils/watch_time_formatter.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics/creator_geo_taxonomy_helper.dart';

/// Mixin managing reactive top-level creator summary metrics, retention calculations,
/// and live viewer indicators.
mixin CreatorAnalyticsSummaryMixin on BaseController {
  // Summary metrics (reactive)
  final engagementScore = RxDouble(0);
  final completionRate = RxDouble(0);
  final averageWatchTime = RxString('0:00');
  final totalWatchTime = RxString('0h');
  final ctrValue = RxDouble(0);
  final liveViewerCount = RxInt(0);
  final subscriberConversionRate = RxDouble(0);
  final returningViewerCount = RxInt(0);
  final urbanPercentage = RxDouble(0);
  final ruralPercentage = RxDouble(0);

  /// Update video summary metrics
  void updateVideoSummaryMetrics(
    VideoAnalyticsSnapshot analytics, {
    required void Function({
      required int days,
      required Map<DateTime, int> dailyWatchTime,
      required Map<DateTime, int> dailyViews,
      required Map<DateTime, int> dailySubscribers,
    }) buildTrendData,
    required void Function(Map<String, double> countryData) populateCountryChart,
    required int days,
  }) {
    engagementScore.value = analytics.getEngagementScore();
    completionRate.value = analytics.getCompletionRate();
    averageWatchTime.value = CreatorGeoTaxonomyHelper.formatSeconds(
      analytics.averageWatchDuration.toInt(),
    );
    totalWatchTime.value = analytics.totalWatchTimeFormatted;
    if (totalWatchTime.value.isEmpty ||
        totalWatchTime.value == '0 mins' ||
        totalWatchTime.value == '0.0h' ||
        totalWatchTime.value == '0h') {
      if (analytics.totalWatchTimeSeconds > 0) {
        totalWatchTime.value = WatchTimeFormatter.format(
          analytics.totalWatchTimeSeconds,
        );
      }
    }
    ctrValue.value = analytics.ctr;
    liveViewerCount.value = analytics.liveViewerCount;
    subscriberConversionRate.value = analytics.subscriberConversionRate;
    returningViewerCount.value = analytics.returningViewers;
    urbanPercentage.value = analytics.urbanPercentage;
    ruralPercentage.value = analytics.ruralPercentage;

    buildTrendData(
      days: days,
      dailyWatchTime: analytics.dailyWatchTime,
      dailyViews: analytics.dailyViews,
      dailySubscribers: analytics.dailySubscribers,
    );

    populateCountryChart(analytics.countryTrafficPercentage);
  }

  /// Update channel summary metrics
  void updateChannelSummaryMetrics(
    ChannelAnalyticsSnapshot analytics, {
    required void Function({
      required int days,
      required Map<DateTime, int> dailyWatchTime,
      required Map<DateTime, int> dailyViews,
      required Map<DateTime, int> dailySubscribers,
    }) buildTrendData,
    required void Function(Map<String, double> countryData) populateCountryChart,
    required int days,
  }) {
    engagementScore.value = analytics.getAverageEngagementScore();
    completionRate.value = analytics.totalVideoWatches > 0
        ? (analytics.totalUniqueViewers / analytics.totalVideoWatches) * 100
        : 0;
    averageWatchTime.value = CreatorGeoTaxonomyHelper.formatSeconds(
      analytics.averageWatchDuration.toInt(),
    );
    totalWatchTime.value = analytics.totalWatchTimeFormatted;
    if (totalWatchTime.value.isEmpty ||
        totalWatchTime.value == '0 mins' ||
        totalWatchTime.value == '0.0h' ||
        totalWatchTime.value == '0h') {
      if (analytics.totalWatchTimeSeconds > 0) {
        totalWatchTime.value = WatchTimeFormatter.format(
          analytics.totalWatchTimeSeconds,
        );
      }
    }
    ctrValue.value = analytics.ctr;
    subscriberConversionRate.value = analytics.subscriberConversionRate;
    returningViewerCount.value = analytics.returningViewers;
    urbanPercentage.value = analytics.urbanPercentage;
    ruralPercentage.value = analytics.ruralPercentage;

    buildTrendData(
      days: days,
      dailyWatchTime: analytics.dailyWatchTime,
      dailyViews: analytics.dailyViews,
      dailySubscribers: analytics.dailySubscribers,
    );

    liveViewerCount.value = analytics.liveViewerCount;
    populateCountryChart(analytics.countryTrafficPercentage);
  }
}
