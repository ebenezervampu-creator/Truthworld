import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/video/presentation/controllers/video_loader_controller.dart';

export 'package:truthworld/features/video/presentation/controllers/video_loader_controller.dart';

// Constants for consistent styling
const double kSmallPadding = 8;
const double kLargePadding = 24;

class VideoLoaderScreen extends StatelessWidget {
  const VideoLoaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VideoLoaderController>(
      init: VideoLoaderController(),
      builder: (controller) {
        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: controller.animation,
                  child: const AppLogo(
                    size: 80,
                    borderRadius: 20,
                  ),
                ),
                const SizedBox(height: kLargePadding),
                Text(
                  'Loading Video...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: kSmallPadding),
                Text(
                  'Please wait a moment while we fetch your content.',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
