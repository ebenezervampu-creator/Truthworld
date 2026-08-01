import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Utility helpers for miniplayer navigation and state management.
///
/// These are convenience wrappers around `MiniplayerController.to`
/// for use from places that don't hold a direct controller reference.
///
/// Implements YouTube-style miniplayer with professional exception handling.
class MiniplayerNavigationHelper {
  MiniplayerNavigationHelper._();

  static const String _tag = 'MiniplayerNavHelper';

  /// Navigate to video screen directly without showing miniplayer first.
  /// The miniplayer will appear when navigating AWAY from the video screen.
  ///
  /// Exception handling ensures the app continues even if miniplayer fails.
  static Future<void> navigateToVideoScreen({
    required Video video,
    Map<String, dynamic>? routeArguments,
  }) async {
    try {
      if (video.id.isEmpty || video.videoUrl.isEmpty) {
        logger.warning(
          'Invalid video data: id=${video.id}, url=${video.videoUrl}',
          tag: _tag,
        );
        // Continue with navigation even if video is invalid
      }

      // Navigate directly to video screen without eagerly instantiating miniplayer
      await Get.toNamed(
        '/watch?v=${video.id}',
        arguments: routeArguments ?? {'video': video},
        preventDuplicates: false,
      );
    } catch (e, stackTrace) {
      logger.error(
        'Navigation to video screen failed',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      // Show user-friendly error message
      _showNavigationError();
    }
  }

  /// Show miniplayer with video when navigating away from video screen.
  /// This is called when user leaves the video screen to go to home/channel.
  ///
  /// [currentPosition] - resume the video from this position
  /// [autoShow] - whether to automatically expand/show the miniplayer
  static Future<void> showMiniplayerWithCurrentVideo({
    required Video video,
    Duration? currentPosition,
    String? overrideUrl,
    bool autoShow = true,
  }) async {
    try {
      final ctrl = MiniplayerController.to;

      // Show video in miniplayer
      await ctrl.showWithVideo(
        video,
        resumeFromPosition: currentPosition,
        overrideUrl: overrideUrl,
      );

      if (autoShow) {
        // Collapse to show the miniplayer (not expanded)
        ctrl.collapse();
      }

      logger.info(
        'Miniplayer shown for video: ${video.id}, resumed at: $currentPosition',
        tag: _tag,
      );
    } catch (e, stackTrace) {
      logger.error(
        'Failed to show miniplayer with current video',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      // Non-critical error - user can still browse
    }
  }

  /// Dismiss miniplayer and open the currently-loaded video in full screen.
  static void expandToFullScreen() {
    try {
      MiniplayerController.to.openFullScreen();
      logger.info('Expanded miniplayer to fullscreen', tag: _tag);
    } catch (e, stackTrace) {
      logger.error(
        'Failed to expand miniplayer to fullscreen',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      _showOperationError('Could not open video');
    }
  }

  /// Dismiss the miniplayer entirely.
  static void dismiss() {
    try {
      MiniplayerController.to.dismiss();
      logger.info('Miniplayer dismissed', tag: _tag);
    } catch (e, stackTrace) {
      logger.error(
        'Failed to dismiss miniplayer',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      // Non-critical error
    }
  }

  /// Whether the miniplayer is currently visible.
  static bool get isVisible {
    try {
      return MiniplayerController.to.isVisible;
    } catch (e) {
      logger.error(
        'Error checking miniplayer visibility',
        error: e,
        tag: _tag,
      );
      return false;
    }
  }

  /// Get a responsive collapsed width for the given screen width.
  static double collapsedWidth(double screenWidth) {
    try {
      const fraction = 0.30;
      const minW = 320.0;
      const maxW = 480.0;
      return (screenWidth * fraction).clamp(minW, maxW);
    } catch (e) {
      logger.error('Error calculating miniplayer width', error: e, tag: _tag);
      return 380; // Safe default
    }
  }

  /// Get the current playback position in the miniplayer
  static Duration? getCurrentPosition() {
    try {
      return MiniplayerController.to.currentPosition.value;
    } catch (e) {
      logger.error('Error getting current position', error: e, tag: _tag);
      return null;
    }
  }

  /// Navigate away from video screen while showing miniplayer with smooth transition.
  ///
  /// This is the recommended way to navigate from video screen to other screens.
  ///
  /// [video] - The video to show in miniplayer
  /// [currentPosition] - Current playback position to resume from
  /// [targetRoute] - Where to navigate (e.g., '/home', '/channel')
  /// [arguments] - Arguments to pass to the target route
  ///
  /// Example usage:
  /// ```dart
  /// await MiniplayerNavigationHelper.navigateAwayWithMiniplayer(
  ///   video: controller.video,
  ///   currentPosition: controller.videoPlayerController?.value.position,
  ///   targetRoute: '/home',
  /// );
  /// ```
  static Future<void> navigateAwayWithMiniplayer({
    required Video video,
    required String targetRoute,
    Duration? currentPosition,
    String? overrideUrl,
    Map<String, dynamic>? arguments,
  }) async {
    try {
      // Step 2: Show video in miniplayer (asynchronously, but don't wait)
      final miniplayerCtrl = MiniplayerController.to;
      final showMiniplayer = miniplayerCtrl.showWithVideo(
        video,
        resumeFromPosition: currentPosition,
        overrideUrl: overrideUrl,
      );

      // Step 3: Navigate immediately (don't wait for miniplayer to load)
      // This creates the smooth UX where navigation feels instant
      unawaited(Get.toNamed(targetRoute, arguments: arguments));

      // Step 4: Wait for miniplayer to finish loading in background
      await showMiniplayer;

      // Step 5: Auto-collapse miniplayer to bottom bar
      if (miniplayerCtrl.mode.value != MiniplayerMode.dismissed) {
        miniplayerCtrl.collapse();
      }

      logger.info(
        'Navigation away from video with miniplayer: $targetRoute',
        tag: _tag,
      );
    } catch (e, stackTrace) {
      logger.error(
        'Error navigating away with miniplayer',
        error: e,
        stackTrace: stackTrace,
        tag: _tag,
      );
      // Still complete the navigation even if miniplayer fails
      try {
        await Get.toNamed(targetRoute, arguments: arguments);
      } catch (navError) {
        logger.error(
          'Navigation failed: $navError',
          error: navError,
          tag: _tag,
        );
      }
    }
  }

  /// Get the currently loaded video info
  /// Returns null if no video is loaded or miniplayer is not registered
  static MiniplayerVideoInfo? getCurrentVideoInfo() {
    try {
      return MiniplayerController.to.videoInfo.value;
    } catch (e) {
      logger.error('Error getting current video info', error: e, tag: _tag);
      return null;
    }
  }

  static void _showNavigationError() {
    try {
      Get.snackbar(
        'Navigation Error',
        'Could not open video. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error.withValues(alpha: 0.8),
        colorText: AppColors.textPrimary,
        borderRadius: 8,
        margin: const EdgeInsets.all(12),
      );
    } catch (e) {
      logger.error('Failed to show snackbar', error: e, tag: _tag);
    }
  }

  static void _showOperationError(String message) {
    try {
      Get.snackbar(
        'Error',
        message,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.warning.withValues(alpha: 0.8),
        colorText: AppColors.textPrimary,
        borderRadius: 8,
        margin: const EdgeInsets.all(12),
      );
    } catch (e) {
      logger.error('Failed to show error snackbar', error: e, tag: _tag);
    }
  }
}

/// Animation factory helpers for miniplayer transitions.
class MiniplayerAnimations {
  MiniplayerAnimations._();

  static Animation<Offset> slideAnimation(
    AnimationController controller, {
    Offset begin = const Offset(0.5, 0.5),
    Offset end = Offset.zero,
  }) {
    return Tween<Offset>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
    );
  }

  static Animation<double> scaleAnimation(AnimationController controller) {
    return Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
    );
  }

  static Animation<double> fadeAnimation(AnimationController controller) {
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInCubic),
    );
  }
}

/// Performance helpers for miniplayer.
class MiniplayerPerformanceUtils {
  MiniplayerPerformanceUtils._();

  /// Whether the platform can probably run the miniplayer smoothly.
  static bool canRunMiniplayer(TargetPlatform platform) => true;

  /// Recommended UI update frequency in ms for a target FPS.
  static int getUpdateFrequencyMs({int targetFps = 60}) =>
      1000 ~/ targetFps;
}
