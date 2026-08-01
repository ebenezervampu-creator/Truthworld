import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/data/services/geolocation_service.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Controller for creator analytics dashboard.
/// Reads from pre-aggregated daily stats for cost efficiency.
class CreatorAnalyticsController extends GetxController {
  static const String _tag = 'CreatorAnalyticsController';

  final VideoAnalyticsService _videoAnalyticsService = Get.find();
  final GeolocationService _geolocationService = Get.find();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Reactive State
  // ---------------------------------------------------------------------------

  final selectedVideoId = RxString('');
  final selectedChannelId = RxString('');
  final selectedGeoTab = RxString('states');

  // Date range filter
  final selectedDateRange = Rx<AnalyticsDateRange>(
    AnalyticsDateRange.last28Days,
  );
  final customStartDate = Rx<DateTime?>(null);
  final customEndDate = Rx<DateTime?>(null);

  // Analytics snapshots
  final videoAnalytics = Rx<VideoAnalyticsSnapshot?>(null);
  final channelAnalytics = Rx<ChannelAnalyticsSnapshot?>(null);

  // Loading states
  final isLoadingVideoAnalytics = RxBool(false);
  final isLoadingChannelAnalytics = RxBool(false);
  final videoLoadingError = RxString('');
  final channelLoadingError = RxString('');

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
  final channelVideos = RxList<Video>();

  // Insights
  final topStates = RxList<StateTrafficStat>();
  final topCountries = RxList<CountryTrafficStat>();
  final topCities = RxList<CityTrafficStat>();
  final deviceBreakdownStats = RxList<DeviceStatStat>();
  final qualityStats = RxList<QualityStatStat>();
  final trafficSourceStats = RxList<TrafficSourceStat>();

  // Summary metrics
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

  // Live viewer polling timer
  Timer? _liveViewerTimer;

  @override
  void onInit() {
    super.onInit();
    logger.info('Creator Analytics Controller initialized', tag: _tag);

    // Listen to video selection
    ever(selectedVideoId, (videoId) {
      if (videoId.isNotEmpty) loadVideoAnalytics(videoId);
    });

    // Listen to channel selection
    ever(selectedChannelId, (channelId) {
      if (channelId.isNotEmpty) {
        loadChannelAnalytics(channelId);
        fetchChannelVideos(channelId);
        if (selectedVideoId.isEmpty) {
          _startChannelLiveViewerPolling(channelId);
        }
      }
    });

    // Listen to date range changes → reload
    ever(selectedDateRange, (_) {
      if (selectedVideoId.value.isNotEmpty) {
        loadVideoAnalytics(selectedVideoId.value);
      }
      if (selectedChannelId.value.isNotEmpty) {
        loadChannelAnalytics(selectedChannelId.value);
      }
    });
  }

  @override
  void onClose() {
    _liveViewerTimer?.cancel();
    super.onClose();
  }

  // ---------------------------------------------------------------------------
  // Date Range
  // ---------------------------------------------------------------------------

  void setDateRange(AnalyticsDateRange range) {
    selectedDateRange.value = range;
  }

  void setCustomDateRange(DateTime start, DateTime end) {
    customStartDate.value = start;
    customEndDate.value = end;
    selectedDateRange.value = AnalyticsDateRange.custom;
  }

  // ---------------------------------------------------------------------------
  // VIDEO ANALYTICS
  // ---------------------------------------------------------------------------

