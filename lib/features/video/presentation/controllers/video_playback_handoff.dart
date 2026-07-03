import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// A global handoff registry to transfer an active [VideoPlayerController]
/// from a video card preview to the watch screen (`VideoScreen`).
///
/// This enables zero-latency under-a-second playback transitions by avoiding
/// re-initialization and re-buffering.
class VideoPlaybackHandoff {
  static VideoPlayerController? _activeController;
  static String? _activeVideoId;

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
