import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/deep_link_service.dart';
import 'package:truthworld/core/services/guest_playback_limit_service.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/home/presentation/controllers/home_feed_controller.dart';
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
  set video(Video v);
  VideoPlayerController? get videoPlayerController;
  RxBool get isPlayerInitialized;
  Rx<VideoClip?> get activeClip;
  RxBool get isPlayingRx;
  RxBool get showThumbnail;
  RxBool get isSubscribed;
  RxDouble get rxAspectRatio;
  RxBool get isSwitchingResolution;

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
  bool get isAlreadyWatched;
  set isAlreadyWatched(bool val);
  bool get isAlreadyWatchedVideo;

  void flushRemainingWatchTime();
  Future<void> syncWatchHistory(int watchSeconds, int totalDuration);
  bool canCountQualifiedView();
  Future<void> fireMilestoneEvent(String eventType, int position, int duration);
  void markQualifiedViewTimestamp();
  Future<void> pingWatchEvent(String eventType, int position, int duration, int deltaSeconds);
  void handleVideoCompletion(VideoPlayerValue value);

  static const List<int> _milestoneThresholds = [25, 50, 75, 100];
  // Industry Standard: 10-second telemetry pulse (YouTube-style heartbeat for real-time watch time tracking)
  static const int _watchPingIntervalSeconds = 10;
  static const int _crossDeviceResumeIntervalSeconds = 45;

  void videoListener() {
    if (videoPlayerController == null) return;
    final VideoPlayerValue value;
    try {
      value = videoPlayerController!.value;
    } catch (_) {
      return;
    }

    // Keep aspect ratio reactively synchronized with actual stream dimensions
    if (value.isInitialized && value.aspectRatio > 0) {
      if ((rxAspectRatio.value - value.aspectRatio).abs() > 0.001) {
        rxAspectRatio.value = value.aspectRatio;
      }
    }

    if (isPlayerInitialized.value != value.isInitialized) {
      if (WidgetsBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!isClosed && isPlayerInitialized.value != value.isInitialized) {
            isPlayerInitialized.value = value.isInitialized;
          }
        });
      } else {
        isPlayerInitialized.value = value.isInitialized;
      }
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
      if (Get.isRegistered<GuestPlaybackLimitService>()) {
        if (!GuestPlaybackLimitService.to.isPlaybackAllowed()) {
          videoPlayerController?.pause();
          GuestPlaybackLimitService.to.promptGuestSignIn();
          return;
        }
        GuestPlaybackLimitService.to.onPlaybackActive(videoId: video.id);
      }
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
      if (Get.isRegistered<GuestPlaybackLimitService>()) {
        GuestPlaybackLimitService.to.onPlaybackPaused();
      }

      // Industry standard: Do not stop stopwatch or tear down presence while actively switching resolution
      if (isSwitchingResolution.value) {
        return;
      }

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
    final isAuth = AuthService.to.isAuthenticated.value && AuthService.to.uid.isNotEmpty;

    // 1. Qualified View: 20s for standard videos, or min(20, duration * 0.8) for short videos (Industry Standard)
    // CRITICAL: Unsigned / guest viewers NEVER increment views or trigger qualified views.
    final effectiveWatchThreshold = totalDuration > 0
        ? math.min(20, (totalDuration >= 5 ? (totalDuration * 0.8).round() : totalDuration))
        : 20;

    if (isAuth &&
        !hasCountedQualifiedView &&
        !isAlreadyWatchedVideo &&
        currentWatchSeconds >= effectiveWatchThreshold &&
        effectiveWatchThreshold > 0) {
      if (canCountQualifiedView()) {
        hasCountedQualifiedView = true;
        mainController.incrementViews(
          videoId: video.id,
          channelId: video.channelId,
          userId: AuthService.to.uid,
          isQualified: true,
        );

        // Update local reactive view state immediately for instantaneous 0ms UI reactivity
        final currentViews = mainController.videoViews[video.id] ?? video.views;
        final updatedViews = currentViews + 1;
        mainController.videoViews[video.id] = updatedViews;
        final updatedVideo = video.copyWith(viewCount: updatedViews);
        video = updatedVideo;
        DeepLinkService.instance.cacheVideo(updatedVideo);

        if (Get.isRegistered<HomeFeedController>()) {
          Get.find<HomeFeedController>().updateVideo(updatedVideo);
        }

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

    // 2. Completion milestones (25%, 50%, 75%, 100%) — fire once each (authenticated users only)
    if (isAuth && totalDuration > 0 && !isAlreadyWatchedVideo) {
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
    // Unsigned users do not credit watch time to channels (handled for preview limits only by GuestPlaybackLimitService)
    if (isAuth) {
      final unpingedSeconds = currentWatchSeconds - lastPingWatchSeconds;
      if (unpingedSeconds >= _watchPingIntervalSeconds) {
        if (!isAlreadyWatchedVideo) {
          pingWatchEvent('watch_ping', currentWatchSeconds, totalDuration, unpingedSeconds);
        }
        lastPingWatchSeconds = currentWatchSeconds;
      }
    }

    // 4. Multi-tiered resume tracking (Local GetStorage every tick + RTDB cross-device sync every 45s)
    // Firestore is NOT touched here — it is only written once on pause, completion, or exit.
    final currentPos = value.position.inSeconds;
    // Transparent watch progress: percentage MUST reflect true watch time, NOT scrubbed position!
    final actualWatchPct = totalDuration > 0
        ? ((currentWatchSeconds / totalDuration) * 100).clamp(0, 100).toDouble()
        : 0.0;

    // Fast same-device local storage (0ms, works offline, 100% free)
    WatchHistoryService.to.saveLocalPosition(video.id, currentPos, actualWatchPct);

    // Cross-device RTDB resume sync (throttled to 45s - zero-cost operation)
    if (currentWatchSeconds - lastReportedWatchTime >= _crossDeviceResumeIntervalSeconds) {
      WatchHistoryService.to.syncCrossDeviceResume(video.id, currentPos, actualWatchPct);
      lastReportedWatchTime = currentWatchSeconds;
    }

    // Auto-mark video as watched once user has actually watched >= 90% of duration
    if (totalDuration > 0 && currentWatchSeconds >= (totalDuration * 0.90) && !isAlreadyWatched) {
      isAlreadyWatched = true;
      if (Get.isRegistered<WatchHistoryService>()) {
        WatchHistoryService.to.markVideoFullyWatched(video.id);
      }
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
          final resumeMs = args['resumePosition'] as int? ??
              (args['initialPosition'] is Duration
                  ? (args['initialPosition'] as Duration).inMilliseconds
                  : null);
          final startMs = resumeMs ?? (clip.startTime * 1000).toInt();
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
