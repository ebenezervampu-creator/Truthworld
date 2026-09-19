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

  /// Synchronize alternate audio track player volume, playback speed, and seek drift
  static void syncAlternateAudioTrack({
    required VideoPlayerController mainVpc,
    required VideoPlayerController? audioCtrl,
    required bool isMuted,
    required double volume,
  }) {
    if (audioCtrl == null || !audioCtrl.value.isInitialized) return;
    final val = mainVpc.value;
    if (val.volume > 0.0) {
      mainVpc.setVolume(0);
    }
    final targetVol = isMuted ? 0.0 : volume;
    if (audioCtrl.value.volume != targetVol) {
      audioCtrl.setVolume(targetVol);
    }
    if (val.playbackSpeed != audioCtrl.value.playbackSpeed) {
      audioCtrl.setPlaybackSpeed(val.playbackSpeed);
    }

    final audioDur = audioCtrl.value.duration;
    if (audioDur > Duration.zero && val.position > audioDur) {
      if (audioCtrl.value.isPlaying) {
        audioCtrl.pause();
      }
    } else {
      if (val.isPlaying && !audioCtrl.value.isPlaying) {
        audioCtrl.play();
      } else if (!val.isPlaying && audioCtrl.value.isPlaying) {
        audioCtrl.pause();
      }
      final drift = (val.position - audioCtrl.value.position).inMilliseconds.abs();
      if (drift > 80) {
        audioCtrl.seekTo(val.position);
      }
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
      final totalDur = val.duration;

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
