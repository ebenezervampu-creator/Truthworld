import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/data/services/geolocation_service.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';
import 'package:truthworld/features/analytics/data/services/video_presence_service.dart';
import 'package:truthworld/features/analytics/presentation/controllers/creator_analytics/creator_analytics_barrel.dart';
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

  @override
  void onClose() {
    _liveViewerSubscription?.cancel();
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
      updateVideoChartData(analytics);
      updateVideoInsights(analytics);
      updateVideoSummaryMetrics(
        analytics,
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

      final analytics = await _videoAnalyticsService.getChannelAnalytics(
        channelId,
        channelName: channelName,
        dateRange: selectedDateRange.value,
        customStart: customStartDate.value,
        customEnd: customEndDate.value,
      );

      var finalAnalytics = analytics;
      if (finalAnalytics.totalVideoWatches == 0 ||
          finalAnalytics.totalWatchTimeSeconds == 0) {
        if (channelVideos.isNotEmpty) {
          final totalV = channelVideos.fold<int>(
            0,
            (sum, v) => sum + v.viewCount,
          );
          final totalW = channelVideos.fold<int>(
            0,
            (sum, v) => sum + v.totalWatchTimeSeconds,
          );
          if (totalV > 0 || totalW > 0) {
            finalAnalytics = finalAnalytics.copyWith(
              totalVideoWatches:
                  totalV > 0 ? totalV : finalAnalytics.totalVideoWatches,
              totalUniqueViewers:
                  totalV > 0 ? totalV : finalAnalytics.totalUniqueViewers,
              totalWatchTimeSeconds:
                  totalW > 0 ? totalW : finalAnalytics.totalWatchTimeSeconds,
            );
          }
        }
      }

      if (finalAnalytics.totalVideoWatches == 0 &&
          finalAnalytics.totalWatchTimeSeconds == 0) {
        channelLoadingError.value =
            'No watch data available for this channel yet';
      }

      channelAnalytics.value = finalAnalytics;
      updateChannelChartData(finalAnalytics);
      updateChannelInsights(finalAnalytics);
      updateChannelSummaryMetrics(
        finalAnalytics,
        buildTrendData: buildContinuousTrendData,
        populateCountryChart: populateCountryChart,
        days: selectedDateRange.value.days,
      );
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
      channelVideos.value = snapshot.docs
          .map(Video.fromDocumentSnapshot)
          .toList();

      // If channelAnalytics has 0 totalVideoWatches or 0 totalWatchTime, aggregate from fetched videos
      if (channelAnalytics.value != null &&
          (channelAnalytics.value!.totalVideoWatches == 0 ||
              channelAnalytics.value!.totalWatchTimeSeconds == 0) &&
          channelVideos.isNotEmpty) {
        final totalV = channelVideos.fold<int>(
          0,
          (sum, v) => sum + v.viewCount,
        );
        final totalW = channelVideos.fold<int>(
          0,
          (sum, v) => sum + v.totalWatchTimeSeconds,
        );
        if (totalV > 0 || totalW > 0) {
          final updated = channelAnalytics.value!.copyWith(
            totalVideoWatches:
                totalV > 0 ? totalV : channelAnalytics.value!.totalVideoWatches,
            totalUniqueViewers:
                totalV > 0 ? totalV : channelAnalytics.value!.totalUniqueViewers,
            totalWatchTimeSeconds:
                totalW > 0 ? totalW : channelAnalytics.value!.totalWatchTimeSeconds,
          );
          channelAnalytics.value = updated;
          channelLoadingError.value = '';
          updateChannelSummaryMetrics(
            updated,
            buildTrendData: buildContinuousTrendData,
            populateCountryChart: populateCountryChart,
            days: selectedDateRange.value.days,
          );
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
