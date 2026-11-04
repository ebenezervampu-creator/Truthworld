import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/services/distributed_counter_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/data/services/analytics/channel_analytics_aggregator.dart';
import 'package:truthworld/features/analytics/data/services/analytics/fraud_overview.dart';
import 'package:truthworld/features/analytics/data/services/analytics/video_analytics_aggregator.dart';
import 'package:truthworld/features/analytics/data/services/geolocation_service.dart';
import 'package:truthworld/features/video/data/models/video/video_duration_utils.dart';

/// Client executing Firestore queries and live counter fallbacks for video and channel analytics.
class AnalyticsFirestoreClient {
  AnalyticsFirestoreClient({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _tag = 'AnalyticsFirestoreClient';
  final FirebaseFirestore _firestore;
  final _dateFormat = DateFormat('yyyy_MM_dd');
  final _hourFormat = DateFormat('yyyy_MM_dd_HH');

  /// Fetch DailyVideoStats documents for a video in a date range.
  Future<List<DailyVideoStats>> fetchDailyVideoStats(
    String videoId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final startKey = _dateFormat.format(start);
      final endKey = _dateFormat.format(end);

      final snapshot = await _firestore
          .collection('video_stats_daily')
          .where('videoId', isEqualTo: videoId)
          .get();

      final allStats = snapshot.docs
          .map((doc) => DailyVideoStats.fromMap(doc.data()))
          .toList();

      final filteredStats = allStats.where((stats) {
        return stats.dateKey.compareTo(startKey) >= 0 &&
            stats.dateKey.compareTo(endKey) <= 0;
      }).toList();

      filteredStats.sort((a, b) => b.dateKey.compareTo(a.dateKey));
      return filteredStats.take(365).toList();
    } catch (e) {
      logger.warning('Error fetching daily video stats: $e', tag: _tag);
      return [];
    }
  }

  /// Build analytics from live video doc counters (fallback when no daily stats exist).
  Future<VideoAnalyticsSnapshot> buildFromLiveVideoCounters(
    String videoId,
    String title,
  ) async {
    try {
      final doc = await _firestore.collection('videos').doc(videoId).get();
      if (!doc.exists) {
        return const VideoAnalyticsAggregator().createEmptyVideoAnalytics(
          videoId,
          title,
        );
      }

      final data = doc.data()!;
      final viewCount = (data['viewCount'] as num?)?.toInt() ??
          (data['views'] as num?)?.toInt() ??
          (data['stats'] is Map
              ? (data['stats']['views'] as num?)?.toInt()
              : null) ??
          0;
      var watchTime = (data['totalWatchTimeSeconds'] as num?)?.toInt() ??
          (data['metrics'] is Map
              ? (data['metrics']['totalWatchTimeSeconds'] as num?)?.toInt()
              : null) ??
          (data['stats'] is Map
              ? (data['stats']['totalWatchTimeSeconds'] as num?)?.toInt()
              : null) ??
          0;
      final durationSec = (data['durationSeconds'] as num?)?.toInt() ??
          ((data['durationMs'] as num?) != null
              ? (data['durationMs'] as num).toInt() ~/ 1000
              : (data['duration'] != null
                  ? VideoDurationUtils.parseDuration(data['duration']).inSeconds
                  : 0));

      if (watchTime <= 0 && Get.isRegistered<DistributedCounterService>()) {
        final shardWatchTime =
            await DistributedCounterService.to.getRealtimeVideoWatchTime(videoId);
        if (shardWatchTime > 0) {
          watchTime = shardWatchTime;
          DistributedCounterService.to.healParentVideoWatchTime(videoId, shardWatchTime);
        }
      }

      if (durationSec > 0 && watchTime > 0) {
        final maxAllowed = math.max(1, viewCount) * durationSec;
        if (watchTime > maxAllowed) {
          watchTime = maxAllowed;
        }
      }

      final avgDuration = viewCount > 0
          ? (durationSec > 0
              ? (watchTime / viewCount).clamp(0.0, durationSec.toDouble())
              : (watchTime / viewCount))
          : (watchTime > 0 ? watchTime.toDouble() : 0.0);

      final avgPercentage = durationSec > 0
          ? ((avgDuration / durationSec) * 100).clamp(0.0, 100.0)
          : 0.0;

      final categoryCount = <WatchtimeCategory, int>{
        for (final cat in WatchtimeCategory.values) cat: 0,
      };
      if (viewCount > 0 && durationSec > 0) {
        if (avgPercentage >= 100.0) {
          categoryCount[WatchtimeCategory.complete] = viewCount;
        } else if (avgPercentage >= 75.0) {
          categoryCount[WatchtimeCategory.lessThan75] = viewCount;
        } else if (avgPercentage >= 50.0) {
          categoryCount[WatchtimeCategory.lessThan50] = viewCount;
        } else if (avgPercentage >= 25.0) {
          categoryCount[WatchtimeCategory.lessThan25] = viewCount;
        } else {
          categoryCount[WatchtimeCategory.lessThan20] = viewCount;
        }
      }

      return VideoAnalyticsSnapshot(
        videoId: videoId,
        title: data['title'] as String? ?? title,
        totalViews: viewCount,
        totalUniqueViewers: viewCount,
        averageWatchDuration: avgDuration,
        averageWatchPercentage: avgPercentage,
        totalWatchTimeSeconds: watchTime,
        usersCompletedVideo: avgPercentage >= 100.0 ? viewCount : 0,
        watchtimeCategoryCount: categoryCount,
        stateTraffic: {},
        stateTrafficPercentage: {},
        deviceTypeBreakdown: {},
        qualityBreakdown: {},
        generatedAt: DateTime.now(),
        estimatedReadCount: 1,
        dailyViews: {DateTime.now(): viewCount},
        dailyWatchTime: {DateTime.now(): watchTime},
      );
    } catch (e) {
      return const VideoAnalyticsAggregator().createEmptyVideoAnalytics(
        videoId,
        title,
      );
    }
  }

  /// Fetch daily channel stats documents.
  Future<List<DailyChannelStats>> fetchDailyChannelStats(
    String channelId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final startKey = _dateFormat.format(start);
      final endKey = _dateFormat.format(end);

      final snapshot = await _firestore
          .collection('channel_stats_daily')
          .where('channelId', isEqualTo: channelId)
          .get();

      final allStats = snapshot.docs
          .map((doc) => DailyChannelStats.fromMap(doc.data()))
          .toList();

      final filteredStats = allStats.where((stats) {
        return stats.dateKey.compareTo(startKey) >= 0 &&
            stats.dateKey.compareTo(endKey) <= 0;
      }).toList();

      filteredStats.sort((a, b) => b.dateKey.compareTo(a.dateKey));
      return filteredStats.take(365).toList();
    } catch (e) {
      logger.warning('Error fetching daily channel stats: $e', tag: _tag);
      return [];
    }
  }

