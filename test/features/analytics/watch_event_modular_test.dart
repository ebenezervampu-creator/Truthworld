import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';

void main() {
  group('Watch Event Taxonomy & Definitions Tests', () {
    test('TrafficSourceCategory fromKey maps valid and fallback keys', () {
      expect(
        TrafficSourceCategory.fromKey('home_feed'),
        TrafficSourceCategory.homeFeed,
      );
      expect(
        TrafficSourceCategory.homeFeed.isInternal,
        isTrue,
      );
      expect(
        TrafficSourceCategory.homeFeed.isExternal,
        isFalse,
      );

      expect(
        TrafficSourceCategory.fromKey('whatsapp'),
        TrafficSourceCategory.whatsapp,
      );
      expect(
        TrafficSourceCategory.whatsapp.isExternal,
        isTrue,
      );
      expect(
        TrafficSourceCategory.whatsapp.isInternal,
        isFalse,
      );

      expect(
        TrafficSourceCategory.fromKey('nonexistent_key'),
        TrafficSourceCategory.unknown,
      );
    });

    test('FraudSignals serialization and suspicion detection', () {
      const cleanSignals = FraudSignals.clean;
      expect(cleanSignals.isSuspicious, isFalse);
      expect(cleanSignals.fraudScore, 0.0);

      const suspiciousScore = FraudSignals(fraudScore: 0.6);
      expect(suspiciousScore.isSuspicious, isTrue);

      const flaggedSignals = FraudSignals(isFlagged: true);
      expect(flaggedSignals.isSuspicious, isTrue);

      final map = {
        'viewsFromSameIP24h': 5,
        'bounceLoopCount': 2,
        'sessionVelocity': 4.5,
        'impossibleGeoJump': true,
        'suspiciousCompletion': false,
        'fingerprintMismatch': true,
        'fraudScore': 0.75,
        'isFlagged': true,
      };
      final deserialized = FraudSignals.fromMap(map);
      expect(deserialized.viewsFromSameIP24h, 5);
      expect(deserialized.impossibleGeoJump, isTrue);
      expect(deserialized.fraudScore, 0.75);
      expect(deserialized.isSuspicious, isTrue);

      final roundtrip = deserialized.toMap();
      expect(roundtrip['bounceLoopCount'], 2);
      expect(roundtrip['fingerprintMismatch'], isTrue);
    });

    test('ReturningViewerDefinition constants are strictly configured', () {
      expect(ReturningViewerDefinition.lookbackDays, 28);
      expect(ReturningViewerDefinition.minQualifiedSeconds, 20);
      expect(ReturningViewerDefinition.requiredEventType, 'qualified_view');
      expect(ReturningViewerDefinition.tooltip, isNotEmpty);
    });
  });

  group('WatchEvent and Category Tests', () {
    final now = DateTime(2026, 3, 15, 12);

    test('WatchEvent getCategory assigns proper completion buckets', () {
      final bounced = WatchEvent(
        videoId: 'v1',
        channelId: 'c1',
        userId: 'u1',
        watchedAt: now,
        watchedDuration: 15,
        videoDuration: 100,
        watchPercentage: 15,
        deviceType: 'mobile',
        videoQuality: '1080p',
      );
      expect(bounced.getCategory(), WatchtimeCategory.lessThan20);

      final under25 = bounced.copyWith(watchedDuration: 22, watchPercentage: 20);
      expect(under25.getCategory(), WatchtimeCategory.lessThan25);

      final under50 = bounced.copyWith(watchedDuration: 40, watchPercentage: 40);
      expect(under50.getCategory(), WatchtimeCategory.lessThan50);

      final under75 = bounced.copyWith(watchedDuration: 70, watchPercentage: 70);
      expect(under75.getCategory(), WatchtimeCategory.lessThan75);

      final complete = bounced.copyWith(watchedDuration: 100, watchPercentage: 100);
      expect(complete.getCategory(), WatchtimeCategory.complete);
    });

    test('WatchEvent toMap and fromMap serialization', () {
      final event = WatchEvent(
        videoId: 'vid_101',
        channelId: 'chan_202',
        userId: 'usr_303',
        sessionId: 'sess_404',
        watchedAt: now,
        watchedDuration: 45,
        videoDuration: 120,
        watchPercentage: 37.5,
        deviceType: 'desktop',
        videoQuality: '4k',
        city: 'Mumbai',
        state: 'Maharashtra',
        fraudSignals: const FraudSignals(fraudScore: 0.1),
      );

      final map = event.toMap();
      expect(map['videoId'], 'vid_101');
      expect(map['city'], 'Mumbai');
      expect(map['watchedAt'], isA<Timestamp>());

      final deserialized = WatchEvent.fromMap(map);
      expect(deserialized.videoId, 'vid_101');
      expect(deserialized.channelId, 'chan_202');
      expect(deserialized.watchedDuration, 45);
      expect(deserialized.watchPercentage, 37.5);
      expect(deserialized.fraudSignals?.fraudScore, 0.1);
    });
  });

  group('Daily & Hourly Video Stats Tests', () {
    final date = DateTime(2026, 3, 10);

    test('DailyVideoStats calculated getters and merging', () {
      final stats1 = DailyVideoStats(
        videoId: 'v1',
        channelId: 'c1',
        dateKey: '2026_03_10',
        totalViews: 100,
        totalImpressions: 1000,
        uniqueViewers: 80,
        totalWatchTimeSeconds: 4000,
        date: date,
        watched100Percent: 20,
        stateTraffic: {'Maharashtra': 50, 'Karnataka': 30},
        subscribersGained: 10,
        subscribersLost: 2,
      );

      expect(stats1.ctr, 10.0);
      expect(stats1.avgWatchDuration, 50.0);
      expect(stats1.completionRate, 25.0);

      final stats2 = DailyVideoStats(
        videoId: 'v1',
        channelId: 'c1',
        dateKey: '2026_03_10',
        totalViews: 50,
        totalImpressions: 500,
        uniqueViewers: 40,
        totalWatchTimeSeconds: 2000,
        date: date,
        watched100Percent: 10,
        stateTraffic: {'Maharashtra': 20, 'Delhi': 30},
        subscribersGained: 5,
        subscribersLost: 1,
      );

      final merged = stats1.merge(stats2);
      expect(merged.totalViews, 150);
      expect(merged.totalImpressions, 1500);
      expect(merged.uniqueViewers, 120);
      expect(merged.totalWatchTimeSeconds, 6000);
      expect(merged.stateTraffic['Maharashtra'], 70);
      expect(merged.stateTraffic['Karnataka'], 30);
      expect(merged.stateTraffic['Delhi'], 30);
      expect(merged.subscribersGained, 15);
      expect(merged.subscribersLost, 3);
    });

    test('HourlyVideoStats clean views and metrics', () {
      final hourly = HourlyVideoStats(
        videoId: 'v1',
        channelId: 'c1',
        hourKey: '2026_03_10_14',
        totalViews: 50,
        uniqueViewers: 40,
        totalWatchTimeSeconds: 1200,
        flaggedFraudViews: 5,
        watched100Percent: 10,
        hour: DateTime(2026, 3, 10, 14),
      );

      expect(hourly.avgWatchDuration, 30.0);
      expect(hourly.completionRate, 25.0);
      expect(hourly.cleanViews, 45);

      final map = hourly.toMap();
      expect(map['cleanViews'], isNull); // cleanViews is computed getter
      expect(map['flaggedFraudViews'], 5);

      final fromMap = HourlyVideoStats.fromMap(map);
      expect(fromMap.cleanViews, 45);
    });
  });

  group('Channel Stats & Snapshots Tests', () {
    test('DailyChannelStats calculations and merging', () {
      final cStats1 = DailyChannelStats(
        channelId: 'c1',
        dateKey: '2026_03_10',
        totalViews: 500,
        totalImpressions: 5000,
        uniqueViewers: 400,
        totalWatchTimeSeconds: 7200,
        date: DateTime(2026, 3, 10),
        subscribersGained: 20,
        subscribersLost: 5,
      );

      expect(cStats1.ctr, 10.0);
      expect(cStats1.totalWatchHours, 2.0);
      expect(cStats1.avgWatchDuration, 18.0);

      final cStats2 = DailyChannelStats(
        channelId: 'c1',
        dateKey: '2026_03_11',
        totalViews: 300,
        totalImpressions: 2500,
        uniqueViewers: 200,
        totalWatchTimeSeconds: 3600,
        date: DateTime(2026, 3, 11),
        subscribersGained: 10,
        subscribersLost: 2,
      );

      final merged = cStats1.merge(cStats2);
      expect(merged.totalViews, 800);
      expect(merged.totalWatchHours, 3.0);
      expect(merged.subscribersGained, 30);
      expect(merged.subscribersLost, 7);
    });

    test('VideoAnalyticsSnapshot scoring, fraud metrics, and helpers', () {
      final snapshot = VideoAnalyticsSnapshot(
        videoId: 'vid_01',
        title: 'Modular Analytics Guide',
        totalViews: 1000,
        totalUniqueViewers: 800,
        totalImpressions: 10000,
        averageWatchDuration: 60.0,
        averageWatchPercentage: 50.0,
        totalWatchTimeSeconds: 48000,
        usersCompletedVideo: 400,
        watchtimeCategoryCount: {
          WatchtimeCategory.complete: 400,
          WatchtimeCategory.lessThan50: 400,
        },
        stateTraffic: {'MH': 600, 'DL': 400},
        stateTrafficPercentage: {'MH': 60.0, 'DL': 40.0},
        cityTraffic: {'Mumbai': 500, 'Pune': 300, 'Delhi': 200},
        urbanViewers: 700,
        ruralViewers: 300,
        deviceTypeBreakdown: {'mobile': 800, 'desktop': 200},
        qualityBreakdown: {'1080p': 1000},
        trafficSourceBreakdown: {'home_feed': 900},
        suspectedFraudViews: 30,
        confirmedFraudViews: 20,
        subscribersGained: 50,
        subscribersLost: 10,
        generatedAt: DateTime(2026, 3, 15),
        estimatedReadCount: 42,
      );

      expect(snapshot.ctr, 10.0);
      expect(snapshot.cleanViews, 950);
      expect(snapshot.fraudRate, 5.0);
      expect(snapshot.viewQualityScore, 95.0);
      expect(snapshot.urbanPercentage, 70.0);
      expect(snapshot.ruralPercentage, 30.0);
      expect(snapshot.getCompletionRate(), 50.0);
      expect(snapshot.getEngagementScore(), 50.0);
      expect(snapshot.subscriberConversionRate, 5.0);

      final topStates = snapshot.getTopStates(limit: 1);
      expect(topStates.length, 1);
      expect(topStates.first.key, 'MH');
      expect(topStates.first.value, 60.0);

      final topCities = snapshot.getTopCities(limit: 2);
      expect(topCities.length, 2);
      expect(topCities.first.key, 'Mumbai');
      expect(topCities.first.value, 50.0);
    });

    test('ChannelAnalyticsSnapshot serialization and copyWith', () {
      final snapshot = ChannelAnalyticsSnapshot(
        channelId: 'chan_abc',
        channelName: 'Truth Channel',
        totalVideoWatches: 2000,
        totalUniqueViewers: 1500,
        totalImpressions: 20000,
        averageWatchDuration: 45.0,
        averageWatchPercentage: 60.0,
        totalWatchTimeSeconds: 90000,
        stateTraffic: {'TN': 1000},
        stateTrafficPercentage: {'TN': 100.0},
        generatedAt: DateTime(2026, 3, 15),
        videoCount: 10,
        totalEngagementScore: 750.0,
        urbanViewers: 800,
        ruralViewers: 200,
        subscribersGained: 100,
      );

      expect(snapshot.totalWatchHours, 25.0);
      expect(snapshot.ctr, 10.0);
      expect(snapshot.getAverageEngagementScore(), 75.0);
      expect(snapshot.urbanPercentage, 80.0);
      expect(snapshot.ruralPercentage, 20.0);
      expect(snapshot.subscriberConversionRate, 5.0);

      final copied = snapshot.copyWith(channelName: 'Truth Global');
      expect(copied.channelName, 'Truth Global');
      expect(copied.channelId, 'chan_abc');

      final map = copied.toMap();
      expect(map['channelName'], 'Truth Global');
      final fromMap = ChannelAnalyticsSnapshot.fromMap(map);
      expect(fromMap.channelId, 'chan_abc');
      expect(fromMap.channelName, 'Truth Global');
    });
  });

  group('Mapping Helpers and Models Tests', () {
    test('GeoRegionModel & RetentionFunnelModel roundtrip', () {
      const geo = GeoRegionModel(
        regionKey: 'Maharashtra',
        count: 1200,
        isIndianState: true,
      );
      final geoMap = geo.toMap();
      final geoFrom = GeoRegionModel.fromMap(geoMap);
      expect(geoFrom.regionKey, 'Maharashtra');
      expect(geoFrom.count, 1200);
      expect(geoFrom.isIndianState, isTrue);

      const funnel = RetentionFunnelModel(
        impressions: 1000,
        start: 500,
        dropOnStart: 100,
        d25: 400,
        d50: 300,
        d75: 200,
        d100: 150,
        startRate: 50.0,
        dropOnStartRate: 20.0,
        completionRate: 30.0,
      );
      final funnelMap = funnel.toMap();
      final funnelFrom = RetentionFunnelModel.fromMap(funnelMap);
      expect(funnelFrom.impressions, 1000);
      expect(funnelFrom.completionRate, 30.0);
    });

    test('Helper functions castIntMap, castDoubleMap, mergeMaps handle edge cases', () {
      expect(castIntMap(null), isEmpty);
      expect(castDoubleMap(null), isEmpty);
      expect(castDateIntMap(null), isEmpty);

      final merged = mergeMaps({'a': 1, 'b': 2}, {'b': 3, 'c': 4});
      expect(merged['a'], 1);
      expect(merged['b'], 5);
      expect(merged['c'], 4);
    });
  });
}
