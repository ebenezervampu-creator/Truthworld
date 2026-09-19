import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_playback_handoff.dart';
import 'package:truthworld/features/video/presentation/views/player/tower_custom_player.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Video player stage with YouTube-style ambient glow, responsive constraints, and Chewie/Tower player mounting.
class VideoPlayerStage extends StatelessWidget {
  const VideoPlayerStage({
    required this.controller,
    this.videoTag,
    super.key,
  });

  final VideoController controller;
  final String? videoTag;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Obx(() {
        final ratio = controller.video.isShort
            ? 9 / 16
            : controller.vpcAspectRatio;

        return LayoutBuilder(
          builder: (context, constraints) {
            final mediaQuery = MediaQuery.of(context);
            final screenHeight = mediaQuery.size.height;
            final maxWidth = constraints.maxWidth;

            final height = maxWidth / ratio;
            final isDesktop = mediaQuery.size.width > 1050;
            final maxHeight = isDesktop
                ? screenHeight * 0.65
                : screenHeight * 0.55;

            var finalHeight = height;
            var finalRatio = ratio;

            if (height > maxHeight) {
              finalHeight = maxHeight;
              finalRatio = maxWidth / finalHeight;
            }

            final finalWidth = finalHeight * finalRatio;

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // YouTube Ambient Mode Glow
                if (controller.video.thumbnailUrl.isNotEmpty)
                  Positioned(
                    width: finalWidth * 1.3,
                    height: finalHeight,
                    child: IgnorePointer(
                      child: Obx(() {
                        if (controller.isFullScreen.value) {
                          return const SizedBox.shrink();
                        }
                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 1000),
                          opacity: controller.showThumbnail.value ? 0.08 : 0.18,
                          child: ClipRect(
                            child: ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(
                                sigmaX: 65,
                                sigmaY: 65,
                                tileMode: TileMode.decal,
                              ),
                              child: CachedNetworkImage(
                                imageUrl: controller.video.thumbnailUrl
                                    .replaceAll(' ', '%20'),
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                // Video Player Container
                AspectRatio(
                  aspectRatio: finalRatio.isFinite && finalRatio > 0
                      ? finalRatio
                      : 16 / 9,
                  child: ColoredBox(
                    color: Colors.black,
                    child: ClipRect(
                      child: VideoPlayerView(
                        controller: controller,
                        videoTag: videoTag,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }),
    );
  }
}

/// Main video player view with overlays for clip mode, watermark, and loading thumbnails.
class VideoPlayerView extends StatelessWidget {
  const VideoPlayerView({
    required this.controller,
    this.videoTag,
    super.key,
  });

  final VideoController controller;
  final String? videoTag;

  @override
  Widget build(BuildContext context) {
    final String heroTag =
        Get.arguments?['heroTag'] ?? 'video_${controller.video.id}';
    final thumbnailWidget = ColoredBox(
      color: Colors.black,
      child: Center(
        child: controller.video.thumbnailUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: controller.video.thumbnailUrl.replaceAll(' ', '%20'),
                fit: BoxFit.contain,
                placeholder: (context, url) => const SizedBox.shrink(),
                errorWidget: (context, url, error) => const SizedBox.shrink(),
              )
            : Icon(
                Icons.video_library_outlined,
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                size: 48,
              ),
      ),
    );

    return Hero(
      tag: heroTag,
      child: Obx(() {
        final isLoading = controller.isLoading;
        final isError = controller.videoError.value;
        final vpc = controller.videoPlayerController;

        if (isError) {
          return VideoPlayerErrorView(
            controller: controller,
            thumbnailWidget: thumbnailWidget,
          );
        }

        final isHandoff = VideoPlaybackHandoff.isActive(controller.video.id) ||
            (Get.arguments is Map && Get.arguments['isFromMiniplayer'] == true);

        if (vpc == null ||
            (isLoading &&
                !controller.isSwitchingResolution.value &&
                !isHandoff)) {
          return thumbnailWidget;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            TowerCustomPlayer(
              videoPlayerController: vpc,
              tag: controller.video.id,
            ),

            // Granular Thumbnail / Loading Overlay
            Obx(() {
              final activeVpc = controller.videoPlayerController;
              final isVideoReady =
                  activeVpc != null && activeVpc.value.isInitialized;
              final isPlaying = activeVpc != null && activeVpc.value.isPlaying;
              final isAutoSwitching = controller.isAutoSwitching.value;
              final isAdShowing = Get.isRegistered<TowerPlayerController>(
                      tag: controller.video.id) &&
                  Get.find<TowerPlayerController>(tag: controller.video.id)
                      .isShowingAd
                      .value;
              final isHandoffActive =
                  VideoPlaybackHandoff.isActive(controller.video.id) ||
                      (Get.arguments is Map &&
                          Get.arguments['isFromMiniplayer'] == true);
              final loading = controller.isLoading &&
                  !controller.isSwitchingResolution.value;

              final showThumbnailOverlay = !isHandoffActive &&
                  !isAutoSwitching &&
                  !controller.isAudioOnly.value &&
                  !isAdShowing &&
                  (loading ||
                      !isVideoReady ||
                      (!isPlaying && controller.showThumbnail.value));

              if (!showThumbnailOverlay) return const SizedBox.shrink();
              return Positioned.fill(child: thumbnailWidget);
            }),

            // Granular Clip Mode Overlay
            Obx(() {
              final clip = controller.activeClip.value;
              if (clip == null) return const SizedBox.shrink();
              return Positioned(
                top: 40,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.brand.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.content_cut_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'CLIP: ${clip.title}',
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  color: Colors.black,
                                  size: 10,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'TRUTHWORLD WATERMARK',
                                  style: GoogleFonts.roboto(
                                    color: Colors.black,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: controller.clearActiveClip,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'WATCH FULL',
                          style: GoogleFonts.roboto(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Granular Persistent Watermark on Clip Playback
            Obx(() {
              if (controller.activeClip.value == null) {
                return const SizedBox.shrink();
              }
              return Positioned(
                bottom: 60,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.water_drop_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Truthworld Watermark',
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      }),
    );
  }
}

/// Fallback error view when a video cannot be initialized or loaded.
class VideoPlayerErrorView extends StatelessWidget {
  const VideoPlayerErrorView({
    required this.controller,
    required this.thumbnailWidget,
    super.key,
  });

  final VideoController controller;
  final Widget thumbnailWidget;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        thumbnailWidget,
        ColoredBox(
          color: Colors.black54,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      controller.errorMessage.isNotEmpty
                          ? controller.errorMessage
                          : 'This video is currently unavailable',
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: controller.initializeVideoPlayer,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                      label: const Text(
                        'Retry',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.bgSurface,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: const BorderSide(
                            color: AppColors.bgDivider,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
