import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/analytics/data/services/impression_tracking_service.dart';
import 'package:truthworld/features/analytics/data/services/video_analytics_service.dart';
import 'package:truthworld/features/analytics/data/services/viewer_identity_service.dart';

/// Controller responsible for managing playback metrics, stopwatch timers, milestone tracking, and view qualification.
class VideoAnalyticsController extends BaseController {
  final Stopwatch _watchStopwatch = Stopwatch();
  bool _hasCountedQualifiedView = false;
  int _lastReportedWatchTime = 0;
  final Set<String> _firedMilestones = {};
  static const List<int> _milestoneThresholds = [25, 50, 75, 100];

  String trafficSource = 'direct';
  String viewerHash = '';

  int get watchTimeSeconds => _watchStopwatch.elapsed.inSeconds;

  void startTimer() {
    if (!_watchStopwatch.isRunning) {
      _watchStopwatch.start();
    }
  }

  void stopTimer() {
    if (_watchStopwatch.isRunning) {
      _watchStopwatch.stop();
    }
  }

  void resetTimer() {
    _watchStopwatch.reset();
    _hasCountedQualifiedView = false;
    _lastReportedWatchTime = 0;
    _firedMilestones.clear();
  }

  Future<void> resolveViewerIdentity() async {
    try {
      if (Get.isRegistered<ViewerIdentityService>()) {
        viewerHash = await Get.find<ViewerIdentityService>().getViewerHash();
      }
    } catch (e) {
      debugPrint(
        '[VideoAnalyticsController] Viewer identity resolution error: $e',
      );
    }
  }

  void trackPlaybackPosition(
    String videoId,
    double currentPositionSeconds,
    double totalDurationSeconds,
  ) {
    if (totalDurationSeconds <= 0 || videoId.isEmpty) return;

    final progressPct = (currentPositionSeconds / totalDurationSeconds * 100)
        .clamp(0, 100);

    // Qualified View check (e.g. at 30s or 50% watch time)
    if (!_hasCountedQualifiedView &&
        (watchTimeSeconds >= 30 || progressPct >= 50)) {
      _hasCountedQualifiedView = true;
      if (Get.isRegistered<VideoAnalyticsService>()) {
        Get.find<VideoAnalyticsService>().recordQualifiedView(
          videoId,
          trafficSource: trafficSource,
        );
      }
    }

    // Milestone Event check (25%, 50%, 75%, 100%)
    for (final threshold in _milestoneThresholds) {
      final key = '${videoId}_$threshold';
      if (progressPct >= threshold && !_firedMilestones.contains(key)) {
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
