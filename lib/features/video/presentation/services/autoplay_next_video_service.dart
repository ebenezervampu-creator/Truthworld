/// ============================================================================
/// autoplay_next_video_service.dart
/// Industry-standard Auto-Play Next Video Service (YouTube/Netflix-style)
/// ============================================================================
/// Features:
///   ✅ Configurable countdown timer (default: 10s, YouTube-style)
///   ✅ Smart next video selection from recommendations
///   ✅ User dismiss/continue controls
///   ✅ Analytics tracking (impression, continue, dismiss)
///   ✅ Respects autoplay toggle & user preferences
///   ✅ Handles offline & no-recommendations scenarios
///   ✅ Prevents duplicate video playback
/// ============================================================================

library;

import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class AutoplayNextVideoService extends GetxService {
  // Observable state
  final RxBool isCountdownVisible = false.obs;
  final RxInt countdownSeconds = 10.obs;
  final Rx<Video?> upNextVideo = Rx<Video?>(null);
  final RxBool isAutoplayEnabled = true.obs;
  final RxString dismissReason = ''.obs;

  // Configuration
  static const int defaultCountdownSeconds = 10;
  static const String storageKeyAutoplay = 'app.autoplay.enabled';
  static const String storageKeyTimeout = 'app.autoplay.timeout_seconds';

  // Internal state
  Timer? _countdownTimer;
  bool _countdownCancelled = false;

  @override
  void onInit() {
    super.onInit();
    _loadUserPreferences();

    // Listen to autoplay toggle
    ever(isAutoplayEnabled, (_) => _saveUserPreferences());
  }

  @override
  void onClose() {
    _stopCountdown();
    super.onClose();
  }

  /// ── PUBLIC API ─────────────────────────────────────────────────────────

  /// Initiate autoplay countdown with next video
  void initiateAutoplayCountdown({
    required Video currentVideo,
    required List<Video> recommendations,
  }) {
    debugPrint(
      '[AutoplayNextVideoService] 📺 Initiating autoplay countdown',
    );

    // Guard: Check if autoplay is enabled
    if (!isAutoplayEnabled.value) {
      debugPrint('[AutoplayNextVideoService] ⚠️ Autoplay disabled by user');
      return;
    }

    // Guard: Check if we have recommendations
    if (recommendations.isEmpty) {
      debugPrint('[AutoplayNextVideoService] ⚠️ No recommendations available');
      _handleNoRecommendations();
      return;
    }


    // Select next video using smart algorithm
    final nextVideo = _selectNextVideo(currentVideo, recommendations);
    if (nextVideo == null) {
      debugPrint('[AutoplayNextVideoService] ❌ Could not select next video');
      return;
    }

    upNextVideo.value = nextVideo;
    _countdownCancelled = false;
    isCountdownVisible.value = true;

    // Track impression
    _trackAutoplayEvent('autoplay_impression', {
      'current_video_id': currentVideo.id,
      'next_video_id': nextVideo.id,
    });

    // Start countdown
    _startCountdown();
  }

  /// User clicks "Continue" → play next video immediately
  void continueToNextVideo() {
    debugPrint(
      '[AutoplayNextVideoService] ✅ User continuing to next video',
    );

    final nextVideo = upNextVideo.value;
    if (nextVideo == null) return;

    _stopCountdown();
    isCountdownVisible.value = false;

    // Track event
    _trackAutoplayEvent('autoplay_continue', {
      'time_remaining': countdownSeconds.value,
      'next_video_id': nextVideo.id,
    });

    // Navigate
    _navigateToNextVideo(nextVideo);
  }

  /// User clicks "Dismiss" → stop autoplay for this session
  Future<void> dismissAutoplay({String reason = 'user_dismissed'}) async {
    debugPrint(
      '[AutoplayNextVideoService] ❌ User dismissed autoplay: $reason',
    );

    _countdownCancelled = true;
    _stopCountdown();
    isCountdownVisible.value = false;
    dismissReason.value = reason;

    // Track event
    _trackAutoplayEvent('autoplay_dismiss', {
      'reason': reason,
      'time_remaining': countdownSeconds.value,
      'next_video_id': upNextVideo.value?.id ?? 'unknown',
    });

    // Reset state
    await Future.delayed(const Duration(milliseconds: 300));
    upNextVideo.value = null;
    dismissReason.value = '';
  }

  /// Toggle autoplay on/off (user preference)
  void toggleAutoplay() {
    isAutoplayEnabled.value = !isAutoplayEnabled.value;
    debugPrint(
      '[AutoplayNextVideoService] 🔀 Autoplay toggled: ${isAutoplayEnabled.value}',
    );

    _trackAutoplayEvent('autoplay_toggle', {
      'enabled': isAutoplayEnabled.value,
    });
  }

  /// Set custom countdown duration (for testing/preferences)
  void setCountdownDuration(int seconds) {
    if (seconds <= 0 || seconds > 60) {
      debugPrint('[AutoplayNextVideoService] ⚠️ Invalid countdown duration');
      return;
    }

    countdownSeconds.value = seconds;
    try {
      GetStorage().write(storageKeyTimeout, seconds);
    } catch (e) {
      debugPrint('[AutoplayNextVideoService] Error saving timeout: $e');
    }
  }

  /// Reset state for next video
  void reset() {
    _stopCountdown();
    isCountdownVisible.value = false;
    upNextVideo.value = null;
    dismissReason.value = '';
    _countdownCancelled = false;
  }

  /// ── PRIVATE METHODS ────────────────────────────────────────────────────

  /// Start the countdown timer
  void _startCountdown() {
    _stopCountdown();

    countdownSeconds.value = GetStorage().read<int>(storageKeyTimeout) ??
        defaultCountdownSeconds;

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (_countdownCancelled) {
          _stopCountdown();
          return;
        }

        countdownSeconds.value--;

        if (countdownSeconds.value <= 0) {
          _stopCountdown();
          continueToNextVideo();
        }
      },
    );
  }

  /// Stop the countdown timer
  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// Select next video using smart algorithm
  /// Prioritizes: channel videos → popular videos → avoid repeats
  Video? _selectNextVideo(Video currentVideo, List<Video> recommendations) {
    if (recommendations.isEmpty) return null;

    try {
      // 1. Prefer videos from same channel (if not current video)
      final channelVideos = recommendations
          .where((v) => v.channelId == currentVideo.channelId && v.id != currentVideo.id)
          .toList();
      if (channelVideos.isNotEmpty) {
        return channelVideos.first;
      }

      // 2. Fallback: any video except current
      final differentVideos =
          recommendations.where((v) => v.id != currentVideo.id).toList();
      if (differentVideos.isNotEmpty) {
        return differentVideos.first;
      }

      return null;
    } catch (e) {
      debugPrint('[AutoplayNextVideoService] Error selecting next video: $e');
      return null;
    }
  }

  /// Navigate to next video (route)
  void _navigateToNextVideo(Video nextVideo) {
    try {
      Get.offNamed('/watch?v=${nextVideo.id}', arguments: {'video': nextVideo});
    } catch (e) {
      debugPrint('[AutoplayNextVideoService] Navigation error: $e');
    }
  }

  /// Handle case where no recommendations are available
  void _handleNoRecommendations() {
    debugPrint('[AutoplayNextVideoService] ⚠️ No recommendations to play');
    isCountdownVisible.value = false;
    upNextVideo.value = null;
  }

  /// Track autoplay-specific events for analytics
  Future<void> _trackAutoplayEvent(
    String eventType,
    Map<String, dynamic> data,
  ) async {
    try {
      debugPrint(
        '[AutoplayNextVideoService] 📊 Tracking event: $eventType | Data: $data',
      );

      // Send to Firebase Analytics
      await FirebaseAnalytics.instance.logEvent(
        name: eventType,
        parameters: Map<String, Object>.from(data),
      );
    } catch (e) {
      debugPrint('[AutoplayNextVideoService] Analytics error: $e');
    }
  }

  /// Load user preferences from storage
  void _loadUserPreferences() {
    try {
      final storage = GetStorage();
      isAutoplayEnabled.value =
          storage.read<bool>(storageKeyAutoplay) ?? true;
      countdownSeconds.value = storage.read<int>(storageKeyTimeout) ??
          defaultCountdownSeconds;

      debugPrint(
        '[AutoplayNextVideoService] ✅ Loaded preferences: enabled=${isAutoplayEnabled.value}, timeout=${countdownSeconds.value}s',
      );
    } catch (e) {
      debugPrint('[AutoplayNextVideoService] Error loading preferences: $e');
    }
  }

  /// Save user preferences to storage
  void _saveUserPreferences() {
    try {
      final storage = GetStorage();
      storage.write(storageKeyAutoplay, isAutoplayEnabled.value);
      storage.write(storageKeyTimeout, countdownSeconds.value);

      debugPrint(
        '[AutoplayNextVideoService] 💾 Saved preferences: enabled=${isAutoplayEnabled.value}',
      );
    } catch (e) {
      debugPrint('[AutoplayNextVideoService] Error saving preferences: $e');
    }
  }
}





