import 'package:get/get.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Thin service layer providing a clean public API for the miniplayer.
///
/// Responsibilities:
///  - Gate access behind a simple, testable interface
///  - Coordinate analytics / logging
///  - Provide lifecycle hooks (navigate-away, return-to-video)
///  - Handle errors gracefully with exceptions
///
/// Rule: This service never touches UI widgets directly.
class MiniplayerService extends GetxService {
  static const String serviceName = 'MiniplayerService';
  static const String _tag = 'MiniplayerService';

  // ── Dependencies ──
  MiniplayerController get _ctrl =>
      Get.find<MiniplayerController>(tag: 'miniplayer');

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Show miniplayer for the given [video].
  ///
  /// If [resumeFromPosition] is provided, playback will seek to that position
  /// after initialization (useful for seamless video-screen → miniplayer
  /// transitions).
  ///
  /// Throws [MiniplayerException] if operation fails critically.
  Future<void> showWithVideo(
    Video video, {
    Duration? resumeFromPosition,
    String? overrideUrl,
  }) async {
    try {
      if (video.id.isEmpty) {
        throw MiniplayerException('Invalid video: empty ID');
      }

      if (video.videoUrl.isEmpty && overrideUrl == null) {
        throw MiniplayerException('Invalid video: empty URL');
      }

      await _ctrl.showWithVideo(video, resumeFromPosition: resumeFromPosition, overrideUrl: overrideUrl);
      _logEvent('miniplayer_shown', {
        'video_id': video.id,
        'resume_position': resumeFromPosition?.inSeconds ?? 0,
      });
    } catch (e, stackTrace) {
      logger.error(
        'Failed to show miniplayer: $e',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      rethrow;
    }
  }

  /// Dismiss and clean up the miniplayer.
  void dismiss() {
    try {
      final videoId = _ctrl.videoInfo.value?.id;
      _ctrl.dismiss();
      _logEvent('miniplayer_dismissed', {'video_id': videoId});
    } catch (e, stackTrace) {
      logger.error(
        'Failed to dismiss miniplayer: $e',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      // Don't rethrow for dismiss - it's not critical
    }
  }

  /// Whether the miniplayer is currently visible.
  bool get isVisible {
    try {
      return _ctrl.isVisible;
    } catch (e) {
      logger.error('Error checking visibility: $e', error: e, tag: _tag);
      return false;
    }
  }

  /// The ID of the currently loaded video, or `null`.
  String? get currentVideoId {
    try {
      return _ctrl.videoInfo.value?.id;
    } catch (e) {
      logger.error('Error getting current video ID: $e', error: e, tag: _tag);
      return null;
    }
  }

  /// Get the current playback position.
  Duration? get currentPosition {
    try {
      return _ctrl.currentPosition.value;
    } catch (e) {
      logger.error('Error getting position: $e', error: e, tag: _tag);
      return null;
    }
  }

  /// Check if the miniplayer is in a healthy state.
  bool get isHealthy {
    try {
      return _ctrl.isHealthy;
    } catch (e) {
      logger.error('Error checking health: $e', error: e, tag: _tag);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE HOOKS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Called when the user navigates away from a video screen.
  ///
  /// If [shouldShow] is true and the config allows auto-show, the
  /// miniplayer will appear.
  Future<void> onNavigateAwayFromVideo({
    required Video video,
    Duration? currentPosition,
    String? overrideUrl,
    bool shouldShow = true,
  }) async {
    try {
      if (!shouldShow) {
        logger.info('Navigation away from video - not showing miniplayer', tag: _tag);
        return;
      }

      await showWithVideo(video, resumeFromPosition: currentPosition, overrideUrl: overrideUrl);
      logger.info(
        'Miniplayer shown on navigation from video',
        tag: _tag,
      );
    } catch (e, stackTrace) {
      logger.warning(
        'Failed to show miniplayer on navigation: $e',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      // Don't rethrow - continue with navigation anyway
    }
  }

  /// Called when the user re-enters the same video's full screen.
  ///
  /// Automatically dismisses the miniplayer if it's showing the same video.
  void onReturnToVideoScreen({required String videoId}) {
    try {
      if (currentVideoId == videoId) {
        dismiss();
        logger.info('Miniplayer dismissed on return to video', tag: _tag);
      }
    } catch (e, stackTrace) {
      logger.error(
        'Error on return to video: $e',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
    }
  }

  /// Attempt to recover from an error state.
  Future<void> recover() async {
    try {
      if (!_ctrl.isHealthy) {
        logger.warning('Miniplayer not healthy, attempting recovery', tag: _tag);
        await _ctrl.attemptRecovery();
        logger.info('Miniplayer recovery attempted', tag: _tag);
      }
    } catch (e, stackTrace) {
      logger.error(
        'Recovery failed: $e',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
    }
  }

  /// Clear any error state.
  void clearError() {
    try {
      _ctrl.clearError();
    } catch (e) {
      logger.error('Error clearing state: $e', error: e, tag: _tag);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ANALYTICS
  // ═══════════════════════════════════════════════════════════════════════════

  void _logEvent(String name, Map<String, dynamic> params) {
    try {
      // In production, forward to Firebase Analytics.
      logger.info('[$name] $params', tag: _tag);
    } catch (e) {
      logger.error('Error logging event: $e', error: e, tag: _tag);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CUSTOM EXCEPTION
// ═══════════════════════════════════════════════════════════════════════════

/// Custom exception for miniplayer errors.
class MiniplayerException implements Exception {

  MiniplayerException(
    this.message, {
    this.originalError,
    this.stackTrace,
  });
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  @override
  String toString() => 'MiniplayerException: $message';
}






