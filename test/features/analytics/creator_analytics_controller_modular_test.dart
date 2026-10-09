import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/data/services/geolocation_service.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  group('CreatorAnalyticsController Modular Unit Test Suite', () {
    late CreatorAnalyticsController controller;

    setUpAll(() async {
      await setupMockFirebase();
    });

    setUp(() {
      Get.reset();
      Get.testMode = true;
      Get.put<VideoAnalyticsService>(VideoAnalyticsService());
      Get.put<GeolocationService>(GeolocationService());
      controller = Get.put(CreatorAnalyticsController());
    });

    tearDown(Get.reset);

    test('Initializes with expected default reactive observables and singleton', () {
      expect(CreatorAnalyticsController.to, equals(controller));
      expect(controller.selectedVideoId.value, isEmpty);
      expect(controller.selectedChannelId.value, isEmpty);
      expect(controller.selectedGeoTab.value, equals('states'));
      expect(controller.selectedDateRange.value, equals(AnalyticsDateRange.last28Days));
      expect(controller.customStartDate.value, isNull);
      expect(controller.customEndDate.value, isNull);
      expect(controller.videoAnalytics.value, isNull);
      expect(controller.channelAnalytics.value, isNull);
      expect(controller.isLoadingVideoAnalytics.value, isFalse);
      expect(controller.isLoadingChannelAnalytics.value, isFalse);
      expect(controller.videoLoadingError.value, isEmpty);
      expect(controller.channelLoadingError.value, isEmpty);
      expect(controller.channelVideos, isEmpty);
    });

    test('setDateRange and setCustomDateRange mutate state correctly', () {
      controller.setDateRange(AnalyticsDateRange.last7Days);
      expect(controller.selectedDateRange.value, equals(AnalyticsDateRange.last7Days));

      final start = DateTime(2026, 3, 5);
      final end = DateTime(2026, 3, 20);
      controller.setCustomDateRange(start, end);
      expect(controller.selectedDateRange.value, equals(AnalyticsDateRange.custom));
      expect(controller.customStartDate.value, equals(start));
      expect(controller.customEndDate.value, equals(end));
    });

    test('Taxonomy and Geo helpers resolve correctly', () {
      expect(controller.getStateName('Delhi'), contains('Delhi'));
      expect(controller.getStateName('NonExistent'), equals('NonExistent'));

      final coords = controller.getCoordinates('India');
      expect(coords, isNotNull);
      expect(coords!.length, equals(2));

      expect(controller.getCoordinates('UnknownPlace'), isNull);

      expect(controller.getSourceType('suggested'), equals(TrafficSourceType.internal));
      expect(controller.getSourceType('whatsapp'), equals(TrafficSourceType.external));
    });

    test('CreatorGeoTaxonomyHelper formatting and color generator utilities', () {
      expect(CreatorGeoTaxonomyHelper.formatSeconds(45), equals('45s'));
      expect(CreatorGeoTaxonomyHelper.formatSeconds(125), equals('2m 5s'));
      expect(CreatorGeoTaxonomyHelper.formatSeconds(3665), equals('1h 1m'));

      expect(CreatorGeoTaxonomyHelper.formatSourceLabel('shorts_feed'), equals('Shorts Feed'));
      expect(CreatorGeoTaxonomyHelper.formatSourceLabel('search'), equals('Search'));

      final colors5 = CreatorGeoTaxonomyHelper.generateColors(5);
      expect(colors5.length, equals(5));

      final colors15 = CreatorGeoTaxonomyHelper.generateColors(15);
      expect(colors15.length, equals(15));
    });

    test('updateVideoChartData transforms snapshots into chart models', () {
      final snapshot = VideoAnalyticsSnapshot(
        videoId: 'vid_123',
        title: 'Test Video',
        totalViews: 100,
        totalUniqueViewers: 80,
        averageWatchDuration: 45.0,
        averageWatchPercentage: 55.0,
        usersCompletedVideo: 15,
        totalWatchTimeSeconds: 3600,
        returningViewers: 20,
        generatedAt: DateTime.now(),
        estimatedReadCount: 1,
        watchtimeCategoryCount: {
          WatchtimeCategory.lessThan20: 10,
          WatchtimeCategory.lessThan25: 20,
          WatchtimeCategory.lessThan50: 30,
          WatchtimeCategory.lessThan75: 25,
          WatchtimeCategory.complete: 15,
        },
        stateTraffic: {'Maharashtra': 60, 'Delhi': 40},
        stateTrafficPercentage: {'Maharashtra': 60.0, 'Delhi': 40.0},
        cityTraffic: {'Mumbai': 50, 'New Delhi': 40},
        trafficSourceBreakdown: {'search': 70, 'suggested': 30},
        urbanViewers: 80,
        ruralViewers: 20,
        countryTraffic: {'India': 100},
        countryTrafficPercentage: {'India': 100.0},
        deviceTypeBreakdown: {'mobile': 90, 'desktop': 10},
        qualityBreakdown: {'1080p': 80, '720p': 20},
      );

      controller.updateVideoChartData(snapshot);

      expect(controller.watchtimeChartData.length, equals(5));
      expect(controller.stateTrafficChartData.length, equals(2));
      expect(controller.cityTrafficChartData.length, equals(2));
      expect(controller.trafficSourceChartData.length, equals(2));
      expect(controller.areaTypeChartData.length, equals(2));
    });

    test('updateVideoInsights populates ranked breakdowns', () {
      final snapshot = VideoAnalyticsSnapshot(
        videoId: 'vid_123',
        title: 'Test Video',
        totalViews: 100,
        totalUniqueViewers: 80,
        averageWatchDuration: 45.0,
        averageWatchPercentage: 55.0,
        usersCompletedVideo: 15,
        totalWatchTimeSeconds: 3600,
        returningViewers: 20,
        generatedAt: DateTime.now(),
        estimatedReadCount: 1,
        watchtimeCategoryCount: const {},
        stateTraffic: {'Maharashtra': 60, 'Karnataka': 40},
        stateTrafficPercentage: {'Maharashtra': 60.0, 'Karnataka': 40.0},
        countryTraffic: {'India': 90, 'US': 10},
        countryTrafficPercentage: {'India': 90.0, 'US': 10.0},
        cityTraffic: {'Mumbai': 50, 'Bengaluru': 30},
        deviceTypeBreakdown: {'mobile': 80, 'tablet': 20},
        qualityBreakdown: {'1080p': 70, '4k': 30},
        trafficSourceBreakdown: {'search': 60, 'direct': 40},
      );

      controller.updateVideoInsights(snapshot);

      expect(controller.topStates.length, equals(2));
      expect(controller.topCountries.length, equals(2));
      expect(controller.topCities.length, equals(2));
      expect(controller.deviceBreakdownStats.length, equals(2));
      expect(controller.qualityStats.length, equals(2));
      expect(controller.trafficSourceStats.length, equals(2));
    });

    test('updateVideoSummaryMetrics calculates metrics and populates trends', () {
      final now = DateTime.now();
      final day1 = DateTime(now.year, now.month, now.day);
      final snapshot = VideoAnalyticsSnapshot(
        videoId: 'vid_123',
        title: 'Test Video',
        totalViews: 100,
        totalUniqueViewers: 80,
        averageWatchDuration: 72.0,
        averageWatchPercentage: 60.0,
        usersCompletedVideo: 20,
        totalWatchTimeSeconds: 7200,
        returningViewers: 25,
        generatedAt: DateTime.now(),
        estimatedReadCount: 1,
        watchtimeCategoryCount: const {},
        stateTraffic: const {},
        stateTrafficPercentage: const {},
        deviceTypeBreakdown: const {},
        qualityBreakdown: const {},
        totalImpressions: 1000,
        subscribersGained: 5,
        liveViewerCount: 15,
        urbanViewers: 75,
        ruralViewers: 25,
        dailyWatchTime: {day1: 3600},
        dailyViews: {day1: 50},
        dailySubscribers: {day1: 5},
        countryTrafficPercentage: {'India': 90.0, 'US': 10.0},
      );

      controller.updateVideoSummaryMetrics(
        snapshot,
        buildTrendData: controller.buildContinuousTrendData,
        populateCountryChart: controller.populateCountryChart,
        days: 7,
      );

      expect(controller.ctrValue.value, equals(10.0));
      expect(controller.liveViewerCount.value, equals(15));
      expect(controller.subscriberConversionRate.value, equals(5.0));
      expect(controller.returningViewerCount.value, equals(25));
      expect(controller.urbanPercentage.value, equals(75.0));
      expect(controller.ruralPercentage.value, equals(25.0));
      expect(controller.watchTimeTrendData.length, equals(7));
      expect(controller.viewsTrendData.length, equals(7));
      expect(controller.subscribersTrendData.length, equals(7));
      expect(controller.countryTrafficChartData.length, equals(2));
    });

    test('Channel analytics updating methods handle channel snapshots', () {
      final now = DateTime.now();
      final day1 = DateTime(now.year, now.month, now.day);
      final channelSnapshot = ChannelAnalyticsSnapshot(
        channelId: 'chan_123',
        channelName: 'Test Channel',
        totalVideoWatches: 500,
        totalWatchTimeSeconds: 18000,
        totalUniqueViewers: 350,
        averageWatchDuration: 60.0,
        averageWatchPercentage: 50.0,
        generatedAt: DateTime.now(),
        videoCount: 10,
        totalEngagementScore: 85.0,
        returningViewers: 120,
        stateTraffic: {'Maharashtra': 300, 'Delhi': 200},
        stateTrafficPercentage: {'Maharashtra': 60.0, 'Delhi': 40.0},
        cityTraffic: {'Mumbai': 250, 'Delhi': 150},
        trafficSourceBreakdown: {'search': 300, 'suggested': 200},
        urbanViewers: 400,
        ruralViewers: 100,
        countryTraffic: {'India': 480},
        countryTrafficPercentage: {'India': 96.0},
        dailyWatchTime: {day1: 7200},
        dailyViews: {day1: 150},
        dailySubscribers: {day1: 20},
      );

      controller.updateChannelChartData(channelSnapshot);
      expect(controller.stateTrafficChartData.length, equals(2));
      expect(controller.cityTrafficChartData.length, equals(2));
      expect(controller.trafficSourceChartData.length, equals(2));

      controller.updateChannelInsights(channelSnapshot);
      expect(controller.topStates.length, equals(2));
      expect(controller.topCities.length, equals(2));

      controller.updateChannelSummaryMetrics(
        channelSnapshot,
        buildTrendData: controller.buildContinuousTrendData,
        populateCountryChart: controller.populateCountryChart,
        days: 7,
      );
      expect(controller.returningViewerCount.value, equals(120));
      expect(controller.watchTimeTrendData.length, equals(7));
    });

    test('loadVideoAnalytics reconciles watch time with channelVideos (e.g. 5 mins / 328s)', () async {
      final testVideo = Video(
        id: 'vid_test_5min',
        title: 'Mahonathuda song by Raj prakash paul worship conference',
        description: 'Test song',
        thumbnailUrl: '',
        ownerId: 'owner_1',
        channelId: 'chan_1',
        channelName: 'Channel 1',
        category: 'Music',
        tags: const [],
        viewCount: 1,
        duration: '05:28',
        vDurationValue: const Duration(seconds: 328),
        totalWatchTimeSeconds: 328,
      );

      controller.channelVideos.add(testVideo);

      // Load analytics for this video
      await controller.loadVideoAnalytics('vid_test_5min', videoTitle: testVideo.title);

      // Epistemic reconciliation: video watch time must be 328s (5 mins), NEVER 0 mins
      expect(controller.videoAnalytics.value?.totalWatchTimeSeconds, equals(328));
      expect(controller.totalWatchTime.value, equals('5 mins'));
      expect(controller.videoLoadingError.value, isEmpty);
    });
  });
}
