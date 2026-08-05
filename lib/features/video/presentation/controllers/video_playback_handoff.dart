import 'package:flutter/foundation.dart';
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
  static Future<void> prewarmVideo(Video video) async {
    if (video.id.isEmpty) return;

    // Skip if already pre-warming or active for this video
    if (_activeVideoId == video.id && _activeController != null) {
      return;
    }

    String? targetUrl;
    if (!kIsWeb && video.hlsUrl.isNotEmpty && !video.hlsUrl.startsWith('gs://')) {
      targetUrl = video.hlsUrl;
    } else if (video.originalUrl.isNotEmpty && !video.originalUrl.startsWith('gs://')) {
      targetUrl = video.originalUrl;
    } else if (video.hlsUrl.isNotEmpty && !video.hlsUrl.startsWith('gs://')) {
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
      }).catchError((dynamic e) {
        debugPrint('[VideoPlaybackHandoff] ⚠️ Pre-warm initialization error: $e');
      });
    } catch (e) {
      debugPrint('[VideoPlaybackHandoff] Error initiating pre-warm: $e');
    }
  }

  /// Register an active controller for a given video ID.
  static void registerActiveController(
    String videoId,
    VideoPlayerController controller,
  ) {
    debugPrint(
      '[VideoPlaybackHandoff] Registered controller for video: $videoId',
    );

    // Clean up any previously registered controller that was never claimed
    if (_activeController != null && _activeController != controller) {
      try {
        _activeController!.dispose();
      } catch (e) {
        debugPrint(
          '[VideoPlaybackHandoff] Error cleaning up old controller: $e',
        );
      }
    }

    _activeController = controller;
    _activeVideoId = videoId;
  }

  /// Retrieve the active controller for a video ID, clearing it from the registry.
  /// This transfers ownership of the controller to the caller.
  static VideoPlayerController? retrieveController(String videoId) {
    if (_activeVideoId == videoId && _activeController != null) {
      debugPrint(
        '[VideoPlaybackHandoff] Retrieved controller for video: $videoId (Handing over!)',
      );
      final controller = _activeController;
      _activeController = null;
      _activeVideoId = null;
      return controller;
    }
    return null;
  }

  /// Check if the active controller for a video ID is still in the handoff (not claimed yet).
  static bool isActive(String videoId) {
    return _activeVideoId == videoId && _activeController != null;
  }

  /// Clear/dispose the active controller for a video ID if it hasn't been claimed yet.
  static void clear(String videoId) {
    if (_activeVideoId == videoId && _activeController != null) {
      debugPrint(
        '[VideoPlaybackHandoff] Clearing/disposing controller for video: $videoId',
      );
      try {
        _activeController!.dispose();
      } catch (e) {
        debugPrint(
          '[VideoPlaybackHandoff] Error disposing controller during clear: $e',
        );
      }
      _activeController = null;
      _activeVideoId = null;
    }
  }
}
