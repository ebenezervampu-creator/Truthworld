// ============================================================
// sleep_timer_service.dart
// Production-Grade Sleep Timer Service for Truthworld Media
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/playback_source.dart';

enum SleepTimerMode {
  off,
  duration,
  endOfVideo,
}

/// Service managing absolute timestamp-driven sleep timers with smooth volume fade-out
class SleepTimerService extends GetxService {
  static SleepTimerService get to => Get.isRegistered<SleepTimerService>()
      ? Get.find<SleepTimerService>()
      : Get.put(SleepTimerService(), permanent: true);

  final Rx<SleepTimerMode> mode = SleepTimerMode.off.obs;
  final RxInt remainingSeconds = 0.obs;
  DateTime? _expirationTime;
  Timer? _countdownTimer;

  PlaybackSource? _activePlayback;
  double _originalVolume = 1;
  bool _isFading = false;

  void setActivePlayback(PlaybackSource source) {
    _activePlayback = source;
  }

  /// Start or replace a sleep timer
  void startTimer(Duration duration, {bool isEndOfVideo = false}) {
    cancelTimer();

    if (isEndOfVideo) {
      mode.value = SleepTimerMode.endOfVideo;
      remainingSeconds.value = duration.inSeconds > 0 ? duration.inSeconds : 0;
      debugPrint('[SleepTimer] Set to End of Video');
      return;
    }

    if (duration <= Duration.zero) return;

    mode.value = SleepTimerMode.duration;
    _expirationTime = DateTime.now().add(duration);
    _updateRemainingSeconds();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    debugPrint('[SleepTimer] Started: ${duration.inMinutes}m (Expires at $_expirationTime)');
  }

  /// Extend active sleep timer (e.g. +5 minutes)
  void extendTimer(Duration addDuration) {
    if (mode.value != SleepTimerMode.duration || _expirationTime == null) {
      startTimer(addDuration);
      return;
    }

    _expirationTime = _expirationTime!.add(addDuration);
    _updateRemainingSeconds();
    debugPrint('[SleepTimer] Extended by ${addDuration.inMinutes}m');
  }

  void _tick() {
    if (_expirationTime == null || mode.value != SleepTimerMode.duration) {
      cancelTimer();
      return;
    }

    _updateRemainingSeconds();
    final rem = remainingSeconds.value;

    // Smooth volume fade-out during final 10 seconds
    if (rem <= 10 && rem > 0 && !_isFading && _activePlayback != null) {
      _startVolumeFade();
    }

    if (rem <= 0) {
      triggerExpiration();
    }
  }

  void _updateRemainingSeconds() {
    if (_expirationTime == null) return;
    final diff = _expirationTime!.difference(DateTime.now()).inSeconds;
    remainingSeconds.value = diff.clamp(0, 86400);
  }

  void _startVolumeFade() {
    _isFading = true;
    if (_activePlayback != null) {
      _originalVolume = 1.0; // Preserve base volume reference
    }

    Timer.periodic(const Duration(milliseconds: 200), (fadeTimer) {
      final rem = remainingSeconds.value;
      if (rem <= 0 || mode.value == SleepTimerMode.off) {
        fadeTimer.cancel();
        _isFading = false;
        return;
      }

      // Linear interpolation over 10 seconds: V(t) = originalVolume * (rem / 10)
      final fraction = (rem / 10.0).clamp(0.0, 1.0);
      _activePlayback?.setVolume(_originalVolume * fraction);
    });
  }

  /// Trigger timer expiration across active playback
  Future<void> triggerExpiration() async {
    debugPrint('[SleepTimer] Expired — Pausing playback');
    cancelTimer();

    if (_activePlayback != null) {
      await _activePlayback!.pause();
      // Restore volume safely so manual playback resumes at normal volume
      await _activePlayback!.setVolume(_originalVolume);
    }
  }

  /// Called when a video track ends (for End of Video mode)
  void onTrackEnded() {
    if (mode.value == SleepTimerMode.endOfVideo) {
      triggerExpiration();
    }
  }

  /// Cancel active sleep timer
  void cancelTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _expirationTime = null;
    _isFading = false;
    mode.value = SleepTimerMode.off;
    remainingSeconds.value = 0;
  }

  bool get isActive => mode.value != SleepTimerMode.off;
  bool get isAtEndOfVideo => mode.value == SleepTimerMode.endOfVideo;
}
