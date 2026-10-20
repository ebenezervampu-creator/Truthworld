import 'dart:math' as math;
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

/// Video player stage with ambient glow, responsive constraints, and Chewie/Tower player mounting.
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

            // Align desktop breakpoint with TWBreakpoints.desktop / widescreen 2-column layout (>= 900)
            final isDesktop = mediaQuery.size.width >= 900;
            // On desktop, the left column width is already constrained, so let the player comfortably
            // fill the column width up to 80% screen height (at least 480px, up to screenHeight - 80px)
            // so standard 16:9 desktop videos fit full column width without shrinking.
            final upperLimit = (screenHeight - 80.0).clamp(240.0, 1600.0);
            final lowerLimit = math.min(480.0, upperLimit);
            final maxHeight = isDesktop
                ? (screenHeight * 0.80).clamp(lowerLimit, upperLimit)
                : (screenHeight * 0.55).clamp(200.0, upperLimit);

            final validRatio = ratio.isFinite && ratio > 0 ? ratio : 16 / 9;
            final height = maxWidth / validRatio;
            final finalHeight = height > maxHeight ? maxHeight : height;
            final finalWidth = (finalHeight * validRatio).clamp(0.0, maxWidth);

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Ambient Mode Glow - softly illuminates above and to the sides of the player,
                // smoothly dissolving to transparent before reaching the bottom edge to ensure
                // zero hard borders, color bleeding, or seam artifacts below the player controls.
                if (controller.video.thumbnailUrl.isNotEmpty)
                  Positioned(
                    top: -24,
                    bottom: 0,
                    width: finalWidth + 48,
                    child: IgnorePointer(
                      child: Obx(() {
                        if (controller.isFullScreen.value) {
                          return const SizedBox.shrink();
                        }
                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 1000),
                          opacity: controller.showThumbnail.value ? 0.08 : 0.18,
                          child: ShaderMask(
                            shaderCallback: (bounds) {
                              return const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0.0, 0.65, 0.95],
                                colors: [
                                  Colors.white,
                                  Colors.white,
                                  Colors.transparent,
                                ],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.dstIn,
                            child: ImageFiltered(
                              imageFilter: ui.ImageFilter.blur(
                                sigmaX: 55,
                                sigmaY: 55,
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
                SizedBox(
                  width: finalWidth,
                  height: finalHeight,
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

        final isVideoReady = vpc != null && vpc.value.isInitialized;

        if (vpc == null || (!isVideoReady && isLoading && !isHandoff)) {
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
              final isReady =
                  activeVpc != null && activeVpc.value.isInitialized;
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

              final showThumbnailOverlay = !isHandoffActive &&
                  !isAutoSwitching &&
                  !controller.isAudioOnly.value &&
                  !isAdShowing &&
                  !isReady;

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
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Truthworld',
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
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
                      style: const TextStyle(
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
