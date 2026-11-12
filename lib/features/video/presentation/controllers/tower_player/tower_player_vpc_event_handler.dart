import 'dart:async';

import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/features/settings/presentation/controllers/user_settings_controller.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:video_player/video_player.dart';

/// Helper methods for handling video player updates, transient error filtering, volume normalization, ad evaluation, and audio track synchronization.
class TowerPlayerVpcEventHandler {
  /// Determines whether an error message is a transient DOM interruption or harmless browser artifact
  static bool isTransientDomError(String? vpcError, String rxError) {
    final err = '${vpcError ?? ''} $rxError'.toLowerCase();
    return err.contains('removed from the document') ||
        err.contains('play() request was interrupted') ||
        err.contains('the play() request was interrupted') ||
        err.contains('aborterror') ||
        err.contains('notallowederror') ||
        err.contains('not allowed') ||
        err.contains('notallowed') ||
        err.contains("user didn't interact") ||
        err.contains('user did not interact') ||
        err.contains('interact with the document') ||
        err.contains('autoplay') ||
        err.contains('media_err_aborted') ||
        err.contains('client returned a buffer') ||
        err.contains('bad_index') ||
        err.contains('pause()') ||
        err.contains('user gesture');
  }

  /// Calculates user-configured volume scale based on volume normalization settings
  static double getNormalizedVolumeScale() {
    if (!Get.isRegistered<UserSettingsController>()) return 1.0;
    final mode = UserSettingsController.to.playback.value.volumeNormalizationMode;
    switch (mode) {
      case 'Light':
        return 0.90;
      case 'Standard':
        return 0.80;
      case 'Aggressive':
        return 0.70;
      case 'Off':
      default:
        return 1.0;
    }
  }

  static int _lastSeekTimestamp = 0;
  static int? _pendingSeekTargetMs;
  static bool _isSyncingAudio = false;

  /// Notifies the sync handler that a manual seek was initiated, resetting cooldowns
  /// and preventing machinegun re-seeks while the media buffers.
  static void notifyManualSeekInitiated() {
    _lastSeekTimestamp = DateTime.now().millisecondsSinceEpoch;
    _pendingSeekTargetMs = null;
  }

