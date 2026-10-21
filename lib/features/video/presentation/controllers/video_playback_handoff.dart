import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
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
  static final Set<String> _inFlightPrewarm = <String>{};

  /// Pre-warm/pre-buffer a video stream from Google CDN as soon as user taps a card
  /// or initiates navigation to achieve zero-latency instant playback.
  static Future<void> prewarmVideo(Video video) async {
    if (video.id.isEmpty) return;

    // On web: Skip physical controller handoff because Flutter Web binds each
    // VideoPlayerController to an HtmlElementView in the DOM. However, the exact
    // position is still preserved in `_activePositions` for zero-offset resume.
    if (kIsWeb) return;

    // Skip if already pre-warming or active for this video
    if (_inFlightPrewarm.contains(video.id) ||
        (_activeVideoId == video.id &&
            _activeController != null &&
            !_activeController!.value.hasError)) {
      return;
    }

    _inFlightPrewarm.add(video.id);

    try {
      // Determine the optimal Google CDN stream for instant pre-warming
      String? targetUrl;
      if (video.hlsUrl.isNotEmpty && !video.hlsUrl.startsWith('gs://')) {
        targetUrl = video.hlsUrl;
      } else if (video.adaptiveResolutions.isNotEmpty) {
        final hasPremium = Get.isRegistered<AuthService>() && AuthService.to.hasFullPremium;
        final eligible = hasPremium
            ? video.adaptiveResolutions
            : video.adaptiveResolutions.where((r) => r.height <= 1040).toList();
        final searchList = eligible.isNotEmpty ? eligible : video.adaptiveResolutions;
        final mp4Res = searchList.firstWhereOrNull(
          (r) =>
              r.url.isNotEmpty &&
              !r.url.contains('.m3u8') &&
              !r.url.endsWith('original.mp4') &&
              !r.url.contains('/original/'),
        ) ?? searchList.firstOrNull;
        if (mp4Res != null && mp4Res.url.isNotEmpty) {
          targetUrl = mp4Res.url;
        }
      }

      if (targetUrl == null || targetUrl.isEmpty) {
        if (video.videoUrl.isNotEmpty) {
          targetUrl = video.videoUrl;
        } else if (video.originalUrl.isNotEmpty) {
          targetUrl = video.originalUrl;
        } else if (video.hlsUrl.isNotEmpty) {
          targetUrl = video.hlsUrl;
        }
      }

      if (targetUrl == null || targetUrl.isEmpty) return;

      // Fast 0ms conversion for gs:// or storage paths
      targetUrl = StorageUtils.getFastDownloadUrl(targetUrl);
      if (targetUrl.isEmpty) return;

      debugPrint(
        '[VideoPlaybackHandoff] 🚀 Pre-warming Google CDN stream for video: ${video.id}',
      );
      final isHlsOrCmaf =
          targetUrl.contains('.m3u8') || targetUrl.contains('/cmaf/');
      final networkHeaders = await StorageUtils.getMediaHeaders(
        isHlsOrCmaf: isHlsOrCmaf,
      );

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(targetUrl),
        httpHeaders: networkHeaders,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: true,
        ),
      );

      registerActiveController(video.id, controller);

      // Kick off initialization asynchronously in background
      final initFuture = controller.initialize();
      _inFlightInit[video.id] = initFuture;

      initFuture.then((_) {
        _inFlightInit.remove(video.id);
        debugPrint(
          '[VideoPlaybackHandoff] ✅ Pre-warmed Google CDN player initialized for: ${video.id}',
        );
      }).catchError((dynamic e, StackTrace s) {
        _inFlightInit.remove(video.id);
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
    } finally {
      _inFlightPrewarm.remove(video.id);
    }
  }

  static final Map<String, Duration> _activePositions = <String, Duration>{};
  static final Map<String, Future<void>> _inFlightInit = <String, Future<void>>{};

  /// Access in-flight initialization Future for pre-warmed controllers
  /// to eliminate race conditions and avoid double initialize() calls.
  static Future<void>? getInitializationFuture(String videoId) =>
      _inFlightInit[videoId];

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

  static final Map<String, DateTime> _claimedHandoffs = <String, DateTime>{};

  /// Check if a video controller is currently waiting in handoff or was recently
  /// claimed into an active watch screen session (within 15s) so that automated
  /// background processes (like initial ABR ladder switches) do not abruptly tear down
  /// the active playing stream.
  static bool isHandoffActiveOrRecent(String videoId) {
    if (kIsWeb) return false;
    if (isActive(videoId)) return true;
    final claimedAt = _claimedHandoffs[videoId];
    if (claimedAt != null) {
      if (DateTime.now().difference(claimedAt).inSeconds < 15) {
        return true;
      } else {
        _claimedHandoffs.remove(videoId);
      }
    }
    return false;
  }

  /// Retrieve the active controller for a video ID, clearing it from the registry.
  /// This transfers ownership of the controller to the caller.
  static VideoPlayerController? retrieveController(String videoId) {
    if (kIsWeb) return null;

    if (_activeVideoId == videoId && _activeController != null) {
      final controller = _activeController!;
      _activeController = null;
      _activeVideoId = null;
      _claimedHandoffs[videoId] = DateTime.now();

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
    _inFlightPrewarm.remove(videoId);
    _activePositions.remove(videoId);
    _claimedHandoffs.remove(videoId);
    _inFlightInit.remove(videoId);
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
