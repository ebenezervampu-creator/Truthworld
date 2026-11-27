import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/distributed_counter_service.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/watch_time_formatter.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/data/services/geolocation_service.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';
import 'package:truthworld/features/analytics/data/services/video_presence_service.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics/creator_analytics_barrel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';

export 'package:truthworld/features/analytics/presentation/controllers/creator_analytics/creator_analytics_barrel.dart';

/// Controller for creator analytics dashboard.
/// Reads from pre-aggregated daily stats for cost efficiency.
class CreatorAnalyticsController extends BaseController
    with
        CreatorAnalyticsChartMixin,
        CreatorAnalyticsInsightsMixin,
        CreatorAnalyticsSummaryMixin {
  static const String _tag = 'CreatorAnalyticsController';

  static CreatorAnalyticsController get to {
    if (!Get.isRegistered<CreatorAnalyticsController>()) {
      return Get.put(CreatorAnalyticsController());
    }
    return Get.find<CreatorAnalyticsController>();
  }

  final VideoAnalyticsService _videoAnalyticsService =
      Get.isRegistered<VideoAnalyticsService>()
          ? Get.find<VideoAnalyticsService>()
          : Get.put(VideoAnalyticsService());
  final GeolocationService _geolocationService =
      Get.isRegistered<GeolocationService>()
          ? Get.find<GeolocationService>()
          : Get.put(GeolocationService());
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Selection & Filter State
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

  // Channel videos list
  final channelVideos = RxList<Video>();

  // Live viewer stream subscription (RTDB)
  StreamSubscription<int>? _liveViewerSubscription;

  @override
  void onInit() {
    super.onInit();
    logger.info('Creator Analytics Controller initialized', tag: _tag);

    // Listen to video selection
    addWorker(
      ever(selectedVideoId, (videoId) {
        if (videoId.isNotEmpty) loadVideoAnalytics(videoId);
      }),
    );

    // Listen to channel selection
    addWorker(
      ever(selectedChannelId, (channelId) {
        if (channelId.isNotEmpty) {
          loadChannelAnalytics(channelId);
          fetchChannelVideos(channelId);
          if (selectedVideoId.isEmpty) {
            _startChannelLiveViewerPolling(channelId);
          }
        }
      }),
    );

    // Listen to date range changes → reload
    addWorker(
      ever(selectedDateRange, (_) {
        if (selectedVideoId.value.isNotEmpty) {
          loadVideoAnalytics(selectedVideoId.value);
        }
        if (selectedChannelId.value.isNotEmpty) {
          loadChannelAnalytics(selectedChannelId.value);
        }
      }),
    );
  }

  void clearData() {
    _liveViewerSubscription?.cancel();
    _liveViewerSubscription = null;
    videoAnalytics.value = null;
    channelAnalytics.value = null;
    channelVideos.clear();
    selectedVideoId.value = '';
    selectedChannelId.value = '';
    videoLoadingError.value = '';
    channelLoadingError.value = '';
    isLoadingVideoAnalytics.value = false;
    isLoadingChannelAnalytics.value = false;
  }

  @override
  void onClose() {
    clearData();
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

      final matchingVideo = channelVideos.firstWhereOrNull((v) => v.id == videoId);
      final currentVideoSeconds = matchingVideo?.totalWatchTimeSeconds ?? 0;
      totalWatchTime.value = WatchTimeFormatter.format(currentVideoSeconds);

      final analytics = await _videoAnalyticsService.getVideoAnalytics(
        videoId,
        videoTitle: videoTitle,
        dateRange: selectedDateRange.value,
        customStart: customStartDate.value,
        customEnd: customEndDate.value,
      );

      var finalAnalytics = analytics;
      var videoWatchTime = matchingVideo?.totalWatchTimeSeconds ?? 0;
      var videoViews = matchingVideo?.viewCount ?? 0;
      var videoDur = matchingVideo?.durationSeconds ?? 0;

      if (videoWatchTime <= 0 || videoDur <= 0 || videoViews <= 0) {
        try {
          final vDoc = await _firestore.collection(FirestoreCollections.videos).doc(videoId).get();
          if (vDoc.exists) {
            final vData = vDoc.data()!;
            if (videoDur <= 0) {
              videoDur = (vData['durationSeconds'] as num?)?.toInt() ??
                  ((vData['durationMs'] as num?) != null
                      ? (vData['durationMs'] as num).toInt() ~/ 1000
                      : (vData['duration'] != null
                          ? VideoDurationUtils.parseDuration(vData['duration']).inSeconds
                          : 0));
            }
            if (videoWatchTime <= 0) {
              videoWatchTime = (vData['totalWatchTimeSeconds'] as num?)?.toInt() ??
                  (vData['metrics'] is Map
                      ? (vData['metrics']['totalWatchTimeSeconds'] as num?)?.toInt()
                      : null) ??
                  (vData['stats'] is Map
                      ? (vData['stats']['totalWatchTimeSeconds'] as num?)?.toInt()
                      : null) ??
                  0;
            }
            if (videoViews <= 0) {
              videoViews = (vData['viewCount'] as num?)?.toInt() ??
                  (vData['views'] as num?)?.toInt() ??
                  (vData['stats'] is Map
                      ? (vData['stats']['views'] as num?)?.toInt()
                      : null) ??
                  0;
            }
          }
        } catch (_) {}
      }

      if (videoWatchTime <= 0 && Get.isRegistered<DistributedCounterService>()) {
        final shardWatch =
            await DistributedCounterService.to.getRealtimeVideoWatchTime(videoId);
        if (shardWatch > 0) {
          videoWatchTime = shardWatch;
          DistributedCounterService.to.healParentVideoWatchTime(videoId, shardWatch);
        }
      }

      if (videoDur > 0 && videoWatchTime > 0) {
        final maxAllowed = math.max(1, videoViews) * videoDur;
        videoWatchTime = math.min(videoWatchTime, maxAllowed);
      }

      if (videoWatchTime > 0 &&
          (finalAnalytics.totalWatchTimeSeconds == 0 ||
              finalAnalytics.totalWatchTimeSeconds < videoWatchTime)) {
        final effectiveViews = finalAnalytics.totalViews > 0
            ? finalAnalytics.totalViews
            : (videoViews > 0 ? videoViews : 1);
        final updatedDailyWatch =
            Map<DateTime, int>.from(finalAnalytics.dailyWatchTime);
        final dailySum =
            updatedDailyWatch.values.fold<int>(0, (s, w) => s + w);
        if (dailySum < videoWatchTime) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final diff = videoWatchTime - dailySum;
          if (updatedDailyWatch.isEmpty || dailySum == 0) {
            final daysVal = selectedDateRange.value.days;
            final daysToSpread = daysVal > 0 ? math.min(daysVal, 7) : 7;
            final portion = diff ~/ daysToSpread;
            for (var i = daysToSpread - 1; i >= 0; i--) {
              final d = today.subtract(Duration(days: i));
              updatedDailyWatch[d] = portion;
            }
            updatedDailyWatch[today] =
                (updatedDailyWatch[today] ?? 0) + (diff - portion * (daysToSpread - 1));
          } else {
            updatedDailyWatch[today] = (updatedDailyWatch[today] ?? 0) + diff;
          }
        }

        final updatedDailyViews =
            Map<DateTime, int>.from(finalAnalytics.dailyViews);
        final dailyViewsSum =
            updatedDailyViews.values.fold<int>(0, (s, w) => s + w);
        if (dailyViewsSum < effectiveViews && effectiveViews > 0) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final diff = effectiveViews - dailyViewsSum;
          updatedDailyViews[today] = (updatedDailyViews[today] ?? 0) + diff;
        }

        final updatedDailySubs =
            Map<DateTime, int>.from(finalAnalytics.dailySubscribers);
        final dailySubsSum =
            updatedDailySubs.values.fold<int>(0, (s, w) => s + w);
        if (dailySubsSum < finalAnalytics.subscribersGained &&
            finalAnalytics.subscribersGained > 0) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final diff = finalAnalytics.subscribersGained - dailySubsSum;
          updatedDailySubs[today] = (updatedDailySubs[today] ?? 0) + diff;
        }

        final effectiveAvgDur = effectiveViews > 0
            ? (videoWatchTime / effectiveViews)
            : videoWatchTime.toDouble();
        final clampedAvgDur = videoDur > 0
            ? math.min(effectiveAvgDur, videoDur.toDouble())
            : effectiveAvgDur;

        finalAnalytics = finalAnalytics.copyWith(
          totalWatchTimeSeconds: videoWatchTime,
          totalViews: effectiveViews,
          totalUniqueViewers: finalAnalytics.totalUniqueViewers > 0
              ? finalAnalytics.totalUniqueViewers
              : effectiveViews,
          averageWatchDuration: clampedAvgDur,
          dailyWatchTime: updatedDailyWatch,
          dailyViews: updatedDailyViews,
          dailySubscribers: updatedDailySubs,
        );
      } else {
        final effectiveViews = finalAnalytics.totalViews > 0
            ? finalAnalytics.totalViews
            : videoViews;
        final updatedDailyViews =
            Map<DateTime, int>.from(finalAnalytics.dailyViews);
        final dailyViewsSum =
            updatedDailyViews.values.fold<int>(0, (s, w) => s + w);
        if (dailyViewsSum < effectiveViews && effectiveViews > 0) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final diff = effectiveViews - dailyViewsSum;
          updatedDailyViews[today] = (updatedDailyViews[today] ?? 0) + diff;
        }

        final updatedDailySubs =
            Map<DateTime, int>.from(finalAnalytics.dailySubscribers);
        final dailySubsSum =
            updatedDailySubs.values.fold<int>(0, (s, w) => s + w);
        if (dailySubsSum < finalAnalytics.subscribersGained &&
            finalAnalytics.subscribersGained > 0) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final diff = finalAnalytics.subscribersGained - dailySubsSum;
          updatedDailySubs[today] = (updatedDailySubs[today] ?? 0) + diff;
        }

        if (videoDur > 0) {
          final maxWatchTime = math.max(1, effectiveViews) * videoDur;
          final clampedWatchSec =
              math.min(finalAnalytics.totalWatchTimeSeconds, maxWatchTime);
          final clampedAvgDur =
              math.min(finalAnalytics.averageWatchDuration, videoDur.toDouble());
          finalAnalytics = finalAnalytics.copyWith(
            totalViews: effectiveViews > 0 ? effectiveViews : null,
            totalWatchTimeSeconds: clampedWatchSec,
            averageWatchDuration: clampedAvgDur,
            dailyViews: updatedDailyViews,
            dailySubscribers: updatedDailySubs,
          );
        } else if (effectiveViews > 0 ||
            updatedDailyViews.isNotEmpty ||
            updatedDailySubs.isNotEmpty) {
          finalAnalytics = finalAnalytics.copyWith(
            totalViews: effectiveViews > 0 ? effectiveViews : null,
            dailyViews: updatedDailyViews,
            dailySubscribers: updatedDailySubs,
          );
        }
      }

      if (finalAnalytics.totalViews == 0 && finalAnalytics.totalWatchTimeSeconds == 0) {
        videoLoadingError.value = 'No watch data available for this video yet';
      } else {
        videoLoadingError.value = '';
      }

      videoAnalytics.value = finalAnalytics;
      updateVideoChartData(finalAnalytics);
      updateVideoInsights(finalAnalytics);
      updateVideoSummaryMetrics(
        finalAnalytics,
        buildTrendData: buildContinuousTrendData,
        populateCountryChart: populateCountryChart,
        days: selectedDateRange.value.days,
      );

      // Start live viewer stream (RTDB)
      _startLiveViewerStream(videoId);
    } catch (e, stackTrace) {
      logger.error(
        'Error loading video analytics: $e',
        stackTrace: stackTrace,
        tag: _tag,
      );
      videoLoadingError.value =
          'Unable to load analytics. Please check your connection and try again.';
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

      if (channelVideos.isEmpty) {
        await fetchChannelVideos(channelId);
      }

      final analytics = await _videoAnalyticsService.getChannelAnalytics(
        channelId,
        channelName: channelName,
        dateRange: selectedDateRange.value,
        customStart: customStartDate.value,
        customEnd: customEndDate.value,
      );

      var finalAnalytics = analytics;
      var effectiveWatches = finalAnalytics.totalVideoWatches;
      var effectiveWatchSec = finalAnalytics.totalWatchTimeSeconds;

      if (selectedDateRange.value == AnalyticsDateRange.allTime) {
        if (channelVideos.isNotEmpty) {
          final totalV = channelVideos.fold<int>(
            0,
            (sum, v) => sum + v.viewCount,
          );
          final totalW = channelVideos.fold<int>(
            0,
            (sum, v) => sum + v.totalWatchTimeSeconds,
          );
          if (effectiveWatches <= 0 || totalV > effectiveWatches) {
            effectiveWatches = totalV;
          }
          if (effectiveWatchSec <= 0 || (totalW > 0 && totalW > effectiveWatchSec)) {
            effectiveWatchSec = totalW;
          }
        }
      } else {
        // Windowed date range (7 days, 28 days, 90 days, 1 year):
        // Only estimate from channelVideos if no daily aggregated stats exist
        if (effectiveWatches <= 0 && channelVideos.isNotEmpty) {
          final range = selectedDateRange.value.calculateRange(
            customStart: customStartDate.value,
            customEnd: customEndDate.value,
          );
          final now = DateTime.now();
          var windowV = 0;
          var windowW = 0;
          for (final v in channelVideos) {
            final created = v.createdAt.toDate();
            if (created.isAfter(range.start)) {
              windowV += v.viewCount;
              windowW += v.totalWatchTimeSeconds;
            } else {
              final ageDays = math.max(1, now.difference(created).inDays);
              final winDays = math.min(selectedDateRange.value.days, ageDays);
              final ratio = winDays / ageDays;
              windowV += (v.viewCount * ratio).round();
              windowW += (v.totalWatchTimeSeconds * ratio).round();
            }
          }
          effectiveWatches = windowV;
          effectiveWatchSec = windowW;
        }
      }

      if (effectiveWatchSec <= 0 && Get.isRegistered<DistributedCounterService>()) {
        final shardWatch =
            await DistributedCounterService.to.getRealtimeChannelWatchTime(channelId);
        if (shardWatch > 0) {
          effectiveWatchSec = shardWatch;
          DistributedCounterService.to.healParentChannelWatchTime(channelId, shardWatch);
        }
      }

      final updatedDailyWatch =
          Map<DateTime, int>.from(finalAnalytics.dailyWatchTime);
      final dailySum =
          updatedDailyWatch.values.fold<int>(0, (s, w) => s + w);
      if (dailySum < effectiveWatchSec && effectiveWatchSec > 0) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final diff = effectiveWatchSec - dailySum;
        if (updatedDailyWatch.isEmpty || dailySum == 0) {
          final daysVal = selectedDateRange.value.days;
          final daysToSpread = daysVal > 0 ? math.min(daysVal, 7) : 7;
          final portion = diff ~/ daysToSpread;
          for (var i = daysToSpread - 1; i >= 0; i--) {
            final d = today.subtract(Duration(days: i));
            updatedDailyWatch[d] = portion;
          }
          updatedDailyWatch[today] =
              (updatedDailyWatch[today] ?? 0) + (diff - portion * (daysToSpread - 1));
        } else {
          updatedDailyWatch[today] = (updatedDailyWatch[today] ?? 0) + diff;
        }
      }

      final updatedDailyViews =
          Map<DateTime, int>.from(finalAnalytics.dailyViews);
      final dailyViewsSum =
          updatedDailyViews.values.fold<int>(0, (s, w) => s + w);
      if (dailyViewsSum < effectiveWatches && effectiveWatches > 0) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final diff = effectiveWatches - dailyViewsSum;
        updatedDailyViews[today] = (updatedDailyViews[today] ?? 0) + diff;
      }

      final updatedDailySubs =
          Map<DateTime, int>.from(finalAnalytics.dailySubscribers);
      final dailySubsSum =
          updatedDailySubs.values.fold<int>(0, (s, w) => s + w);
      if (dailySubsSum < finalAnalytics.subscribersGained &&
          finalAnalytics.subscribersGained > 0) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final diff = finalAnalytics.subscribersGained - dailySubsSum;
        updatedDailySubs[today] = (updatedDailySubs[today] ?? 0) + diff;
      }

      final effectiveAvgDur = effectiveWatches > 0
          ? (effectiveWatchSec / effectiveWatches)
          : 0.0;

      finalAnalytics = finalAnalytics.copyWith(
        totalVideoWatches: effectiveWatches,
        totalUniqueViewers: finalAnalytics.totalUniqueViewers > 0
            ? finalAnalytics.totalUniqueViewers
            : effectiveWatches,
        totalWatchTimeSeconds: effectiveWatchSec,
        averageWatchDuration: effectiveAvgDur,
        dailyWatchTime: updatedDailyWatch,
        dailyViews: updatedDailyViews,
        dailySubscribers: updatedDailySubs,
      );

      if (finalAnalytics.totalVideoWatches == 0 &&
          finalAnalytics.totalWatchTimeSeconds == 0) {
        channelLoadingError.value =
            'No watch data available for this channel yet';
      } else {
        channelLoadingError.value = '';
      }

      channelAnalytics.value = finalAnalytics;
      if (selectedVideoId.value.isEmpty) {
        updateChannelChartData(finalAnalytics, videos: channelVideos);
        if (channelVideos.isNotEmpty) {
          buildChannelRetentionFromVideos(channelVideos);
        }
        updateChannelInsights(finalAnalytics);
        updateChannelSummaryMetrics(
          finalAnalytics,
          buildTrendData: buildContinuousTrendData,
          populateCountryChart: populateCountryChart,
          days: selectedDateRange.value.days,
        );
      }

      // Bidirectional sync: notify active Studio DashboardController
      if (Get.isRegistered<DashboardController>()) {
        final dash = Get.find<DashboardController>();
        if (dash.channelId == channelId || dash.channelId.isEmpty) {
          dash.syncMetricsFromAnalytics(
            views: finalAnalytics.totalVideoWatches,
            watchTimeSeconds: finalAnalytics.totalWatchTimeSeconds,
            subscribers: finalAnalytics.subscribersGained,
            dailyViews: finalAnalytics.dailyViews,
          );
        }
      }
    } catch (e, stackTrace) {
      logger.error(
        'Error loading channel analytics: $e',
        stackTrace: stackTrace,
        tag: _tag,
      );
      channelLoadingError.value =
          'Unable to load channel analytics. Please check your connection and try again.';
    } finally {
      isLoadingChannelAnalytics.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // LIVE VIEWER STREAM (RTDB Real-time presence)
  // ---------------------------------------------------------------------------

  void _startLiveViewerStream(String videoId) {
    _liveViewerSubscription?.cancel();
    _liveViewerSubscription = VideoPresenceService.to
        .getLiveViewerCountStream(videoId)
        .listen(
          (count) {
            liveViewerCount.value = count;
          },
          onError: (e, stackTrace) => logger.error(
            'Error in live viewer stream',
            error: e,
            stackTrace: stackTrace,
            tag: _tag,
          ),
        );
  }

  void _startChannelLiveViewerPolling(String channelId) {
    _liveViewerSubscription?.cancel();
    _liveViewerSubscription = VideoPresenceService.to
        .getLiveViewerCountStream(null)
        .listen(
          (count) {
            if (selectedVideoId.isEmpty) {
              liveViewerCount.value = count;
            }
          },
          onError: (e, stackTrace) => logger.error(
            'Error in channel live viewer stream',
            error: e,
            stackTrace: stackTrace,
            tag: _tag,
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // CHANNEL VIDEOS & REFRESH
  // ---------------------------------------------------------------------------

  Future<void> fetchChannelVideos(String channelId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: channelId)
          .orderBy('viewCount', descending: true)
          .limit(50)
          .get();

      final resolvedVideos = <Video>[];
      for (final v in snapshot.docs.map(Video.fromDocumentSnapshot)) {
        var w = v.totalWatchTimeSeconds;
        if (w <= 0 && Get.isRegistered<DistributedCounterService>()) {
          final shardW = await DistributedCounterService.to.getRealtimeVideoWatchTime(v.id);
          if (shardW > 0) {
            w = shardW;
            DistributedCounterService.to.healParentVideoWatchTime(v.id, shardW);
          }
        }
        resolvedVideos.add(v.copyWith(totalWatchTimeSeconds: w));
      }
      channelVideos.value = resolvedVideos;

      // Aggregate and clamp channelAnalytics against fetched videos
      if (channelVideos.isNotEmpty) {
        final totalV = channelVideos.fold<int>(
          0,
          (sum, v) => sum + v.viewCount,
        );
        final totalW = channelVideos.fold<int>(
          0,
          (sum, v) => sum + v.totalWatchTimeSeconds,
        );

        if (channelAnalytics.value != null) {
          final currWatches = channelAnalytics.value!.totalVideoWatches;
          final currWatchSec = channelAnalytics.value!.totalWatchTimeSeconds;

          if (currWatches == 0 || currWatchSec == 0 || currWatchSec < totalW || currWatches < totalV) {
            if (totalV > 0 || totalW > 0) {
              final effectiveWatches = math.max(currWatches, totalV);
              final effectiveWatchSec = math.max(currWatchSec, totalW);

              final updatedDailyWatch =
                  Map<DateTime, int>.from(channelAnalytics.value!.dailyWatchTime);
              final dailySum =
                  updatedDailyWatch.values.fold<int>(0, (s, w) => s + w);
              if (dailySum < effectiveWatchSec && effectiveWatchSec > 0) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final diff = effectiveWatchSec - dailySum;
                if (updatedDailyWatch.isEmpty || dailySum == 0) {
                  final daysVal = selectedDateRange.value.days;
                  final daysToSpread = daysVal > 0 ? math.min(daysVal, 7) : 7;
                  final portion = diff ~/ daysToSpread;
                  for (var i = daysToSpread - 1; i >= 0; i--) {
                    final d = today.subtract(Duration(days: i));
                    updatedDailyWatch[d] = portion;
                  }
                  updatedDailyWatch[today] =
                      (updatedDailyWatch[today] ?? 0) + (diff - portion * (daysToSpread - 1));
                } else {
                  updatedDailyWatch[today] =
                      (updatedDailyWatch[today] ?? 0) + diff;
                }
              }

              final updatedDailyViews =
                  Map<DateTime, int>.from(channelAnalytics.value!.dailyViews);
              final dailyViewsSum =
                  updatedDailyViews.values.fold<int>(0, (s, w) => s + w);
              if (dailyViewsSum < effectiveWatches && effectiveWatches > 0) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final diff = effectiveWatches - dailyViewsSum;
                updatedDailyViews[today] =
                    (updatedDailyViews[today] ?? 0) + diff;
              }

              final effectiveAvgDur = effectiveWatches > 0
                  ? (effectiveWatchSec / effectiveWatches)
                  : 0.0;

              final updated = channelAnalytics.value!.copyWith(
                totalVideoWatches: effectiveWatches,
                totalUniqueViewers: channelAnalytics.value!.totalUniqueViewers > 0
                    ? channelAnalytics.value!.totalUniqueViewers
                    : effectiveWatches,
                totalWatchTimeSeconds: effectiveWatchSec,
                averageWatchDuration: effectiveAvgDur,
                dailyWatchTime: updatedDailyWatch,
                dailyViews: updatedDailyViews,
              );
              channelAnalytics.value = updated;
              channelLoadingError.value = '';
              if (selectedVideoId.value.isEmpty) {
                updateChannelSummaryMetrics(
                  updated,
                  buildTrendData: buildContinuousTrendData,
                  populateCountryChart: populateCountryChart,
                  days: selectedDateRange.value.days,
                );
                buildChannelRetentionFromVideos(channelVideos);
              }

              // Bidirectional sync: notify active Studio DashboardController
              if (Get.isRegistered<DashboardController>()) {
                final dash = Get.find<DashboardController>();
                if (dash.channelId == channelId || dash.channelId.isEmpty) {
                  dash.syncMetricsFromAnalytics(
                    views: effectiveWatches,
                    watchTimeSeconds: effectiveWatchSec,
                    subscribers: updated.subscribersGained,
                    dailyViews: updated.dailyViews,
                  );
                }
              }
            }
          }
        }
        buildChannelRetentionFromVideos(channelVideos);
      }

      // If a video is currently selected, refresh its analytics against fetched videos if needed
      if (selectedVideoId.value.isNotEmpty && channelVideos.isNotEmpty) {
        final currentVideo = channelVideos.firstWhereOrNull((v) => v.id == selectedVideoId.value);
        if (currentVideo != null && currentVideo.totalWatchTimeSeconds > 0) {
          final currWatch = videoAnalytics.value?.totalWatchTimeSeconds ?? 0;
          if (currWatch == 0 || currWatch < currentVideo.totalWatchTimeSeconds) {
            loadVideoAnalytics(currentVideo.id, videoTitle: currentVideo.title);
          }
        }
      }
    } catch (e) {
      logger.error('Error fetching channel videos: $e', tag: _tag);
    }
  }

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
  // PUBLIC HELPER DELEGATES
  // ---------------------------------------------------------------------------

  /// Get formatted state name from code
  String getStateName(String stateCode) {
    return CreatorGeoTaxonomyHelper.getStateName(stateCode, _geolocationService);
  }

  /// Get geographic coordinates [lat, lng] for a given region/country
  List<double>? getCoordinates(String name) {
    return CreatorGeoTaxonomyHelper.getCoordinates(name);
  }

  /// Get traffic source type (internal vs external) for grouping
  TrafficSourceType getSourceType(String key) {
    return CreatorGeoTaxonomyHelper.getSourceType(key);
  }
}
