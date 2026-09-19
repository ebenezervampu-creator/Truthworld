import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics/creator_analytics_models.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics/creator_geo_taxonomy_helper.dart';

/// Mixin managing reactive chart datasets and visual transformation pipelines
/// for Creator Analytics.
mixin CreatorAnalyticsChartMixin on BaseController {
  // Chart data (reactive)
  final watchtimeChartData = RxList<PieChartDataModel>();
  final stateTrafficChartData = RxList<PieChartDataModel>();
  final cityTrafficChartData = RxList<BarChartDataModel>();
  final trafficSourceChartData = RxList<PieChartDataModel>();
  final areaTypeChartData = RxList<PieChartDataModel>();
  final watchTimeTrendData = RxList<WatchTimeTrendModel>();
  final viewsTrendData = RxList<ViewsTrendModel>();
  final subscribersTrendData = RxList<SubscribersTrendModel>();
  final countryTrafficChartData = RxList<PieChartDataModel>();

  /// Update video chart models
  void updateVideoChartData(VideoAnalyticsSnapshot analytics) {
    // Watchtime category chart
    final chartData = <PieChartDataModel>[];
    const colors = [
      0xFFEF4444, // Red: < 20 seconds (bounced)
      0xFFF97316, // Orange: < 25%
      0xFF8B5CF6, // Purple: < 50%
      0xFF3B82F6, // Blue: < 75%
      0xFF22C55E, // Green: 100%
    ];

    var colorIdx = 0;
    for (final category in WatchtimeCategory.values) {
      final count = analytics.watchtimeCategoryCount[category] ?? 0;
      if (count > 0) {
        chartData.add(
          PieChartDataModel(
            title: category.label,
            value: count.toDouble(),
            percentage: analytics.totalViews > 0
                ? (count / analytics.totalViews) * 100
                : 0,
            color: colors[colorIdx % colors.length],
          ),
        );
      }
      colorIdx++;
    }
    watchtimeChartData.value = chartData;

    // State traffic chart
    buildStateTrafficChart(
      analytics.stateTrafficPercentage,
      analytics.stateTraffic,
    );

    // City traffic chart (bar chart)
    buildCityTrafficChart(analytics.cityTraffic);

    // Traffic source chart
    buildTrafficSourceChart(
      analytics.trafficSourceBreakdown,
      analytics.totalViews,
    );

    // Area type chart (urban vs rural)
    buildAreaTypeChart(analytics.urbanViewers, analytics.ruralViewers);
  }

  /// Update channel chart models
  void updateChannelChartData(ChannelAnalyticsSnapshot analytics) {
    buildStateTrafficChart(
      analytics.stateTrafficPercentage,
      analytics.stateTraffic,
    );
    buildCityTrafficChart(analytics.cityTraffic);
    buildTrafficSourceChart(
      analytics.trafficSourceBreakdown,
      analytics.totalVideoWatches,
    );
    buildAreaTypeChart(analytics.urbanViewers, analytics.ruralViewers);
  }

  /// Build regional state traffic pie chart
  void buildStateTrafficChart(
    Map<String, double> pct,
    Map<String, int> counts,
  ) {
    final data = <PieChartDataModel>[];
    final stateColors = CreatorGeoTaxonomyHelper.generateColors(pct.length);
    var i = 0;
    for (final entry in pct.entries) {
      data.add(
        PieChartDataModel(
          title: entry.key,
          value: counts[entry.key]?.toDouble() ?? 0,
          percentage: entry.value,
          color: stateColors[i % stateColors.length],
        ),
      );
      i++;
    }
    stateTrafficChartData.value = data;
  }

  /// Build city traffic bar chart
  void buildCityTrafficChart(Map<String, int> cityTraffic) {
    final sorted = cityTraffic.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(10);
    final total = cityTraffic.values.fold<int>(0, (a, b) => a + b);
    final colors = CreatorGeoTaxonomyHelper.generateColors(10);
    var i = 0;
    cityTrafficChartData.value = top.map((e) {
      final pct = total > 0 ? (e.value / total) * 100 : 0.0;
      return BarChartDataModel(
        label: e.key,
        value: e.value.toDouble(),
        percentage: pct,
        color: colors[i++ % colors.length],
      );
    }).toList();
  }

  /// Build traffic source distribution pie chart
  void buildTrafficSourceChart(Map<String, int> sources, int totalViews) {
    const sourceColors = {
      'search': 0xFF3B82F6,
      'suggested': 0xFF8B5CF6,
      'direct': 0xFF22C55E,
      'external': 0xFFF97316,
      'channel_page': 0xFF06B6D4,
      'shorts_feed': 0xFFEC4899,
      'trending': 0xFFEAB308,
    };

    trafficSourceChartData.value = sources.entries.map((e) {
      final pct = totalViews > 0 ? (e.value / totalViews) * 100 : 0.0;
      return PieChartDataModel(
        title: CreatorGeoTaxonomyHelper.formatSourceLabel(e.key),
        value: e.value.toDouble(),
        percentage: pct,
        color: sourceColors[e.key] ?? 0xFF94A3B8,
      );
    }).toList();
  }

  /// Build urban vs rural viewer breakdown pie chart
  void buildAreaTypeChart(int urban, int rural) {
    final total = urban + rural;
    if (total == 0) {
      areaTypeChartData.value = [];
      return;
    }
    areaTypeChartData.value = [
      PieChartDataModel(
        title: 'Urban',
        value: urban.toDouble(),
        percentage: (urban / total) * 100,
        color: 0xFF3B82F6,
      ),
      PieChartDataModel(
        title: 'Rural',
        value: rural.toDouble(),
        percentage: (rural / total) * 100,
        color: 0xFF22C55E,
      ),
    ];
  }

  /// Build continuous date-trend time-series data
  void buildContinuousTrendData({
    required int days,
    required Map<DateTime, int> dailyWatchTime,
    required Map<DateTime, int> dailyViews,
    required Map<DateTime, int> dailySubscribers,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final watchMap = <DateTime, double>{};
    final viewsMap = <DateTime, int>{};
    final subsMap = <DateTime, int>{};

    for (var i = days - 1; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      watchMap[d] = 0.0;
      viewsMap[d] = 0;
      subsMap[d] = 0;
    }

    for (final e in dailyWatchTime.entries) {
      final d = DateTime(e.key.year, e.key.month, e.key.day);
      watchMap[d] = (watchMap[d] ?? 0.0) + (e.value / 3600.0);
    }

    for (final e in dailyViews.entries) {
      final d = DateTime(e.key.year, e.key.month, e.key.day);
      viewsMap[d] = (viewsMap[d] ?? 0) + e.value;
    }

    for (final e in dailySubscribers.entries) {
      final d = DateTime(e.key.year, e.key.month, e.key.day);
      subsMap[d] = (subsMap[d] ?? 0) + e.value;
    }

    watchTimeTrendData.value = watchMap.entries
        .map((e) => WatchTimeTrendModel(date: e.key, watchTimeHours: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    viewsTrendData.value = viewsMap.entries
        .map((e) => ViewsTrendModel(date: e.key, views: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    subscribersTrendData.value = subsMap.entries
        .map((e) => SubscribersTrendModel(date: e.key, subscribers: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Populate country traffic pie chart
  void populateCountryChart(Map<String, double> countryData) {
    if (countryData.isEmpty) {
      countryTrafficChartData.clear();
      return;
    }

    final data = <PieChartDataModel>[];
    var othersPct = 0.0;

    countryData.forEach((country, pct) {
      if (country == 'IN' || country == 'India') {
        data.add(
          PieChartDataModel(
            title: 'India',
            value: pct,
            percentage: pct,
            color: 0xFF22C55E,
          ),
        );
      } else {
        othersPct += pct;
      }
    });

    if (othersPct > 0) {
      data.add(
        PieChartDataModel(
          title: 'Others',
          value: othersPct,
          percentage: othersPct,
          color: 0xFF3B82F6,
        ),
      );
    }

    countryTrafficChartData.value = data;
  }
}