  Future<void> loadVideoAnalytics(String videoId, {String? videoTitle}) async {
    try {
      isLoadingVideoAnalytics.value = true;
      videoLoadingError.value = '';

      final analytics = await _videoAnalyticsService.getVideoAnalytics(
        videoId,
        videoTitle: videoTitle,
        dateRange: selectedDateRange.value,
        customStart: customStartDate.value,
        customEnd: customEndDate.value,
      );

      if (analytics.totalViews == 0) {
        videoLoadingError.value = 'No watch data available for this video yet';
      }

      videoAnalytics.value = analytics;
      _updateVideoChartData(analytics);
      _updateVideoInsights(analytics);
      _updateVideoSummaryMetrics(analytics);

      // Start live viewer polling
      _startLiveViewerPolling(videoId);
    } catch (e, stackTrace) {
      logger.error(
        'Error loading video analytics: $e',
        stackTrace: stackTrace,
        tag: _tag,
      );
      videoLoadingError.value = 'Error loading analytics: $e';
    } finally {
      isLoadingVideoAnalytics.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // CHANNEL ANALYTICS
  // ---------------------------------------------------------------------------

  Future<void> loadChannelAnalytics(
    String channelId, {
    String? channelName,
  }) async {
    try {
      isLoadingChannelAnalytics.value = true;
      channelLoadingError.value = '';

      final analytics = await _videoAnalyticsService.getChannelAnalytics(
        channelId,
        channelName: channelName,
        dateRange: selectedDateRange.value,
        customStart: customStartDate.value,
        customEnd: customEndDate.value,
      );

      if (analytics.totalVideoWatches == 0) {
        channelLoadingError.value =
            'No watch data available for this channel yet';
      }

      channelAnalytics.value = analytics;
      _updateChannelChartData(analytics);
      _updateChannelInsights(analytics);
      _updateChannelSummaryMetrics(analytics);
    } catch (e, stackTrace) {
      logger.error(
        'Error loading channel analytics: $e',
        stackTrace: stackTrace,
        tag: _tag,
      );
      channelLoadingError.value = 'Error loading analytics: $e';
    } finally {
      isLoadingChannelAnalytics.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // LIVE VIEWER POLLING
  // ---------------------------------------------------------------------------

  void _startLiveViewerPolling(String videoId) {
    _liveViewerTimer?.cancel();
    _liveViewerTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        final count = await _videoAnalyticsService.getLiveViewerCount(videoId);
        liveViewerCount.value = count;
      },
    );
  }

  void _startChannelLiveViewerPolling(String channelId) {
    _liveViewerTimer?.cancel();
    _liveViewerTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) async {
        if (selectedVideoId.isEmpty) {
          final count = await _videoAnalyticsService.getChannelLiveViewerCount(
            channelId,
          );
          liveViewerCount.value = count;
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CHART DATA BUILDERS
  // ---------------------------------------------------------------------------

  void _updateVideoChartData(VideoAnalyticsSnapshot analytics) {
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
    _buildStateTrafficChart(
      analytics.stateTrafficPercentage,
      analytics.stateTraffic,
    );

    // City traffic chart (bar chart)
    _buildCityTrafficChart(analytics.cityTraffic);

    // Traffic source chart
    _buildTrafficSourceChart(
      analytics.trafficSourceBreakdown,
      analytics.totalViews,
    );

    // Area type chart (urban vs rural)
    _buildAreaTypeChart(analytics.urbanViewers, analytics.ruralViewers);
  }

  void _updateChannelChartData(ChannelAnalyticsSnapshot analytics) {
    _buildStateTrafficChart(
      analytics.stateTrafficPercentage,
      analytics.stateTraffic,
    );
    _buildCityTrafficChart(analytics.cityTraffic);
    _buildTrafficSourceChart(
      analytics.trafficSourceBreakdown,
      analytics.totalVideoWatches,
    );
    _buildAreaTypeChart(analytics.urbanViewers, analytics.ruralViewers);
  }

  void _buildStateTrafficChart(
    Map<String, double> pct,
    Map<String, int> counts,
  ) {
    final data = <PieChartDataModel>[];
    final stateColors = _generateColors(pct.length);
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

  void _buildCityTrafficChart(Map<String, int> cityTraffic) {
    final sorted = cityTraffic.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(10);
    final total = cityTraffic.values.fold<int>(0, (a, b) => a + b);
    final colors = _generateColors(10);
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

  void _buildTrafficSourceChart(Map<String, int> sources, int totalViews) {
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
        title: _formatSourceLabel(e.key),
        value: e.value.toDouble(),
        percentage: pct,
        color: sourceColors[e.key] ?? 0xFF94A3B8,
      );
    }).toList();
  }

  void _buildAreaTypeChart(int urban, int rural) {
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

  // ---------------------------------------------------------------------------
  // INSIGHTS BUILDERS
  // ---------------------------------------------------------------------------

  void _updateVideoInsights(VideoAnalyticsSnapshot analytics) {
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
                source: _formatSourceLabel(e.key),
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

  void _updateChannelInsights(ChannelAnalyticsSnapshot analytics) {
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
                source: _formatSourceLabel(e.key),
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

  // ---------------------------------------------------------------------------
  // SUMMARY METRICS
  // ---------------------------------------------------------------------------

  void _updateVideoSummaryMetrics(VideoAnalyticsSnapshot analytics) {
    engagementScore.value = analytics.getEngagementScore();
    completionRate.value = analytics.getCompletionRate();
    averageWatchTime.value = _formatSeconds(
      analytics.averageWatchDuration.toInt(),
    );
    totalWatchTime.value = analytics.totalWatchTimeFormatted;
    ctrValue.value = analytics.ctr;
    liveViewerCount.value = analytics.liveViewerCount;
    subscriberConversionRate.value = analytics.subscriberConversionRate;
    returningViewerCount.value = analytics.returningViewers;
    urbanPercentage.value = analytics.urbanPercentage;
    ruralPercentage.value = analytics.ruralPercentage;

    // Update watch time trend
    watchTimeTrendData.value =
        analytics.dailyWatchTime.entries
            .map(
              (e) => WatchTimeTrendModel(
                date: e.key,
                watchTimeHours: e.value / 3600,
              ),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    // Update views trend
    viewsTrendData.value =
        analytics.dailyViews.entries
            .map(
              (e) => ViewsTrendModel(
                date: e.key,
                views: e.value,
              ),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    // Update subscribers trend
    subscribersTrendData.value =
        analytics.dailySubscribers.entries
            .map(
              (e) => SubscribersTrendModel(
                date: e.key,
                subscribers: e.value,
              ),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    // Populate country chart
    _populateCountryChart(analytics.countryTrafficPercentage);
  }

  void _populateCountryChart(Map<String, double> countryData) {
    if (countryData.isEmpty) {
      countryTrafficChartData.clear();
      return;
    }

    final data = <PieChartDataModel>[];
    double othersPct = 0;

    countryData.forEach((country, pct) {
      if (country == 'IN' || country == 'India') {
        data.add(
          PieChartDataModel(
            title: 'India',
            value: pct,
            percentage: pct,
            color: 0xFF22C55E, // Green
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
          color: 0xFF3B82F6, // Blue
        ),
      );
    }

    countryTrafficChartData.value = data;
  }

  Future<void> fetchChannelVideos(String channelId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: channelId)
          .orderBy('viewCount', descending: true)
          .limit(50)
          .get();
      channelVideos.value = snapshot.docs
          .map(Video.fromDocumentSnapshot)
          .toList();
    } catch (e) {
      logger.error('Error fetching channel videos: $e', tag: _tag);
    }
  }

  void _updateChannelSummaryMetrics(ChannelAnalyticsSnapshot analytics) {
    engagementScore.value = analytics.getAverageEngagementScore();
    completionRate.value = analytics.totalVideoWatches > 0
        ? (analytics.totalUniqueViewers / analytics.totalVideoWatches) * 100
        : 0;
    averageWatchTime.value = _formatSeconds(
      analytics.averageWatchDuration.toInt(),
    );
    totalWatchTime.value = analytics.totalWatchTimeFormatted;
    ctrValue.value = analytics.ctr;
    subscriberConversionRate.value = analytics.subscriberConversionRate;
    returningViewerCount.value = analytics.returningViewers;
    urbanPercentage.value = analytics.urbanPercentage;
    ruralPercentage.value = analytics.ruralPercentage;

    // Update watch time trend
    watchTimeTrendData.value =
        analytics.dailyWatchTime.entries
            .map(
              (e) => WatchTimeTrendModel(
                date: e.key,
                watchTimeHours: e.value / 3600,
              ),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    // Update views trend
    viewsTrendData.value =
        analytics.dailyViews.entries
            .map(
              (e) => ViewsTrendModel(
                date: e.key,
                views: e.value,
              ),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    // Update subscribers trend
    subscribersTrendData.value =
        analytics.dailySubscribers.entries
            .map(
              (e) => SubscribersTrendModel(
                date: e.key,
                subscribers: e.value,
              ),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    liveViewerCount.value = analytics.liveViewerCount;
    // Populate country chart
    _populateCountryChart(analytics.countryTrafficPercentage);
  }

  // ---------------------------------------------------------------------------
  // REFRESH
  // ---------------------------------------------------------------------------

  Future<void> refreshAnalytics() async {
    _videoAnalyticsService.clearAnalyticsCache();
    if (selectedVideoId.value.isNotEmpty) {
      await loadVideoAnalytics(selectedVideoId.value);
    }
    if (selectedChannelId.value.isNotEmpty) {
      await loadChannelAnalytics(selectedChannelId.value);
    }
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _formatSeconds(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${secs}s';
    return '${secs}s';
  }

  String _formatSourceLabel(String key) {
    // Use the hierarchical taxonomy enum for clean labels
    final category = TrafficSourceCategory.fromKey(key);
    if (category != TrafficSourceCategory.unknown) return category.label;

    // Fallback for any missed keys
    return key.replaceAll('_', ' ').capitalize ?? key;
  }

  /// Get traffic source type (internal vs external) for grouping
  TrafficSourceType getSourceType(String key) {
    return TrafficSourceCategory.fromKey(key).type;
  }

  List<int> _generateColors(int count) {
    const base = [
      0xFF3B82F6,
      0xFF22C55E,
      0xFFF97316,
      0xFFEF4444,
      0xFF8B5CF6,
      0xFF06B6D4,
      0xFFEC4899,
      0xFFEAB308,
      0xFF64748B,
      0xFF14B8A6,
    ];
    if (count <= base.length) {
      return base.sublist(0, count.clamp(0, base.length));
    }
    final extra = <int>[];
    for (var i = base.length; i < count; i++) {
      final hue = i * 360 ~/ count;
      extra.add(
        HSVColor.fromAHSV(1, hue.toDouble(), 0.7, 0.8).toColor().toARGB32(),
      );
    }
    return [...base, ...extra];
  }

  String getStateName(String stateCode) {
    return _geolocationService.getAllIndianStates().firstWhere(
      (s) => s.startsWith(stateCode),
      orElse: () => stateCode,
    );
  }

  List<double>? getCoordinates(String name) {
    final cleanName = name.trim();
    if (_geoCoordinates.containsKey(cleanName)) {
      return _geoCoordinates[cleanName];
    }
    final lowerName = cleanName.toLowerCase();
    for (final entry in _geoCoordinates.entries) {
      if (entry.key.toLowerCase() == lowerName) {
        return entry.value;
      }
    }
    return null;
  }

  static const Map<String, List<double>> _geoCoordinates = {
    // Indian States/UTs
    'Andaman and Nicobar': [11.74, 92.65],
    'Andhra Pradesh': [15.97, 79.74],
    'Arunachal Pradesh': [28.21, 94.72],
    'Assam': [26.20, 92.93],
    'Bihar': [25.09, 85.31],
    'Chandigarh': [30.73, 76.77],
    'Chhattisgarh': [21.27, 81.86],
    'Dadra and Nagar Haveli': [20.18, 73.01],
    'Daman and Diu': [20.42, 72.83],
    'Delhi': [28.61, 77.20],
    'Goa': [15.29, 74.12],
    'Gujarat': [22.25, 71.19],
    'Haryana': [29.05, 76.08],
    'Himachal Pradesh': [31.10, 77.17],
    'Jammu and Kashmir': [33.77, 76.57],
    'Jharkhand': [23.61, 85.27],
    'Karnataka': [15.31, 75.71],
    'Kerala': [10.85, 76.27],
    'Ladakh': [34.15, 77.57],
    'Lakshadweep': [10.57, 72.64],
    'Madhya Pradesh': [22.97, 78.65],
    'Maharashtra': [19.75, 75.71],
    'Manipur': [24.66, 93.90],
    'Meghalaya': [25.46, 91.36],
    'Mizoram': [23.16, 92.93],
    'Nagaland': [26.15, 94.56],
    'Odisha': [20.95, 85.09],
    'Puducherry': [11.94, 79.80],
    'Punjab': [31.14, 75.34],
    'Rajasthan': [27.02, 74.21],
    'Sikkim': [27.53, 88.51],
    'Tamil Nadu': [11.12, 78.65],
    'Telangana': [18.11, 79.01],
    'Tripura': [23.94, 91.98],
    'Uttar Pradesh': [26.84, 80.88],
    'Uttarakhand': [30.06, 79.01],
    'West Bengal': [22.98, 87.85],

    // Countries
    'India': [20.59, 78.96],
    'IN': [20.59, 78.96],
    'United States': [37.09, -95.71],
    'US': [37.09, -95.71],
    'United Kingdom': [55.37, -3.43],
    'UK': [55.37, -3.43],
    'Canada': [56.13, -106.34],
    'CA': [56.13, -106.34],
    'Australia': [-25.27, 133.77],
    'AU': [-25.27, 133.77],
    'Germany': [51.16, 10.45],
    'DE': [51.16, 10.45],
    'France': [46.22, 2.21],
    'FR': [46.22, 2.21],
    'Japan': [36.20, 138.25],
    'JP': [36.20, 138.25],
    'China': [35.86, 104.19],
    'CN': [35.86, 104.19],
    'Brazil': [-14.23, -51.92],
    'BR': [-14.23, -51.92],
    'Russia': [61.52, 105.31],
    'RU': [61.52, 105.31],
    'Singapore': [1.35, 103.81],
    'SG': [1.35, 103.81],
    'United Arab Emirates': [23.42, 53.84],
    'AE': [23.42, 53.84],
  };
}

// =============================================================================
// DATA MODELS FOR CHARTS & INSIGHTS
// =============================================================================

class PieChartDataModel {
  PieChartDataModel({
    required this.title,
    required this.value,
    required this.percentage,
    required this.color,
  });
  final String title;
  final double value;
  final double percentage;
  final int color;
}

class BarChartDataModel {
  BarChartDataModel({
    required this.label,
    required this.value,
    required this.percentage,
    required this.color,
  });
  final String label;
  final double value;
  final double percentage;
  final int color;
}

class StateTrafficStat {
  StateTrafficStat({
    required this.stateName,
    required this.viewCount,
    required this.percentage,
  });
  final String stateName;
  final int viewCount;
  final double percentage;
}

class CountryTrafficStat {
  CountryTrafficStat({
    required this.countryName,
    required this.viewCount,
    required this.percentage,
  });
  final String countryName;
  final int viewCount;
  final double percentage;
}

class CityTrafficStat {
  CityTrafficStat({
    required this.cityName,
    required this.viewCount,
    required this.percentage,
  });
  final String cityName;
  final int viewCount;
  final double percentage;
}

class DeviceStatStat {
  DeviceStatStat({
    required this.deviceType,
    required this.count,
    required this.percentage,
  });
  final String deviceType;
  final int count;
  final double percentage;
}

class QualityStatStat {
  QualityStatStat({
    required this.quality,
    required this.count,
    required this.percentage,
  });
  final String quality;
  final int count;
  final double percentage;
}

class TrafficSourceStat {
  TrafficSourceStat({
    required this.source,
    required this.sourceKey,
    required this.count,
    required this.percentage,
  });
  final String source;
  final String sourceKey;
  final int count;
  final double percentage;
}

class WatchTimeTrendModel {
  WatchTimeTrendModel({
    required this.date,
    required this.watchTimeHours,
  });
  final DateTime date;
  final double watchTimeHours;
}

class ViewsTrendModel {
  ViewsTrendModel({
    required this.date,
    required this.views,
  });
  final DateTime date;
  final int views;
}

class SubscribersTrendModel {
  SubscribersTrendModel({
    required this.date,
    required this.subscribers,
  });
  final DateTime date;
  final int subscribers;
}
