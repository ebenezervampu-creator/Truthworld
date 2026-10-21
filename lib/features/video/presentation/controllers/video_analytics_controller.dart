import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/analytics/data/services/impression_tracking_service.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';
import 'package:truthworld/features/analytics/data/services/video_presence_service.dart';
import 'package:truthworld/features/analytics/data/services/viewer_identity_service.dart';

/// Controller responsible for managing playback metrics, stopwatch timers, milestone tracking, and view qualification.
class VideoAnalyticsController extends BaseController {
  final Stopwatch _watchStopwatch = Stopwatch();
  int? _testWatchTimeSeconds;
  bool _hasCountedQualifiedView = false;
  final Set<String> _firedMilestones = {};
  static const List<int> _milestoneThresholds = [25, 50, 75, 100];

  String trafficSource = 'direct';
  String viewerHash = '';
  String? currentVideoId;

  int get watchTimeSeconds => _testWatchTimeSeconds ?? _watchStopwatch.elapsed.inSeconds;
  bool get hasCountedQualifiedView => _hasCountedQualifiedView;
  Set<String> get firedMilestones => Set.unmodifiable(_firedMilestones);

  @visibleForTesting
  int? get testWatchTimeSeconds => _testWatchTimeSeconds;
  @visibleForTesting
  set testWatchTimeSeconds(int? seconds) => _testWatchTimeSeconds = seconds;

  void startTimer({String? videoId, double position = 0}) {
    if (videoId != null && videoId.isNotEmpty) {
      currentVideoId = videoId;
    }
    if (!_watchStopwatch.isRunning) {
      _watchStopwatch.start();
    }
    if (currentVideoId != null && currentVideoId!.isNotEmpty) {
      VideoPresenceService.to.startWatching(
        videoId: currentVideoId!,
        position: position,
        watchedSeconds: watchTimeSeconds,
      );
    }
  }

  void stopTimer({bool immediate = false}) {
    if (_watchStopwatch.isRunning) {
      _watchStopwatch.stop();
    }
    VideoPresenceService.to.stopWatching(immediate: immediate);
  }

  void resetTimer() {
    _watchStopwatch.reset();
    _hasCountedQualifiedView = false;
    _firedMilestones.clear();
    VideoPresenceService.to.stopWatching(immediate: true);
  }

  Future<void> resolveViewerIdentity() async {
    try {
      if (Get.isRegistered<ViewerIdentityService>()) {
        viewerHash = await Get.find<ViewerIdentityService>().getViewerHash();
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'VideoAnalyticsController.resolveViewerIdentity',
      );
    }
  }

  void trackPlaybackPosition(
    String videoId,
    double currentPositionSeconds,
    double totalDurationSeconds,
  ) {
    if (totalDurationSeconds <= 0 || videoId.isEmpty) return;
    currentVideoId = videoId;

    // Send heartbeat or restore session to RTDB live presence tracker
    if (!VideoPresenceService.to.isWatching) {
      VideoPresenceService.to.startWatching(
        videoId: videoId,
        position: currentPositionSeconds,
        watchedSeconds: watchTimeSeconds,
      );
    } else {
      VideoPresenceService.to.heartbeat(
        position: currentPositionSeconds,
        watchedSeconds: watchTimeSeconds,
      );
    }

    // Calculate true watch progress percentage strictly based on actual elapsed watch time,
    // NEVER on scrubbed playhead position (prevents dragging to end from inflating metrics).
    final actualWatchPct = (watchTimeSeconds / totalDurationSeconds * 100)
        .clamp(0, 100);

    // CRITICAL POLICY: Views, qualified views, and playback milestones are strictly counted
    // ONLY for authenticated users. Unsigned / guest viewers are excluded from view counts.
    final isAuth = !Get.isRegistered<AuthService>() ||
        (AuthService.to.isAuthenticated.value && AuthService.to.uid.isNotEmpty);

    if (!isAuth) {
      // Unsigned user: Do NOT record qualified views or milestones.
      // Watch time for guest preview limits is handled exclusively by GuestPlaybackLimitService.
      return;
    }

    // Qualified View check (e.g. at 30s or 50% true watch time)
    if (!_hasCountedQualifiedView &&
        (watchTimeSeconds >= 30 || actualWatchPct >= 50)) {
      _hasCountedQualifiedView = true;
      if (Get.isRegistered<VideoAnalyticsService>()) {
        Get.find<VideoAnalyticsService>().recordQualifiedView(
          videoId,
          trafficSource: trafficSource,
        );
      }
    }

    // Milestone Event check (25%, 50%, 75%, 100%) - based strictly on true watch progress
    for (final threshold in _milestoneThresholds) {
      final key = '${videoId}_$threshold';
      if (actualWatchPct >= threshold && !_firedMilestones.contains(key)) {
        _firedMilestones.add(key);
        if (Get.isRegistered<ImpressionTrackingService>()) {
          Get.find<ImpressionTrackingService>().recordPlaybackMilestone(
            videoId: videoId,
            milestonePct: threshold,
          );
        }
      }
    }
  }

  @override
  void onClose() {
    stopTimer();
    super.onClose();
  }
}
