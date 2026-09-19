import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(Get.reset);

  tearDown(Get.reset);

  group('AnalyticsDateRange Tests', () {
    test('presets have expected labels and days', () {
      expect(AnalyticsDateRange.last7Days.days, equals(7));
      expect(AnalyticsDateRange.last28Days.days, equals(28));
      expect(AnalyticsDateRange.last90Days.days, equals(90));
      expect(AnalyticsDateRange.last365Days.days, equals(365));
      expect(AnalyticsDateRange.allTime.days, equals(0));
      expect(AnalyticsDateRange.custom.days, equals(-1));
    });

    test('calculateRange computes accurate DateTime boundaries', () {
      final now = DateTime(2026, 9, 18, 12);
      final range7 = AnalyticsDateRange.last7Days.calculateRange(referenceDate: now);
      expect(range7.start, equals(now.subtract(const Duration(days: 7))));
      expect(range7.end, equals(now));

      final rangeAll = AnalyticsDateRange.allTime.calculateRange(referenceDate: now);
      expect(rangeAll.start.year, equals(2020));

      final customStart = DateTime(2026);
      final customEnd = DateTime(2026, 2);
      final rangeCustom = AnalyticsDateRange.custom.calculateRange(
        customStart: customStart,
        customEnd: customEnd,
        referenceDate: now,
      );
      expect(rangeCustom.start, equals(customStart));
      expect(rangeCustom.end, equals(customEnd));
    });
  });

  group('FraudOverview Tests', () {
    test('properties and calculations match expected view counts', () {
      const overview = FraudOverview(
        totalViews: 1000,
        flaggedViews: 50,
        cleanViews: 950,
        fraudRate: 5.0,
      );

      expect(overview.totalViews, equals(1000));
      expect(overview.flaggedViews, equals(50));
      expect(overview.cleanViews, equals(950));
      expect(overview.fraudRate, equals(5.0));
      expect(FraudOverview.clean.totalViews, equals(0));
      expect(FraudOverview.clean.fraudRate, equals(0.0));
    });
  });

  group('AnalyticsCacheManager Tests', () {
    late AnalyticsCacheManager cacheManager;

    setUp(() {
      cacheManager = AnalyticsCacheManager();
    });

    test('put and get store and retrieve cached snapshot', () {
      final snapshot = const VideoAnalyticsAggregator().createEmptyVideoAnalytics(
        'vid_123',
        'Test Video',
      );

      cacheManager.put('vid_123_last28Days', snapshot);
      final cached = cacheManager.get('vid_123_last28Days');

      expect(cached, isNotNull);
      expect(cached!.videoId, equals('vid_123'));
    });

    test('invalidateVideo removes all keys starting with videoId', () {
      final snapshot = const VideoAnalyticsAggregator().createEmptyVideoAnalytics(
        'vid_999',
        'Test Video',
      );

      cacheManager.put('vid_999_last7Days', snapshot);
      cacheManager.put('vid_999_last28Days', snapshot);
      cacheManager.put('other_vid_last7Days', snapshot);

      cacheManager.invalidateVideo('vid_999');

      expect(cacheManager.get('vid_999_last7Days'), isNull);
      expect(cacheManager.get('vid_999_last28Days'), isNull);
      expect(cacheManager.get('other_vid_last7Days'), isNotNull);
    });

    test('clear removes all entries from cache', () {
      final snapshot = const VideoAnalyticsAggregator().createEmptyVideoAnalytics(
        'vid_abc',
        'Test Video',
      );

      cacheManager.put('vid_abc_7', snapshot);
      cacheManager.clear();
      expect(cacheManager.get('vid_abc_7'), isNull);
    });
  });

  group('VideoAnalyticsAggregator Tests', () {
    const aggregator = VideoAnalyticsAggregator();

    test('createEmptyVideoAnalytics generates valid zero-state snapshot', () {
      final empty = aggregator.createEmptyVideoAnalytics('v1', 'Sample');
      expect(empty.videoId, equals('v1'));
      expect(empty.title, equals('Sample'));
      expect(empty.totalViews, equals(0));
      expect(empty.totalWatchTimeSeconds, equals(0));
      expect(empty.averageWatchDuration, equals(0.0));
    });

    test('aggregateVideoStats sums multi-day stats accurately', () {
      final day1 = DailyVideoStats(
        videoId: 'v1',
        channelId: 'c1',
        dateKey: '2026_09_01',
        totalViews: 100,
        totalImpressions: 500,
        uniqueViewers: 80,
        totalWatchTimeSeconds: 6000,
        subscriberViews: 40,
        nonSubscriberViews: 60,
        returningViewers: 20,
        subscribersGained: 5,
        subscribersLost: 1,
        bouncedUnder20s: 10,
        watched25Percent: 20,
        watched50Percent: 30,
        watched75Percent: 20,
        watched100Percent: 20,
        stateTraffic: {'CA': 50, 'NY': 50},
        cityTraffic: {'Los Angeles': 50, 'New York': 50},
        countryTraffic: {'US': 100},
        deviceBreakdown: {'mobile': 80, 'desktop': 20},
        qualityBreakdown: {'1080p': 100},
        trafficSourceBreakdown: {'search': 60, 'suggested': 40},
        urbanViewers: 70,
        ruralViewers: 30,
        date: DateTime(2026, 9),
      );

      final day2 = DailyVideoStats(
        videoId: 'v1',
        channelId: 'c1',
        dateKey: '2026_09_02',
        totalViews: 50,
        totalImpressions: 250,
        uniqueViewers: 40,
        totalWatchTimeSeconds: 3000,
        subscriberViews: 20,
        nonSubscriberViews: 30,
        returningViewers: 10,
        subscribersGained: 2,
        bouncedUnder20s: 5,
        watched25Percent: 10,
        watched50Percent: 15,
        watched75Percent: 10,
        watched100Percent: 10,
        stateTraffic: {'CA': 30, 'TX': 20},
        cityTraffic: {'Los Angeles': 30, 'Austin': 20},
        countryTraffic: {'US': 50},
        deviceBreakdown: {'mobile': 40, 'desktop': 10},
        qualityBreakdown: {'1080p': 50},
        trafficSourceBreakdown: {'search': 30, 'suggested': 20},
        urbanViewers: 35,
        ruralViewers: 15,
        date: DateTime(2026, 9, 2),
      );

      final snapshot = aggregator.aggregateVideoStats('v1', 'Sample Video', [day1, day2]);

      expect(snapshot.totalViews, equals(150));
      expect(snapshot.totalImpressions, equals(750));
      expect(snapshot.totalUniqueViewers, equals(120));
      expect(snapshot.totalWatchTimeSeconds, equals(9000));
      expect(snapshot.usersCompletedVideo, equals(30));
      expect(snapshot.urbanViewers, equals(105));
      expect(snapshot.ruralViewers, equals(45));
      expect(snapshot.stateTraffic['CA'], equals(80));
      expect(snapshot.stateTraffic['NY'], equals(50));
      expect(snapshot.stateTraffic['TX'], equals(20));
      expect(snapshot.trafficSourceBreakdown['search'], equals(90));
      expect(snapshot.trafficSourceBreakdown['suggested'], equals(60));
    });

    test('mergeHourlyIntoSnapshot supplements day snapshot with hourly data', () {
      final base = aggregator.createEmptyVideoAnalytics('v1', 'Sample');
      final hourly = HourlyVideoStats(
        videoId: 'v1',
        channelId: 'c1',
        hourKey: '2026_09_18_12',
        totalViews: 25,
        uniqueViewers: 20,
        totalWatchTimeSeconds: 1500,
        subscriberViews: 10,
        nonSubscriberViews: 15,
        bouncedUnder20s: 2,
        watched25Percent: 5,
        watched50Percent: 5,
        watched75Percent: 5,
        watched100Percent: 8,
        trafficSourceBreakdown: {'direct': 25},
        hour: DateTime.now(),
      );

      final merged = aggregator.mergeHourlyIntoSnapshot(base, hourly);
      expect(merged.totalViews, equals(25));
      expect(merged.totalUniqueViewers, equals(20));
      expect(merged.totalWatchTimeSeconds, equals(1500));
      expect(merged.usersCompletedVideo, equals(8));
      expect(merged.trafficSourceBreakdown['direct'], equals(25));
    });
  });

  group('ChannelAnalyticsAggregator Tests', () {
    const aggregator = ChannelAnalyticsAggregator();

    test('createEmptyChannelAnalytics returns valid zero-state snapshot', () {
      final empty = aggregator.createEmptyChannelAnalytics('c1', 'My Channel');
      expect(empty.channelId, equals('c1'));
      expect(empty.channelName, equals('My Channel'));
      expect(empty.totalVideoWatches, equals(0));
      expect(empty.totalUniqueViewers, equals(0));
    });

    test('aggregateDailyChannelStats sums stats across multiple days', () {
      final day1 = DailyChannelStats(
        channelId: 'c1',
        dateKey: '2026_09_01',
        totalViews: 200,
        totalImpressions: 1000,
        uniqueViewers: 150,
        totalWatchTimeSeconds: 12000,
        subscriberViews: 100,
        nonSubscriberViews: 100,
        returningViewers: 50,
        subscribersGained: 10,
        subscribersLost: 2,
        urbanViewers: 140,
        ruralViewers: 60,
        videoCount: 5,
        stateTraffic: {'TX': 200},
        cityTraffic: {'Houston': 200},
        countryTraffic: {'US': 200},
        trafficSourceBreakdown: {'search': 200},
        date: DateTime(2026, 9),
      );

      final snapshot = aggregator.aggregateDailyChannelStats('c1', 'Tech Channel', [day1], liveViewerCount: 15);
      expect(snapshot.totalVideoWatches, equals(200));
      expect(snapshot.totalImpressions, equals(1000));
      expect(snapshot.totalUniqueViewers, equals(150));
      expect(snapshot.totalWatchTimeSeconds, equals(12000));
      expect(snapshot.subscribersGained, equals(10));
      expect(snapshot.subscribersLost, equals(2));
      expect(snapshot.liveViewerCount, equals(15));
    });
  });

  group('VideoAnalyticsService Coordinator Tests', () {
    late VideoAnalyticsService service;

    setUp(() {
      service = VideoAnalyticsService();
    });

    test('getVideoAnalytics returns empty snapshot on empty videoId', () async {
      final result = await service.getVideoAnalytics('');
      expect(result.videoId, isEmpty);
      expect(result.totalViews, equals(0));
    });

    test('getChannelAnalytics returns empty snapshot on empty channelId', () async {
      final result = await service.getChannelAnalytics('');
      expect(result.channelId, isEmpty);
      expect(result.totalVideoWatches, equals(0));
    });

    test('cache management methods execute safely', () {
      expect(() => service.clearAnalyticsCache(), returnsNormally);
      expect(() => service.invalidateVideoCache('test_vid'), returnsNormally);
      expect(() => service.recordQualifiedView('test_vid', trafficSource: 'search'), returnsNormally);
    });
  });
}
