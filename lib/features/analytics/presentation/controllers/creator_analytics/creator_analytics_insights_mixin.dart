import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics/creator_analytics_models.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics/creator_geo_taxonomy_helper.dart';

/// Mixin managing reactive audience insights, device breakdowns, quality stats,
/// and traffic source rankings for Creator Analytics.
mixin CreatorAnalyticsInsightsMixin on BaseController {
  // Insights (reactive)
  final topStates = RxList<StateTrafficStat>();
  final topCountries = RxList<CountryTrafficStat>();
  final topCities = RxList<CityTrafficStat>();
  final deviceBreakdownStats = RxList<DeviceStatStat>();
  final qualityStats = RxList<QualityStatStat>();
  final trafficSourceStats = RxList<TrafficSourceStat>();

  /// Update video insights
  void updateVideoInsights(VideoAnalyticsSnapshot analytics) {
    // Top states
    final stateData = <StateTrafficStat>[];
    final sortedStates = analytics.stateTrafficPercentage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedStates.take(5)) {
      stateData.add(
        StateTrafficStat(
          stateName: e.key,
          viewCount: analytics.stateTraffic[e.key] ?? 0,
          percentage: e.value,
        ),
      );
    }
    topStates.value = stateData;

    // Top countries
    final countryData = <CountryTrafficStat>[];
    final sortedCountries = analytics.countryTrafficPercentage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedCountries.take(5)) {
      countryData.add(
        CountryTrafficStat(
          countryName: e.key,
          viewCount: analytics.countryTraffic[e.key] ?? 0,
          percentage: e.value,
        ),
      );
    }
    topCountries.value = countryData;

    // Top cities
    final cityData = <CityTrafficStat>[];
    final sortedCities = analytics.cityTraffic.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final cityTotal = analytics.cityTraffic.values.fold<int>(
      0,
      (a, b) => a + b,
    );
    for (final e in sortedCities.take(10)) {
      cityData.add(
        CityTrafficStat(
          cityName: e.key,
          viewCount: e.value,
          percentage: cityTotal > 0 ? (e.value / cityTotal) * 100 : 0,
        ),
      );
    }
    topCities.value = cityData;

    // Devices
    deviceBreakdownStats.value = analytics.deviceTypeBreakdown.entries
        .map(
          (e) => DeviceStatStat(
            deviceType: e.key,
            count: e.value,
            percentage: analytics.totalViews > 0
                ? (e.value / analytics.totalViews) * 100
                : 0,
          ),
        )
        .toList();

    // Quality
    qualityStats.value = analytics.qualityBreakdown.entries
        .map(
          (e) => QualityStatStat(
            quality: e.key,
            count: e.value,
            percentage: analytics.totalViews > 0
                ? (e.value / analytics.totalViews) * 100
                : 0,
          ),
        )
        .toList();

    // Traffic sources
    trafficSourceStats.value =
        analytics.trafficSourceBreakdown.entries
            .map(
              (e) => TrafficSourceStat(
                source: CreatorGeoTaxonomyHelper.formatSourceLabel(e.key),
                sourceKey: e.key,
                count: e.value,
                percentage: analytics.totalViews > 0
                    ? (e.value / analytics.totalViews) * 100
                    : 0,
              ),
            )
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
  }

  /// Update channel insights
  void updateChannelInsights(ChannelAnalyticsSnapshot analytics) {
    final stateData = <StateTrafficStat>[];
    final sortedStates = analytics.stateTrafficPercentage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedStates.take(5)) {
      stateData.add(
        StateTrafficStat(
          stateName: e.key,
          viewCount: analytics.stateTraffic[e.key] ?? 0,
          percentage: e.value,
        ),
      );
    }
    topStates.value = stateData;

    // Top countries
    final countryData = <CountryTrafficStat>[];
    final sortedCountries = analytics.countryTrafficPercentage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedCountries.take(5)) {
      countryData.add(
        CountryTrafficStat(
          countryName: e.key,
          viewCount: analytics.countryTraffic[e.key] ?? 0,
          percentage: e.value,
        ),
      );
    }
    topCountries.value = countryData;

    // Cities
    final cityData = <CityTrafficStat>[];
    final sortedCities = analytics.cityTraffic.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final cityTotal = analytics.cityTraffic.values.fold<int>(
      0,
      (a, b) => a + b,
    );
    for (final e in sortedCities.take(10)) {
      cityData.add(
        CityTrafficStat(
          cityName: e.key,
          viewCount: e.value,
          percentage: cityTotal > 0 ? (e.value / cityTotal) * 100 : 0,
        ),
      );
    }
    topCities.value = cityData;

    // Traffic sources
    trafficSourceStats.value =
        analytics.trafficSourceBreakdown.entries
            .map(
              (e) => TrafficSourceStat(
                source: CreatorGeoTaxonomyHelper.formatSourceLabel(e.key),
                sourceKey: e.key,
                count: e.value,
                percentage: analytics.totalVideoWatches > 0
                    ? (e.value / analytics.totalVideoWatches) * 100
                    : 0,
              ),
            )
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
  }
}
