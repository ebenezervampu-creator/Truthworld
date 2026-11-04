import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:video_player/video_player.dart';

/// Mixin handling player errors, automatic format fallback, and playback recovery.
mixin VideoErrorRecoveryMixin on GetxController {
  VideoPlayerController? get videoPlayerController;
  RxBool get videoError;
  RxString get rxErrorMessage;
  RxBool get rxIsLoading;
  RxBool get rxIsOffline;
  String? get offlineBlobUrl;
  RxList<VideoResolutionV2> get availableResolutions;
  Video get video;

  Future<void> fetchAvailableResolutions();
  Future<void> initializeVideoPlayer({String? overrideUrl});

  bool _isRecoveringFromFormatError = false;
  bool get isRecoveringFromFormatError => _isRecoveringFromFormatError;

  void videoErrorListener() {
    try {
      if (videoPlayerController?.value.hasError ?? false) {
        final error = videoPlayerController?.value.errorDescription ?? '';
        final lower = error.toLowerCase();

        // Ignore transient web race conditions / audio interruptions / codec resets / autoplay restrictions
        if (lower.contains('removed from the document') ||
            lower.contains('play() request was interrupted') ||
            lower.contains('the play() request was interrupted') ||
            lower.contains('aborterror') ||
            lower.contains('notallowederror') ||
            lower.contains('not allowed') ||
            lower.contains('notallowed') ||
            lower.contains("user didn't interact") ||
            lower.contains('user did not interact') ||
            lower.contains('interact with the document') ||
            lower.contains('autoplay') ||
            lower.contains('media_err_aborted') ||
            lower.contains('client returned a buffer') ||
            lower.contains('bad_index') ||
            lower.contains('pause()') ||
            lower.contains('user gesture')) {
          debugPrint(
            '[VideoController] ℹ️ Ignoring transient play() interruption or web autoplay restriction: $error',
          );
          if (kIsWeb && videoPlayerController != null) {
            try {
              videoPlayerController!.setVolume(0.0);
              videoPlayerController!.play();
            } catch (_) {}
          }
          return;
        }

        debugPrint('[VideoController] ❌ Video error: $error');

        // If this is a format/source error and we haven't already tried recovery,
        // attempt to fall back to a transcoded MP4 resolution.
        if (!_isRecoveringFromFormatError) {
          debugPrint(
            '[VideoController] 🔄 Error detected — attempting seamless fallback...',
          );
          attemptFormatFallback();
          return;
        }

        videoError.value = true;
        rxErrorMessage.value =
            'This video is currently unavailable. Please check your connection or try again.';
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoErrorRecoveryMixin.videoErrorListener',
      );
    }
  }

  /// Tries to recover from a format/source error by testing all available backup URLs.
  Future<void> attemptFormatFallback() async {
    if (_isRecoveringFromFormatError) return;
    _isRecoveringFromFormatError = true;
    videoError.value = false;
    rxIsLoading.value = true;
    try {
      // 1. If resolutions haven't been fetched yet, fetch them now
      if (availableResolutions.isEmpty) {
        await fetchAvailableResolutions();
      }

      final candidates = <String>[];

      // 2. Add all non-HLS MP4 resolutions
      for (final res in availableResolutions) {
        if (res.url.isNotEmpty &&
            !res.url.contains('.m3u8') &&
            !candidates.contains(res.url)) {
          candidates.add(res.url);
        }
      }

      // 3. Add video model adaptive resolutions
      for (final res in video.adaptiveResolutions) {
        if (res.url.isNotEmpty &&
            !res.url.contains('.m3u8') &&
            !candidates.contains(res.url)) {
          candidates.add(res.url);
        }
      }

      // 4. Add videoUrl and originalUrl
      if (video.videoUrl.isNotEmpty && !candidates.contains(video.videoUrl)) {
        candidates.add(video.videoUrl);
      }
      if (video.originalUrl.isNotEmpty &&
          !candidates.contains(video.originalUrl)) {
        candidates.add(video.originalUrl);
      }

      debugPrint(
        '[VideoController] 🔄 Testing ${candidates.length} fallback candidate(s)...',
      );

      for (final candidate in candidates) {
        try {
          final resolvedCandidate = await StorageUtils.resolveUrl(candidate);
          if (resolvedCandidate.isEmpty) continue;

          debugPrint(
            '[VideoController] 🧪 Testing fallback candidate: $resolvedCandidate',
          );
          await initializeVideoPlayer(overrideUrl: resolvedCandidate);
          if (!videoError.value &&
              videoPlayerController != null &&
              videoPlayerController!.value.isInitialized) {
            debugPrint(
              '[VideoController] ✅ Playback recovered using fallback: $resolvedCandidate',
            );
            return;
          }
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'VideoErrorRecoveryMixin.testCandidate',
          );
        }
      }

      // If all candidates fail
      debugPrint('[VideoController] ❌ All fallback candidates failed');
      videoError.value = true;
      rxErrorMessage.value =
          'This video is currently unavailable. Please check your connection or try again.';
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoErrorRecoveryMixin.attemptFormatFallback',
      );
      videoError.value = true;
      rxErrorMessage.value =
          'This video is currently unavailable. Please try again.';
    } finally {
      _isRecoveringFromFormatError = false;
      rxIsLoading.value = false;
    }
  }

  /// Attempts to re-initialize the player from the current position
  Future<void> attemptRecovery() async {
    if (videoPlayerController == null) return;

    final currentPos = videoPlayerController!.value.position;
    final wasPlaying = videoPlayerController!.value.isPlaying;

    debugPrint(
      '[VideoController] 🔄 Recovering playback from ${currentPos.inSeconds}s...',
    );

    videoError.value = false;
    rxIsLoading.value = true;

    try {
      // Re-fetch resolutions if necessary (in case URLs expired or changed)
      if (!rxIsOffline.value) {
        await fetchAvailableResolutions();
      }

      await initializeVideoPlayer(
        overrideUrl: rxIsOffline.value ? offlineBlobUrl : null,
      );

      if (videoPlayerController != null) {
        await videoPlayerController!.seekTo(currentPos);
        if (wasPlaying) {
          await videoPlayerController!.play();
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoErrorRecoveryMixin.attemptRecovery',
      );
      videoError.value = true;
      rxErrorMessage.value = 'Recovery failed. Please check your connection.';
    } finally {
      rxIsLoading.value = false;
    }
  }
}