  /// Synchronize alternate audio track player volume, playback speed, and clock drift.
  /// Broadcast-grade Phase-Locked Loop (PLL) clock smoothing filter:
  /// - In-sync lock (< 40ms): Audio matches main playback speed.
  /// - Micro-drift (40ms - 200ms): Gentle slew ±4% for smooth imperceptible clock alignment.
  /// - Moderate drift (200ms - 600ms): Slew ±8% to pull audio back into lock within ~2.5s without buffer flushes.
  /// - Substantial drift (600ms - 1200ms): Slew ±14% to recover quickly without audio cuts.
  /// - Severe drift (> 1200ms, e.g. scrubbing/jump): Debounced seekTo with a 1500ms cooldown and buffering guard.
  static void syncAlternateAudioTrack({
    required VideoPlayerController mainVpc,
    required VideoPlayerController? audioCtrl,
    required bool isMuted,
    required double volume,
    bool hasAlternateAudioTrack = false,
  }) {
    if (_isSyncingAudio) return;
    _isSyncingAudio = true;
    try {
      final val = mainVpc.value;
      final targetVol = isMuted ? 0.0 : volume;

      final isInitialized = audioCtrl != null && audioCtrl.value.isInitialized;
      final hasError = audioCtrl != null && audioCtrl.value.hasError;
      final audioDur = isInitialized ? audioCtrl.value.duration : Duration.zero;
      final isAudioExhausted = isInitialized &&
          audioDur > Duration.zero &&
          val.position > audioDur;

      // Alternate audio is actively providing sound if it's selected, has a controller,
      // has no playback error, and has not exceeded its duration.
      final isAlternateActive = hasAlternateAudioTrack &&
          audioCtrl != null &&
          !hasError &&
          !isAudioExhausted;

      // 1. Single source of truth for main VPC volume (prevents cyclic oscillation & stack overflow)
      final expectedMainVol = isAlternateActive ? 0.0 : targetVol;
      if ((val.volume - expectedMainVol).abs() > 0.001) {
        mainVpc.setVolume(expectedMainVol);
      }

      // If alternate audio is missing, uninitialized, or in error state, exit cleanly
      if (audioCtrl == null || !isInitialized || hasError) {
        return;
      }

      // If video has advanced past the alternate audio duration, pause audio track
      if (isAudioExhausted) {
        if (audioCtrl.value.isPlaying) {
          audioCtrl.pause();
        }
        return;
      }

      // 2. Sync alternate audio volume
      if ((audioCtrl.value.volume - targetVol).abs() > 0.001) {
        audioCtrl.setVolume(targetVol);
      }

      // 3. Sync play/pause state
      final isVideoBuffering = val.isBuffering;
      final isAudioBuffering = audioCtrl.value.isBuffering;

      if (val.isPlaying && !isVideoBuffering && !audioCtrl.value.isPlaying) {
        audioCtrl.play();
      } else if ((!val.isPlaying || isVideoBuffering) && audioCtrl.value.isPlaying) {
        audioCtrl.pause();
      }

      // 4. Measure clock drift between video and audio (positive => audio lags behind video)
      final driftMs = (val.position - audioCtrl.value.position).inMilliseconds;
      final absDrift = driftMs.abs();
      final now = DateTime.now().millisecondsSinceEpoch;

      // Check if a prior major seek has settled
      if (_pendingSeekTargetMs != null) {
        final seekDiff = (audioCtrl.value.position.inMilliseconds - _pendingSeekTargetMs!).abs();
        if (seekDiff < 400 || (now - _lastSeekTimestamp) > 2000) {
          _pendingSeekTargetMs = null;
        } else {
          // Seek is still settling in decoder/network stream; do not trigger new seek or slew
          return;
        }
      }

      if (absDrift > 1200) {
        // Major user seek / jump: debounced seekTo to prevent machinegun buffer flushes
        // Must not interrupt an ongoing network buffer cycle
        if (!isAudioBuffering && (now - _lastSeekTimestamp > 1500)) {
          _lastSeekTimestamp = now;
          _pendingSeekTargetMs = val.position.inMilliseconds;
          audioCtrl.seekTo(val.position);
        }
      } else if (absDrift >= 40) {
        // Graduated PLL Clock Smoothing to eliminate drift smoothly without audio clicks or decode restarts
        final double slewFactor;
        if (absDrift < 200) {
          slewFactor = 0.04;
        } else if (absDrift < 600) {
          slewFactor = 0.08;
        } else {
          slewFactor = 0.14;
        }

        if (driftMs > 0) {
          // Audio is lagging behind video -> speed up audio
          final targetSpeed = (val.playbackSpeed * (1.0 + slewFactor)).clamp(0.25, 2.0);
          if ((audioCtrl.value.playbackSpeed - targetSpeed).abs() > 0.01) {
            audioCtrl.setPlaybackSpeed(targetSpeed);
          }
        } else {
          // Audio is ahead of video -> slow down audio
          final targetSpeed = (val.playbackSpeed * (1.0 - slewFactor)).clamp(0.25, 2.0);
          if ((audioCtrl.value.playbackSpeed - targetSpeed).abs() > 0.01) {
            audioCtrl.setPlaybackSpeed(targetSpeed);
          }
        }
      } else {
        // In-sync lock (< 40ms): return to main playback speed
        if ((audioCtrl.value.playbackSpeed - val.playbackSpeed).abs() > 0.005) {
          audioCtrl.setPlaybackSpeed(val.playbackSpeed);
        }
      }
    } finally {
      _isSyncingAudio = false;
    }
  }

