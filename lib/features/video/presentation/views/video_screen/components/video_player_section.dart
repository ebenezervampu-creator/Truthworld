import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chewie/chewie.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/custom_play.dart';
import '../theme/video_screen_theme.dart';

/// Video player section with Chewie integration
/// Handles normal and fullscreen modes with proper disposal
class VideoPlayerSection extends StatelessWidget {
  final VideoController controller;

  const VideoPlayerSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // When fullscreen, show ONLY a black placeholder in the background.
    // This is CRITICAL for Web/Desktop to avoid rendering the video player twice,
    // which causes the "audio-only" or "black screen" bug in the fullscreen route.
    if (controller.isFullScreen.value) {
      return SliverToBoxAdapter(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(color: Colors.black),
        ),
      );
    }
    // Normal mode - show video with aspect ratio
    return SliverToBoxAdapter(
      child: RepaintBoundary(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: VideoScreenTheme.background,
            child: _buildVideoPlayer(),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Obx(() {
      final videoPlayerController = controller.videoPlayerController;
      final chewieController = controller.chewieController;

      if (videoPlayerController == null || chewieController == null) {
        return const Center(
          child: CircularProgressIndicator(
            color: VideoScreenTheme.primary,
            strokeWidth: 3,
          ),
        );
      }

      // Check if video is ready
      if (!videoPlayerController.value.isInitialized) {
        return const Center(
          child: CircularProgressIndicator(
            color: VideoScreenTheme.primary,
            strokeWidth: 3,
          ),
        );
      }

      return ClipRect(
        child: Chewie(
          controller: chewieController,
        ),
      );
    });
  }
}
