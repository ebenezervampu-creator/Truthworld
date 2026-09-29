import 'package:flutter/foundation.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:video_player/video_player.dart';

/// A global handoff registry to transfer an active [VideoPlayerController]
/// from a video card preview to the watch screen (`VideoScreen`).
///
/// This enables zero-latency under-a-second playback transitions by avoiding
/// re-initialization and re-buffering.
class VideoPlaybackHandoff {
  static VideoPlayerController? _activeController;
  static String? _activeVideoId;

  /// Pre-warm/pre-buffer a video stream from CDN as soon as user taps a card
  /// or initiates navigation to achieve zero-latency instant playback.
  ///
  /// On web: Skip pre-warming entirely. Web playback waits for transcoded
  /// MP4 resolutions from Firestore, so pre-warming the raw original.mp4
  /// is wasteful and causes MEDIA_ERR_SRC_NOT_SUPPORTED errors.
  ///
  /// On native: Pre-warm using HLS adaptive stream for instant playback.
  static Future<void> prewarmVideo(Video video) async {
    if (video.id.isEmpty) return;

    // Skip pre-warming on web — VideoController will wait for transcoded
    // resolutions from Firestore instead of using raw original.mp4
    if (kIsWeb) return;

    // Skip if already pre-warming or active for this video
    if (_activeVideoId == video.id && _activeController != null) {
      return;
    }

    // On native, only pre-warm if HLS is available
    String? targetUrl;
    if (video.hlsUrl.isNotEmpty && !video.hlsUrl.startsWith('gs://')) {
      targetUrl = video.hlsUrl;
    }

    if (targetUrl == null || targetUrl.isEmpty) return;

    try {
      debugPrint('[VideoPlaybackHandoff] 🚀 Pre-warming CDN stream for video: ${video.id}');
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(targetUrl),
        httpHeaders: const {
          'Connection': 'keep-alive',
          'Accept': '*/*',
        },
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      registerActiveController(video.id, controller);

      // Kick off initialization asynchronously in background
      controller.initialize().then((_) {
        debugPrint('[VideoPlaybackHandoff] ✅ Pre-warmed player initialized for: ${video.id}');
      }).catchError((dynamic e, StackTrace s) {
        ErrorHandler.log(
          e,
          stackTrace: s,
          tag: 'VideoPlaybackHandoff.prewarmVideo.initialize',
        );
        // Clean up failed pre-warm controller so VideoController doesn't inherit the error
        clear(video.id);
      });
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoPlaybackHandoff.prewarmVideo',
      );
    }
  }

  static final Map<String, Duration> _activePositions = <String, Duration>{};

  /// Register an active controller for a given video ID with optional playback position.
  static void registerActiveController(
    String videoId,
    VideoPlayerController controller, {
    Duration? position,
  }) {
    final pos = position ?? (controller.value.isInitialized ? controller.value.position : Duration.zero);
    if (pos > Duration.zero) {
      _activePositions[videoId] = pos;
    }

    // On web: skip physical controller handoff because Flutter Web binds each
    // VideoPlayerController to an HtmlElementView in the DOM. However, the exact
    // position is still preserved above in `_activePositions` for zero-offset resume.
    if (kIsWeb) return;

    debugPrint(
      '[VideoPlaybackHandoff] Registered controller for video: $videoId at pos: ${pos.inSeconds}s',
    );

    // Clean up any previously registered controller that was never claimed
    if (_activeController != null && _activeController != controller) {
      try {
        _activeController!.dispose();
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'VideoPlaybackHandoff.registerActiveController.dispose',
        );
      }
    }

    _activeController = controller;
    _activeVideoId = videoId;
  }

  /// Register an exact resume timestamp without a controller (useful for Web or warm swaps).
  static void registerResumePosition(String videoId, Duration position) {
    if (position > Duration.zero) {
      _activePositions[videoId] = position;
      debugPrint(
        '[VideoPlaybackHandoff] Registered resume position for video: $videoId (${position.inSeconds}s)',
      );
    }
  }

  /// Retrieve and clear the active resume position for a video ID.
  static Duration? retrievePosition(String videoId) {
    return _activePositions.remove(videoId);
  }

  /// Inspect the active resume position for a video ID without clearing it.
  static Duration? peekPosition(String videoId) {
    return _activePositions[videoId];
  }

  /// Inspect the active controller for a video ID without claiming it from the registry.
  static VideoPlayerController? peekController(String videoId) {
    if (kIsWeb) return null;
    if (_activeVideoId == videoId &&
        _activeController != null &&
        !_activeController!.value.hasError) {
      return _activeController;
    }
    return null;
  }

  /// Check if an active resume position is stored for this video.
  static bool hasActivePosition(String videoId) {
    return _activePositions.containsKey(videoId);
  }

  /// Retrieve the active controller for a video ID, clearing it from the registry.
  /// This transfers ownership of the controller to the caller.
  static VideoPlayerController? retrieveController(String videoId) {
    if (kIsWeb) return null;

    if (_activeVideoId == videoId && _activeController != null) {
      final controller = _activeController!;
      _activeController = null;
      _activeVideoId = null;

      // If pre-warmed controller threw an error (e.g. format error), discard it
      if (controller.value.hasError) {
        debugPrint(
          '[VideoPlaybackHandoff] ⚠️ Handed-over controller has error: ${controller.value.errorDescription}. Discarding for clean initialization.',
        );
        try {
          controller.dispose();
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'VideoPlaybackHandoff.retrieveController.dispose',
          );
        }
        return null;
      }

      debugPrint(
        '[VideoPlaybackHandoff] Retrieved controller for video: $videoId (Handing over!)',
      );
      return controller;
    }
    return null;
  }

  /// Check if the active controller for a video ID is still in the handoff (not claimed yet).
  static bool isActive(String videoId) {
    if (kIsWeb) return false;
    return _activeVideoId == videoId &&
        _activeController != null &&
        !_activeController!.value.hasError;
  }

  /// Clear/dispose the active controller for a video ID if it hasn't been claimed yet.
  static void clear(String videoId) {
    _activePositions.remove(videoId);
    if (kIsWeb) return;
    if (_activeVideoId == videoId && _activeController != null) {
      debugPrint(
        '[VideoPlaybackHandoff] Clearing/disposing controller for video: $videoId',
      );
      try {
        _activeController!.dispose();
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'VideoPlaybackHandoff.clear.dispose',
        );
      }
      _activeController = null;
      _activeVideoId = null;
    }
  }

  // ── Global Playback Coordination & Decoupling ─────────────────────────────
  static final List<VoidCallback> _pauseAllListeners = <VoidCallback>[];
  static void registerPauseListener(VoidCallback listener) => _pauseAllListeners.add(listener);
  static void unregisterPauseListener(VoidCallback listener) => _pauseAllListeners.remove(listener);

  /// Pause all active video players across the entire application.
  static void pauseAllActivePlayers() {
    for (final listener in List<VoidCallback>.from(_pauseAllListeners)) {
      try {
        listener();
      } catch (e, stackTrace) {
        ErrorHandler.log(
          e,
          stackTrace: stackTrace,
          tag: 'VideoPlaybackHandoff.pauseAllActivePlayers',
        );
      }
    }
  }

  static void Function(String? tag, VideoPlayerController? controller)? onSyncController;

  /// Sync active overlay player controller without hardcoded type coupling.
  static void syncActivePlayer(String? tag, VideoPlayerController? controller) {
    onSyncController?.call(tag, controller);
  }
}
