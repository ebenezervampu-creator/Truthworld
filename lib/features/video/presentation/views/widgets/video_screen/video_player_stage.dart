import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/channel/presentation/views/channel/widgets/channel_membership_join_sheet.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
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
        final isShort = controller.video.isShort;
        final double validRatio;
        if (controller.isVpcInitialized &&
            controller.vpcAspectRatio.isFinite &&
            controller.vpcAspectRatio > 0) {
          validRatio = controller.vpcAspectRatio;
        } else if (isShort) {
          validRatio = 9 / 16;
        } else {
          validRatio = 16 / 9;
        }

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
                : (screenHeight * 0.65).clamp(200.0, upperLimit);

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
      child: controller.video.thumbnailUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: controller.video.thumbnailUrl.replaceAll(' ', '%20'),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              memCacheWidth: kIsWeb ? null : 1280,
              maxWidthDiskCache: kIsWeb ? null : 1280,
              filterQuality: FilterQuality.medium,
              placeholder: (context, url) => const SizedBox.shrink(),
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            )
          : Center(
              child: Icon(
                Icons.video_library_outlined,
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                size: 48,
              ),
            ),
    );

    return Hero(
      tag: heroTag,
      flightShuttleBuilder: (
        flightContext,
        animation,
        flightDirection,
        fromHeroContext,
        toHeroContext,
      ) {
        return thumbnailWidget;
      },
      child: Obx(() {
        if (controller.isClosed || controller.isMiniplayerHandoffDone.value) {
          return thumbnailWidget;
        }

        final isError = controller.videoError.value;
        final vpc = controller.videoPlayerController;
        final vid = controller.video;
        final isOwner = VideoVisibilityPolicy.isOwner(vid);

        // 1. Private Gate Check (Only channel owner can watch private videos)
        if (vid.isPrivate && !isOwner) {
          return VideoPlayerPrivateGateView(
            controller: controller,
            thumbnailWidget: thumbnailWidget,
          );
        }

        // 2. Members Only Gate Check (Members and channel owner can watch)
        final isMember = controller.isChannelMember;
        if (vid.isMembersOnly && !isOwner && !isMember) {
          return VideoPlayerMembersOnlyGateView(
            controller: controller,
            thumbnailWidget: thumbnailWidget,
          );
        }

        // 3. Subscribers Only Gate Check (Subscribers and channel owner can watch)
        final effectiveChannelId = vid.channelId.isNotEmpty
            ? vid.channelId
            : vid.ownerId;
        final isSubscribed = controller.isSubscribed.value ||
            controller.channelController.subController.isSubscribed.value ||
            (effectiveChannelId.isNotEmpty &&
                controller.channelController.subController
                    .isSubscribedTo(effectiveChannelId)
                    .value);
        if (vid.isSubscribersOnly && !isOwner && !isSubscribed) {
          return VideoPlayerSubscribersOnlyGateView(
            controller: controller,
            thumbnailWidget: thumbnailWidget,
          );
        }

        if (isError) {
          return VideoPlayerErrorView(
            controller: controller,
            thumbnailWidget: thumbnailWidget,
          );
        }

        if (vpc == null) {
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
              final tpc = Get.isRegistered<TowerPlayerController>(
                      tag: controller.video.id)
                  ? Get.find<TowerPlayerController>(tag: controller.video.id)
                  : null;
              final isReady = (tpc != null && tpc.isInitialized.value) ||
                  controller.isPlayerInitialized.value ||
                  (activeVpc != null && activeVpc.value.isInitialized);
              final isAutoSwitching = controller.isAutoSwitching.value;
              final isAdShowing = tpc?.isShowingAd.value ?? false;

              final showThumbnailOverlay = !isAutoSwitching &&
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
                            style: const TextStyle(
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
                        child: const Text(
                          'WATCH FULL',
                          style: TextStyle(
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Truthworld',
                        style: TextStyle(
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

/// YouTube-style gated view for Members-Only videos.
class VideoPlayerMembersOnlyGateView extends StatelessWidget {
  const VideoPlayerMembersOnlyGateView({
    required this.controller,
    required this.thumbnailWidget,
    super.key,
  });

  final VideoController controller;
  final Widget thumbnailWidget;

  @override
  Widget build(BuildContext context) {
    final video = controller.video;

    return Stack(
      fit: StackFit.expand,
      children: [
        thumbnailWidget,
        ColoredBox(
          color: Colors.black.withValues(alpha: 0.85),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(
                    photoUrl: video.channelAvatarUrl.isNotEmpty
                        ? video.channelAvatarUrl
                        : null,
                    displayName: video.channelName,
                    radius: 26,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    video.channelName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF029C5D).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00E676).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.stars_rounded,
                          color: Color(0xFF00E676),
                          size: 16,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Members-only content',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Text(
                      'Join this channel to get access to members-only videos and other exclusive perks.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    key: const ValueKey('join_channel_membership_gate_button'),
                    onPressed: () {
                      final effectiveChannelId = video.channelId.isNotEmpty
                          ? video.channelId
                          : video.ownerId;
                      ChannelMembershipJoinSheet.show(
                        context,
                        channelId: effectiveChannelId,
                        channel:
                            controller.channelController.selectedChannel.value,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.stars_rounded,
                          color: Colors.black,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Join',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// YouTube-style gated view for Subscribers-Only videos.
class VideoPlayerSubscribersOnlyGateView extends StatelessWidget {
  const VideoPlayerSubscribersOnlyGateView({
    required this.controller,
    required this.thumbnailWidget,
    super.key,
  });

  final VideoController controller;
  final Widget thumbnailWidget;

  @override
  Widget build(BuildContext context) {
    final video = controller.video;

    return Stack(
      fit: StackFit.expand,
      children: [
        thumbnailWidget,
        ColoredBox(
          color: Colors.black.withValues(alpha: 0.85),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(
                    photoUrl: video.channelAvatarUrl.isNotEmpty
                        ? video.channelAvatarUrl
                        : null,
                    displayName: video.channelName,
                    radius: 26,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    video.channelName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.subscriptions_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Subscribers-only content',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Text(
                      'Subscribe to this channel to watch this video and get access to exclusive content.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    key: const ValueKey('subscribe_channel_gate_button'),
                    onPressed: () {
                      final effectiveChannelId = video.channelId.isNotEmpty
                          ? video.channelId
                          : video.ownerId;
                      if (effectiveChannelId.isNotEmpty) {
                        controller.channelController.subController
                            .toggleSubscription(effectiveChannelId);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.subscriptions_rounded,
                          color: Colors.black,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Subscribe',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// YouTube-style locked view for Private videos when viewed by non-owners.
class VideoPlayerPrivateGateView extends StatelessWidget {
  const VideoPlayerPrivateGateView({
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
          color: Colors.black.withValues(alpha: 0.88),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This video is private',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      'Only the channel owner can view this video.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
