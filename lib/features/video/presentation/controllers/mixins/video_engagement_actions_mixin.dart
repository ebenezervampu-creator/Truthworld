import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/data/models/video_clip.dart';
import 'package:truthworld/features/video/presentation/controllers/video_analytics_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_engagement_controller.dart';
import 'package:video_player/video_player.dart';

/// Mixin managing playback telemetry loop, watch time heartbeat, clip bounds enforcement, chapters, and optimistic user reactions.
mixin VideoEngagementActionsMixin on GetxController {
  Video get video;
  VideoPlayerController? get videoPlayerController;
  Rx<VideoClip?> get activeClip;
  RxBool get isPlayingRx;
  RxBool get showThumbnail;
  RxBool get isSubscribed;

  VideoEngagementController get engagementController;
  VideoAnalyticsController get analyticsController;
  MainController get mainController;
  ChannelController get channelController;
  Stopwatch get watchStopwatch;

  Set<String> get firedMilestones;
  int get lastPingWatchSeconds;
  set lastPingWatchSeconds(int val);
  int get lastReportedWatchTime;
  set lastReportedWatchTime(int val);
  bool get hasCountedQualifiedView;
  set hasCountedQualifiedView(bool val);
  String get viewerHash;

  void flushRemainingWatchTime();
  Future<void> syncWatchHistory(int watchSeconds, int totalDuration);
  bool canCountQualifiedView();
  Future<void> fireMilestoneEvent(String eventType, int position, int duration);
  void markQualifiedViewTimestamp();
  Future<void> pingWatchEvent(String eventType, int position, int duration, int deltaSeconds);
  void handleVideoCompletion(VideoPlayerValue value);

  static const List<int> _milestoneThresholds = [25, 50, 75, 100];
  static const int _watchPingIntervalSeconds = 20;
  static const int _crossDeviceResumeIntervalSeconds = 45;

  void videoListener() {
    if (videoPlayerController == null) return;
    final VideoPlayerValue value;
    try {
      value = videoPlayerController!.value;
    } catch (_) {
      return;
    }

    // --- Clip Looping Logic ---
    if (activeClip.value != null) {
      final currentPos = value.position.inMilliseconds / 1000.0;
      if (currentPos >= activeClip.value!.endTime) {
        videoPlayerController?.seekTo(
          Duration(milliseconds: (activeClip.value!.startTime * 1000).toInt()),
        );
        return; // Skip rest of listener to avoid conflicting logic
      }
      if (currentPos < activeClip.value!.startTime - 0.5) {
        // If user manually seeks before clip, we might want to allow it or snap back
        // For premium feel, if we are in "Clip Mode", we snap back unless they click "Watch Full"
        videoPlayerController?.seekTo(
          Duration(milliseconds: (activeClip.value!.startTime * 1000).toInt()),
        );
      }
    }

    // Manage thumbnail overlay & playing state safely to prevent reactive rebuilds during build
    if (isPlayingRx.value != value.isPlaying) {
      if (WidgetsBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!isClosed && isPlayingRx.value != value.isPlaying) {
            isPlayingRx.value = value.isPlaying;
          }
        });
      } else {
        isPlayingRx.value = value.isPlaying;
      }
    }
    if ((value.isInitialized || value.isPlaying) && showThumbnail.value) {
      if (WidgetsBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!isClosed && (value.isInitialized || value.isPlaying) && showThumbnail.value) {
            showThumbnail.value = false;
          }
        });
      } else {
        showThumbnail.value = false;
      }
    }

    // Manage stopwatch and analytics presence based on playback state
    if (value.isPlaying) {
      if (!watchStopwatch.isRunning) {
        watchStopwatch.start();
        analyticsController.startTimer(
          videoId: video.id,
          position: value.position.inMilliseconds / 1000.0,
        );
      } else if (!value.isBuffering) {
        analyticsController.trackPlaybackPosition(
          video.id,
          value.position.inMilliseconds / 1000.0,
          value.duration.inSeconds.toDouble(),
        );
      }
    } else {
      if (watchStopwatch.isRunning) {
        watchStopwatch.stop();
        analyticsController.stopTimer();
        flushRemainingWatchTime();
        if (value.isInitialized) {
          syncWatchHistory(watchStopwatch.elapsed.inSeconds, value.duration.inSeconds);
        }
      }
    }

    if (!value.isInitialized) return;

    final currentWatchSeconds = watchStopwatch.elapsed.inSeconds;
    final totalDuration = value.duration.inSeconds;

    // 1. Qualified View: 20s for standard videos, or min(20, duration * 0.8) for short videos (Industry Standard)
    final effectiveWatchThreshold = totalDuration > 0
        ? math.min(20, (totalDuration >= 5 ? (totalDuration * 0.8).round() : totalDuration))
        : 20;

    if (!hasCountedQualifiedView &&
        currentWatchSeconds >= effectiveWatchThreshold &&
        effectiveWatchThreshold > 0) {
      if (canCountQualifiedView()) {
        hasCountedQualifiedView = true;
        mainController.incrementViews(
          videoId: video.id,
          channelId: video.channelId,
          userId: (AuthService.to.isAuthenticated.value &&
                  AuthService.to.uid.isNotEmpty)
              ? AuthService.to.uid
              : (viewerHash.isNotEmpty ? viewerHash : 'anonymous'),
          isQualified: true,
        );

        // Fire qualified_view milestone event
        fireMilestoneEvent(
          'qualified_view',
          currentWatchSeconds,
          totalDuration,
        );
        markQualifiedViewTimestamp();

        debugPrint(
          '[VideoController] ✅ Qualified view counted at $currentWatchSeconds s (threshold: $effectiveWatchThreshold s)',
        );
      }
    }

    // 2. Completion milestones (25%, 50%, 75%, 100%) — fire once each
    if (totalDuration > 0) {
      final currentPct = (currentWatchSeconds / totalDuration) * 100;
      for (final threshold in _milestoneThresholds) {
        final key = 'milestone_$threshold';
        if (currentPct >= threshold && !firedMilestones.contains(key)) {
          firedMilestones.add(key);
          fireMilestoneEvent(key, currentWatchSeconds, totalDuration);
          debugPrint('[VideoController] 📊 Milestone $threshold% reached');
        }
      }
    }

    // 3. Cost-Effective Watch Time Heartbeat (every 20s) with auto-flush on pause/exit
    final unpingedSeconds = currentWatchSeconds - lastPingWatchSeconds;
    if (unpingedSeconds >= _watchPingIntervalSeconds) {
      pingWatchEvent('watch_ping', currentWatchSeconds, totalDuration, unpingedSeconds);
      lastPingWatchSeconds = currentWatchSeconds;
    }

    // 4. Multi-tiered resume tracking (Local GetStorage every tick + RTDB cross-device sync every 45s)
    // Firestore is NOT touched here — it is only written once on pause, completion, or exit.
    final currentPos = value.position.inSeconds;
    final progressPct = totalDuration > 0
        ? ((currentPos / totalDuration) * 100).clamp(0, 100).toDouble()
        : 0.0;

    // Fast same-device local storage (0ms, works offline, 100% free)
    WatchHistoryService.to.saveLocalPosition(video.id, currentPos, progressPct);

    // Cross-device RTDB resume sync (throttled to 45s - zero-cost operation)
    if (currentWatchSeconds - lastReportedWatchTime >= _crossDeviceResumeIntervalSeconds) {
      WatchHistoryService.to.syncCrossDeviceResume(video.id, currentPos, progressPct);
      lastReportedWatchTime = currentWatchSeconds;
    }

    // 5. Handle video completion for loop and autoplay next
    handleVideoCompletion(value);
  }

  void clearActiveClip() {
    activeClip.value = null;
    debugPrint('[VideoController] 🔓 Clip mode disabled. Playing full video.');
  }

  void applyClipIfPresent(Map<String, dynamic>? args) {
    if (args != null && args['clip'] is VideoClip) {
      final clip = args['clip'] as VideoClip;
      if (activeClip.value?.id != clip.id) {
        activeClip.value = clip;
        debugPrint('[VideoController] 🎬 Applied Clip Mode: ${clip.title}');
        if (videoPlayerController != null &&
            videoPlayerController!.value.isInitialized) {
          final startMs = (clip.startTime * 1000).toInt();
          videoPlayerController!.seekTo(Duration(milliseconds: startMs));
          videoPlayerController!.play();
        }
      }
    }
  }

  List<VideoChapter> getDisplayChapters() {
    return video.chapters;
  }

  Future<void> toggleLike() async {
    await engagementController.toggleLike(
      video.id,
      video.likeCount,
      video.dislikeCount,
    );
  }

  Future<void> toggleDislike() async {
    await engagementController.toggleDislike(
      video.id,
      video.likeCount,
      video.dislikeCount,
    );
  }

  void toggleSubscription() {
    isSubscribed.toggle();
    // Call channelController.toggleSubscription(...)
  }

}