  /// Fetch video daily stats for a specific channel.
  Future<List<DailyVideoStats>> fetchChannelVideoDailyStats(
    String channelId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final startKey = _dateFormat.format(start);
      final endKey = _dateFormat.format(end);

      final snapshot = await _firestore
          .collection('video_stats_daily')
          .where('channelId', isEqualTo: channelId)
          .get();

      final allStats = snapshot.docs
          .map((doc) => DailyVideoStats.fromMap(doc.data()))
          .toList();

      final filteredStats = allStats.where((stats) {
        return stats.dateKey.compareTo(startKey) >= 0 &&
            stats.dateKey.compareTo(endKey) <= 0;
      }).toList();

      return filteredStats.take(500).toList();
    } catch (e) {
      logger.error('Error fetching channel video daily stats: $e', tag: _tag);
      return [];
    }
  }

  /// Build channel analytics from live document counters (fallback).
  Future<ChannelAnalyticsSnapshot> buildChannelFromLiveCounters(
    String channelId,
    String channelName,
  ) async {
    try {
      final doc = await _firestore.collection('channels').doc(channelId).get();
      if (!doc.exists) {
        return const ChannelAnalyticsAggregator().createEmptyChannelAnalytics(
          channelId,
          channelName,
        );
      }

      final data = doc.data()!;
      final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
      var views =
          (metrics['totalViews'] as num?)?.toInt() ??
          (data['viewCount'] as num?)?.toInt() ??
          0;
      var watchTimeSec =
          (data['totalWatchTimeSeconds'] as num?)?.toInt() ??
          (metrics['totalWatchTimeSeconds'] as num?)?.toInt() ??
          (((metrics['totalWatchTimeMinutes'] as num?)?.toDouble() ??
                  (data['totalWatchTimeMinutes'] as num?)?.toDouble() ??
                  0) *
              60)
              .round();
      final subCount = (data['subscriberCount'] as num?)?.toInt() ?? 0;

      if (watchTimeSec <= 0 && Get.isRegistered<DistributedCounterService>()) {
        final shardWatch =
            await DistributedCounterService.to.getRealtimeChannelWatchTime(channelId);
        if (shardWatch > 0) {
          watchTimeSec = shardWatch;
          DistributedCounterService.to.healParentChannelWatchTime(channelId, shardWatch);
        }
      }

      // Aggregate from channel videos to ensure watch time never exceeds video durations
      final countryTraffic = <String, int>{};
      final stateTraffic = <String, int>{};
      final cityTraffic = <String, int>{};
      var liveUrban = 0;
      var liveRural = 0;
      var liveSubViews = 0;
      var liveUniqueUsers = 0;

      try {
        final videosSnap = await _firestore
            .collection('videos')
            .where('channelId', isEqualTo: channelId)
            .get();
        var aggregatedViews = 0;
        var aggregatedWatchSec = 0;
        for (final vDoc in videosSnap.docs) {
          final vData = vDoc.data();
          final vViews = (vData['viewCount'] as num?)?.toInt() ?? 0;
          var vWatchSec =
              (vData['totalWatchTimeSeconds'] as num?)?.toInt() ?? 0;
          final vDurSec = (vData['durationSeconds'] as num?)?.toInt() ??
              ((vData['durationMs'] as num?) != null
                  ? (vData['durationMs'] as num).toInt() ~/ 1000
                  : 0);

          if (vWatchSec <= 0 && vViews > 0 && vDurSec > 0) {
            vWatchSec = math.min(vViews * vDurSec, (vViews * vDurSec * 0.75).round());
            if (Get.isRegistered<DistributedCounterService>()) {
              DistributedCounterService.to.healParentVideoWatchTime(vDoc.id, vWatchSec);
            }
          }

          if (vDurSec > 0 && vWatchSec > 0) {
            final maxAllowed = math.max(1, vViews) * vDurSec;
            if (vWatchSec > maxAllowed) {
              vWatchSec = maxAllowed;
            }
          }
          aggregatedViews += vViews;
          aggregatedWatchSec += vWatchSec;

          // Load stats from video_stats collection if present
          try {
            final vsDoc = await _firestore.collection('video_stats').doc(vDoc.id).get();
            if (vsDoc.exists && vsDoc.data() != null) {
              final sData = vsDoc.data()!;
              liveSubViews += (sData['totalSubscribers'] as num?)?.toInt() ??
                  (sData['subscriberViews'] as num?)?.toInt() ?? 0;
              liveUrban += (sData['urbanViewers'] as num?)?.toInt() ?? 0;
              liveRural += (sData['ruralViewers'] as num?)?.toInt() ?? 0;
              liveUniqueUsers += (sData['uniqueUsers'] as num?)?.toInt() ?? 0;

              final cTraffic = sData['countryTraffic'];
              if (cTraffic is Map) {
                for (final e in cTraffic.entries) {
                  final k = e.key.toString();
                  final v = (e.value as num?)?.toInt() ?? 0;
                  countryTraffic[k] = (countryTraffic[k] ?? 0) + v;
                }
              }

              final sTraffic = sData['stateTraffic'];
              if (sTraffic is Map) {
                for (final e in sTraffic.entries) {
                  final k = e.key.toString();
                  final v = (e.value as num?)?.toInt() ?? 0;
                  stateTraffic[k] = (stateTraffic[k] ?? 0) + v;
                }
              }

              final ciTraffic = sData['cityTraffic'];
              if (ciTraffic is Map) {
                for (final e in ciTraffic.entries) {
                  final k = e.key.toString();
                  final v = (e.value as num?)?.toInt() ?? 0;
                  cityTraffic[k] = (cityTraffic[k] ?? 0) + v;
                }
              }
            }
          } catch (_) {}
        }
        if (views == 0 && aggregatedViews > 0) views = aggregatedViews;
        if (watchTimeSec == 0 && aggregatedWatchSec > 0) {
          watchTimeSec = aggregatedWatchSec;
          if (Get.isRegistered<DistributedCounterService>()) {
            DistributedCounterService.to.healParentChannelWatchTime(channelId, watchTimeSec);
          }
        } else if (aggregatedWatchSec > 0 && watchTimeSec > aggregatedWatchSec) {
          watchTimeSec = aggregatedWatchSec;
        }
      } catch (e, s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'AnalyticsFirestoreClient.aggregateChannelMetrics',
        );
      }

      // Reconcile and normalize countryTraffic
      // 1. If stateTraffic or cityTraffic has Indian states/cities, ensure those views are mapped to 'IN'
      final indianStateViews = stateTraffic.entries
          .where((e) => GeolocationService.isIndianState(e.key))
          .fold<int>(0, (a, b) => a + b.value);
      final indianCityViews = cityTraffic.entries
          .where((e) => GeolocationService.isIndianCity(e.key))
          .fold<int>(0, (a, b) => a + b.value);
      final verifiedIndianGeoViews = math.max(indianStateViews, indianCityViews);

      if (verifiedIndianGeoViews > 0) {
        countryTraffic['IN'] = math.max(countryTraffic['IN'] ?? 0, verifiedIndianGeoViews);
        // If US was recorded due to proxy hop or legacy default, rectify it
        if (countryTraffic.containsKey('US') && countryTraffic['US']! <= verifiedIndianGeoViews) {
          countryTraffic.remove('US');
        } else if (countryTraffic.containsKey('US')) {
          countryTraffic['US'] = countryTraffic['US']! - verifiedIndianGeoViews;
        }
      }

      // 2. If countryTraffic is empty but views exist, derive from channel location or default IN
      if (countryTraffic.isEmpty && views > 0) {
        final rawCountry = (data['country'] as String?)?.trim();
        String cCode = 'IN';
        if (rawCountry != null && rawCountry.isNotEmpty) {
          if (rawCountry.toUpperCase() == 'IN' || rawCountry.toLowerCase() == 'india') {
            cCode = 'IN';
          } else if (rawCountry.toUpperCase() == 'US' || rawCountry.toLowerCase() == 'united states') {
            final isCreatorIndian = (Get.isRegistered<AuthService>() &&
                    AuthService.to.userCountry.value == 'IN') ||
                (Get.isRegistered<CurrencyLocalizationService>() &&
                    CurrencyLocalizationService.to.userCountryCode.value == 'IN');
            cCode = isCreatorIndian ? 'IN' : 'US';
          } else if (rawCountry.length == 2) {
            cCode = rawCountry.toUpperCase();
          }
        }
        countryTraffic[cCode] = views;
      }

      final countryTotal = countryTraffic.values.fold<int>(0, (a, b) => a + b);
      final countryPct = <String, double>{};
      for (final e in countryTraffic.entries) {
        countryPct[e.key] = countryTotal > 0 ? (e.value / countryTotal) * 100 : 0.0;
      }

      final stateTotal = stateTraffic.values.fold<int>(0, (a, b) => a + b);
      final statePct = <String, double>{};
      for (final e in stateTraffic.entries) {
        statePct[e.key] = stateTotal > 0 ? (e.value / stateTotal) * 100 : 0.0;
      }

      final effectiveSubViews = liveSubViews > 0
          ? liveSubViews
          : (subCount > 0 && views > 0 ? math.min(views, subCount) : 0);
      final effectiveNonSubViews = math.max(0, views - effectiveSubViews);
      final effectiveUnique = liveUniqueUsers > 0 ? liveUniqueUsers : views;
      final effectiveReturning = math.max(0, views - effectiveUnique);

      var effectiveUrban = liveUrban;
      var effectiveRural = liveRural;
      if (effectiveUrban == 0 && effectiveRural == 0 && views > 0) {
        effectiveUrban = (views * 0.65).round();
        effectiveRural = math.max(0, views - effectiveUrban);
      }

      return ChannelAnalyticsSnapshot(
        channelId: channelId,
        channelName: data['name'] as String? ?? channelName,
        totalVideoWatches: views,
        totalUniqueViewers: effectiveUnique,
        averageWatchDuration: views > 0 ? watchTimeSec / views : 0,
        averageWatchPercentage: 0,
        totalWatchTimeSeconds: watchTimeSec,
        stateTraffic: stateTraffic,
        stateTrafficPercentage: statePct,
        cityTraffic: cityTraffic,
        cityTrafficPercentage: {},
        countryTraffic: countryTraffic,
        countryTrafficPercentage: countryPct,
        urbanViewers: effectiveUrban,
        ruralViewers: effectiveRural,
        dailySubscribers: {DateTime.now(): subCount},
        dailyViews: {DateTime.now(): views},
        dailyWatchTime: {DateTime.now(): watchTimeSec},
        generatedAt: DateTime.now(),
        videoCount: (data['videoCount'] as num?)?.toInt() ?? 0,
        totalEngagementScore: 0,
        subscriberViews: effectiveSubViews,
        nonSubscriberViews: effectiveNonSubViews,
        returningViewers: effectiveReturning,
        subscribersGained: subCount,
      );
    } catch (e) {
      logger.error('Error building channel from live counters: $e', tag: _tag);
      return const ChannelAnalyticsAggregator().createEmptyChannelAnalytics(
        channelId,
        channelName,
      );
    }
  }

  /// Fetch last N hours of stats for a video.
  Future<List<HourlyVideoStats>> getRecentHourlyStats(
    String videoId, {
    int hours = 24,
  }) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(hours: hours));
      final cutoffKey = _hourFormat.format(cutoff);

      final snapshot = await _firestore
          .collection('video_stats_hourly')
          .where('videoId', isEqualTo: videoId)
          .where('hourKey', isGreaterThanOrEqualTo: cutoffKey)
          .orderBy('hourKey', descending: true)
          .limit(hours.clamp(1, 72))
          .get();

      return snapshot.docs
          .map((doc) => HourlyVideoStats.fromMap(doc.data()))
          .toList();
    } catch (e) {
      logger.warning('Error fetching hourly stats: $e', tag: _tag);
      return [];
    }
  }

  /// Get aggregated stats for today by summing hourly docs.
  Future<HourlyVideoStats?> getTodayAggregatedHourly(String videoId) async {
    try {
      final today = _dateFormat.format(DateTime.now());

      final snapshot = await _firestore
          .collection('video_stats_hourly')
          .where('videoId', isEqualTo: videoId)
          .where('hourKey', isGreaterThanOrEqualTo: '${today}_00')
          .where('hourKey', isLessThanOrEqualTo: '${today}_23')
          .get();

      if (snapshot.docs.isEmpty) return null;

      final hourlyStats = snapshot.docs
          .map((doc) => HourlyVideoStats.fromMap(doc.data()))
          .toList();

      var views = 0, unique = 0, watchTime = 0, subViews = 0, nonSubViews = 0;
      var bounced = 0;
      var w25 = 0;
      var w50 = 0;
      var w75 = 0;
      var w100 = 0;
      var flagged = 0;
      final trafficSources = <String, int>{};

      for (final h in hourlyStats) {
        views += h.totalViews;
        unique += h.uniqueViewers;
        watchTime += h.totalWatchTimeSeconds;
        subViews += h.subscriberViews;
        nonSubViews += h.nonSubscriberViews;
        bounced += h.bouncedUnder20s;
        w25 += h.watched25Percent;
        w50 += h.watched50Percent;
        w75 += h.watched75Percent;
        w100 += h.watched100Percent;
        flagged += h.flaggedFraudViews;
        VideoAnalyticsAggregator.mergeInto(
          trafficSources,
          h.trafficSourceBreakdown,
        );
      }

      return HourlyVideoStats(
        videoId: videoId,
        channelId: hourlyStats.first.channelId,
        hourKey: '${today}_aggregated',
        totalViews: views,
        uniqueViewers: unique,
        totalWatchTimeSeconds: watchTime,
        subscriberViews: subViews,
        nonSubscriberViews: nonSubViews,
        bouncedUnder20s: bounced,
        watched25Percent: w25,
        watched50Percent: w50,
        watched75Percent: w75,
        watched100Percent: w100,
        trafficSourceBreakdown: trafficSources,
        flaggedFraudViews: flagged,
        hour: DateTime.now(),
      );
    } catch (e) {
      logger.warning('Error fetching today hourly stats: $e', tag: _tag);
      return null;
    }
  }

  /// Check if a qualified view was already recorded today (server-side dedup).
  Future<bool> hasQualifiedViewToday(String videoId, String userId) async {
    try {
      final today = _dateFormat.format(DateTime.now());
      final dedupKey = '${videoId}_${userId}_$today';
      final doc = await _firestore
          .collection('qualified_views')
          .doc(dedupKey)
          .get();
      return doc.exists;
    } catch (e) {
      logger.warning('Error checking dedup: $e', tag: _tag);
      return false;
    }
  }

  /// Get fraud overview for a video.
  Future<FraudOverview> getFraudOverview(
    String videoId, {
    int days = 28,
  }) async {
    try {
      final startKey = _dateFormat.format(
        DateTime.now().subtract(Duration(days: days)),
      );
      final endKey = _dateFormat.format(DateTime.now());

      final snapshot = await _firestore
          .collection('video_stats_hourly')
          .where('videoId', isEqualTo: videoId)
          .where('hourKey', isGreaterThanOrEqualTo: '${startKey}_00')
          .where('hourKey', isLessThanOrEqualTo: '${endKey}_23')
          .limit(672)
          .get();

      var totalViews = 0;
      var flaggedViews = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalViews += (data['totalViews'] as num?)?.toInt() ?? 0;
        flaggedViews += (data['flaggedFraudViews'] as num?)?.toInt() ?? 0;
      }

      return FraudOverview(
        totalViews: totalViews,
        flaggedViews: flaggedViews,
        cleanViews: totalViews - flaggedViews,
        fraudRate: totalViews > 0 ? (flaggedViews / totalViews) * 100 : 0,
      );
    } catch (e) {
      return FraudOverview.clean;
    }
  }

  /// Get total live viewers for a channel from channel document.
  Future<int> getChannelLiveViewerCount(String channelId) async {
    try {
      final doc = await _firestore.collection('channels').doc(channelId).get();
      return (doc.data()?['liveViewerCount'] as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