  /// Evaluates and triggers ads during playback
  static bool handleAdTriggers({
    required VideoPlayerValue val,
    required bool shouldSuppressAds,
    required bool hasRealVideoAds,
    required bool isShowingAd,
    required VideoPlayerController mainVpc,
    required VideoPlayerController? audioCtrl,
    required String? videoId,
    required bool preRollPlayed,
    required bool midRollPlayed,
    required bool sponsorMidRollPlayed,
    required void Function(dynamic ad, {required bool isPreRoll}) onStartSponsorAd,
    required void Function({required bool isPreRoll}) onStartAd,
    required void Function(bool played) setPreRollPlayed,
    required void Function(bool played) setMidRollPlayed,
    required void Function(bool played) setSponsorMidRollPlayed,
    Duration? effectiveDuration,
  }) {
    if (!shouldSuppressAds && hasRealVideoAds) {
      final sponsorAd = Get.isRegistered<AdService>()
          ? AdService.to.getSponsorAdForVideo(videoId)
          : null;

      if (!preRollPlayed && (val.isPlaying || val.isInitialized)) {
        setPreRollPlayed(true);
        if (sponsorAd != null) {
          onStartSponsorAd(sponsorAd, isPreRoll: true);
          return true;
        } else if (AdService.to.getSkippableVideoAds().isNotEmpty) {
          onStartAd(isPreRoll: true);
          return true;
        }
      }
    }

    if (isShowingAd) {
      if (val.isPlaying) {
        mainVpc.pause();
      }
      if (audioCtrl != null && audioCtrl.value.isPlaying) {
        audioCtrl.pause();
      }
      return true;
    }

    if (!shouldSuppressAds && !isShowingAd && hasRealVideoAds) {
      final currentPos = val.position;
      final totalDur = (effectiveDuration != null && effectiveDuration > Duration.zero)
          ? effectiveDuration
          : val.duration;

      final sponsorAd = Get.isRegistered<AdService>()
          ? AdService.to.getSponsorAdForVideo(videoId)
          : null;

      if (sponsorAd != null &&
          !sponsorMidRollPlayed &&
          totalDur.inSeconds > 420 &&
          currentPos.inSeconds >= 420 &&
          val.isPlaying) {
        setSponsorMidRollPlayed(true);
        onStartSponsorAd(sponsorAd, isPreRoll: false);
        return true;
      } else if (sponsorAd == null &&
          !midRollPlayed &&
          totalDur.inSeconds > 180 &&
          currentPos.inSeconds >= (totalDur.inSeconds / 2).floor() &&
          val.isPlaying) {
        setMidRollPlayed(true);
        onStartAd(isPreRoll: false);
        return true;
      }
    }
    return false;
  }

  /// Syncs subtitles, chapters, credibility claims, and throttled track sync
  static void syncPlaybackMetadata({
    required VideoPlayerValue val,
    required bool subtitlesEnabled,
    required bool hasSubtitles,
    required void Function() startSubtitleSyncTimer,
    required void Function() stopSubtitleSyncTimer,
    required void Function() syncActiveSubtitle,
    required List<VideoChapter> chapters,
    required Rx<VideoChapter?> currentChapter,
    required VideoChapter? Function(Duration pos) binarySearchChapter,
    required void Function(Duration pos) syncActiveClaim,
    required DateTime lastTrackSync,
    required void Function() onSyncTracks,
    required void Function(DateTime time) setLastTrackSync,
    bool isTranscriptVisible = false,
  }) {
    // Subtitle & Transcript sync — timer must run whenever subtitles are enabled
    // OR when the transcript view is visible, and segments are present.
    // Pausing/buffering must NOT kill the timer because on resume there is a gap
    // before the next VPC event fires to restart it.
    final needsSync = (subtitlesEnabled || isTranscriptVisible) && hasSubtitles;
    if (needsSync) {
      startSubtitleSyncTimer();
    } else {
      stopSubtitleSyncTimer();
    }
    syncActiveSubtitle();

    // Chapter sync
    if (chapters.isNotEmpty) {
      final chapter = binarySearchChapter(val.position);
      if (currentChapter.value != chapter) currentChapter.value = chapter;
    } else {
      currentChapter.value = null;
    }

    // Active claim sync
    syncActiveClaim(val.position);

    // Throttled track sync
    final now = DateTime.now();
    if (now.difference(lastTrackSync).inSeconds >= 2) {
      setLastTrackSync(now);
      onSyncTracks();
    }
  }

  /// Evaluates and debounces playback errors, filtering out transient DOM errors
  static Timer? evaluatePlaybackErrors({
    required VideoPlayerValue val,
    required String currentErrorDesc,
    required bool isAutoSwitchingOrRecovering,
    required bool isClosed,
    required VideoPlayerController vpc,
    required Timer? currentTimer,
    required void Function(bool hasError) setHasError,
    required void Function(String desc) setErrorDescription,
  }) {
    if (currentErrorDesc != (val.errorDescription ?? '')) {
      setErrorDescription(val.errorDescription ?? '');
    }

    final isErr = val.hasError &&
        !isTransientDomError(val.errorDescription, currentErrorDesc);

    if (isErr) {
      if (!isAutoSwitchingOrRecovering) {
        currentTimer?.cancel();
        return Timer(const Duration(milliseconds: 800), () {
          if (!isClosed &&
              vpc.value.hasError &&
              !isTransientDomError(vpc.value.errorDescription, currentErrorDesc)) {
            setHasError(true);
          }
        });
      }
      return currentTimer;
    } else {
      currentTimer?.cancel();
      setHasError(false);
      return null;
    }
  }
}
