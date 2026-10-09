import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

/// Configures and manages the lifecycle of the underlying ChewieController.
class TowerPlayerChewieConfigurator {
  /// Safely dispose of an existing ChewieController
  static void safeDispose(
    ChewieController? controller, {
    VideoPlayerController? currentVpc,
  }) {
    if (controller == null) return;
    try {
      if (currentVpc != null && controller.videoPlayerController != currentVpc) {
        controller.pause();
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TowerPlayerChewieConfigurator.pause');
    }
    try {
      controller.dispose();
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'TowerPlayerChewieConfigurator.dispose');
    }
  }

  /// Create and configure a new production ChewieController
  static ChewieController create({
    required VideoPlayerController videoPlayerController,
    required bool isLooping,
  }) {
    return ChewieController(
      videoPlayerController: videoPlayerController,
      looping: isLooping,
      showControls: false,
      allowedScreenSleep: false,
      placeholder: const ColoredBox(
        color: AppColors.bgPage,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        ),
      ),
      errorBuilder: (context, errorMessage) {
        final errLower = errorMessage.toLowerCase();
        if (errLower.contains('removed from the document') ||
            errLower.contains('play() request was interrupted') ||
            errLower.contains('aborterror') ||
            errLower.contains('notallowederror')) {
          return const SizedBox.shrink();
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.brand,
        handleColor: AppColors.brand,
        bufferedColor: AppColors.brand.withValues(alpha: 0.33),
        backgroundColor: AppColors.brand.withValues(alpha: 0.2),
      ),
      cupertinoProgressColors: ChewieProgressColors(
        playedColor: AppColors.brand,
        handleColor: AppColors.brand,
        bufferedColor: AppColors.brand.withValues(alpha: 0.33),
        backgroundColor: AppColors.brand.withValues(alpha: 0.2),
      ),
      deviceOrientationsOnEnterFullScreen:
          videoPlayerController.value.aspectRatio > 1.0
              ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
              : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
      deviceOrientationsAfterFullScreen: const [DeviceOrientation.portraitUp],
      systemOverlaysOnEnterFullScreen: const [],
    );
  }
}
