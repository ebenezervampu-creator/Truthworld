import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/components/ui/video_card/video_card_avatar.dart';
import 'package:truthworld/components/ui/video_card/video_card_formatters.dart';
import 'package:truthworld/components/ui/video_card/video_card_thumbnail_overlays.dart';
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/fullscreen_more_videos_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';

/// Fullscreen recommended videos overlay ("More videos") displayed during fullscreen playback
/// when user scrolls up, taps the More Videos button, or when the video is coming to an end.
/// Designed responsively for all devices (mobile, tablet, desktop) following strict GetX architecture.
class FullscreenMoreVideosOverlay extends StatelessWidget {
  const FullscreenMoreVideosOverlay({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<FullscreenMoreVideosController>(
      tag: ctrl.tag,
      init: FullscreenMoreVideosController(playerCtrl: ctrl),
      builder: (moreCtrl) => _FullscreenMoreVideosOverlayContent(
        ctrl: ctrl,
        moreCtrl: moreCtrl,
      ),
    );
  }
}

class _FullscreenMoreVideosOverlayContent extends StatelessWidget {
  const _FullscreenMoreVideosOverlayContent({
    required this.ctrl,
    required this.moreCtrl,
  });

  final TowerPlayerController ctrl;
  final FullscreenMoreVideosController moreCtrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!ctrl.showMoreVideos.value || !ctrl.isFullScreen.value) {
        return const SizedBox.shrink();
      }

      // Extract recommended videos from VideoController
      var vc = ctrl.videoController;
      if (vc == null && ctrl.tag != null) {
        try {
          if (Get.isRegistered<VideoController>(tag: ctrl.tag)) {
            vc = Get.find<VideoController>(tag: ctrl.tag);
          }
        } catch (e, s) {
          ErrorHandler.log(
            e,
            stackTrace: s,
            tag: 'FullscreenMoreVideosOverlay.findVideoController',
          );
        }
      }

      final rawVideos =
          vc?.filteredRecommendedVideos ?? vc?.recommendedVideos ?? [];
      final currentVideoId = vc?.video.id ?? ctrl.tag ?? '';
      final recommendations = rawVideos
          .where((v) => currentVideoId.isEmpty || v.id != currentVideoId)
          .toList();
      final isLoading = vc?.isLoadingRecommendations.value ?? false;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 200) {
            ctrl.closeMoreVideos();
          }
        },
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.85),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;
                final screenHeight = constraints.maxHeight;

                final isCompact = screenHeight < 450 || screenWidth < 600;
                final cardWidth = isCompact ? 260.0 : 320.0;
                final thumbnailHeight = cardWidth * 9 / 16;
                final infoHeight = isCompact ? 60.0 : 68.0;
                final cardHeight = thumbnailHeight + infoHeight;
                final carouselHeight = cardHeight + 16.0;

                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => moreCtrl.updateScrollButtons(),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header Bar ──────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 10.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'More videos',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Semantics(
                            label: 'Close recommended videos',
                            button: true,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              tooltip: 'Close',
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                              onPressed: ctrl.closeMoreVideos,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // ── Horizontal Cards Carousel ────────────────────────────
                    SizedBox(
                      height: carouselHeight,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Listener(
                            onPointerSignal: (pointerSignal) {
                              if (pointerSignal is PointerScrollEvent) {
                                final delta = pointerSignal.scrollDelta.dy != 0
                                    ? pointerSignal.scrollDelta.dy
                                    : pointerSignal.scrollDelta.dx;
                                moreCtrl.handlePointerScroll(delta);
                              }
                            },
                            child: _buildCarouselContent(
                              recommendations: recommendations,
                              isLoading: isLoading,
                              cardWidth: cardWidth,
                              thumbnailHeight: thumbnailHeight,
                              isCompact: isCompact,
                            ),
                          ),

                          // Desktop Left Scroll Arrow
                          if (!isCompact)
                            Obx(() {
                              if (!moreCtrl.canScrollLeft.value) {
                                return const SizedBox.shrink();
                              }
                              return Positioned(
                                left: 12,
                                child: _buildScrollButton(
                                  icon: Icons.chevron_left_rounded,
                                  onTap: () =>
                                      moreCtrl.scroll(-cardWidth * 1.5),
                                ),
                              );
                            }),

                          // Desktop Right Scroll Arrow
                          if (!isCompact)
                            Obx(() {
                              if (!moreCtrl.canScrollRight.value) {
                                return const SizedBox.shrink();
                              }
                              return Positioned(
                                right: 12,
                                child: _buildScrollButton(
                                  icon: Icons.chevron_right_rounded,
                                  onTap: () =>
                                      moreCtrl.scroll(cardWidth * 1.5),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
        ),
      );
    });
  }

  Widget _buildCarouselContent({
    required List<Video> recommendations,
    required bool isLoading,
    required double cardWidth,
    required double thumbnailHeight,
    required bool isCompact,
  }) {
    if (isLoading && recommendations.isEmpty) {
      return ListView.separated(
        controller: moreCtrl.scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, _) => _buildShimmerCard(cardWidth, thumbnailHeight),
      );
    }

    if (recommendations.isEmpty) {
      return const Center(
        child: Text(
          'No recommended videos available',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      controller: moreCtrl.scrollController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      itemCount: recommendations.length,
      separatorBuilder: (_, _) => const SizedBox(width: 14),
      itemBuilder: (context, index) {
        final video = recommendations[index];
        return _MoreVideoCard(
          video: video,
          cardWidth: cardWidth,
          thumbnailHeight: thumbnailHeight,
          isCompact: isCompact,
          moreCtrl: moreCtrl,
          onTap: () {
            ctrl.closeMoreVideos();
            ctrl.navigateToVideo(video);
          },
        );
      },
    );
  }

  Widget _buildScrollButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  Widget _buildShimmerCard(double cardWidth, double thumbnailHeight) {
    return SizedBox(
      width: cardWidth,
      child: Shimmer.fromColors(
        baseColor: const Color(0xFF1E1E22),
        highlightColor: const Color(0xFF2C2C34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: thumbnailHeight,
              width: cardWidth,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: cardWidth * 0.6,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual video card matching the YouTube/TruthWorld fullscreen "More videos" layout.
class _MoreVideoCard extends StatelessWidget {
  const _MoreVideoCard({
    required this.video,
    required this.cardWidth,
    required this.thumbnailHeight,
    required this.isCompact,
    required this.moreCtrl,
    required this.onTap,
  });

  final Video video;
  final double cardWidth;
  final double thumbnailHeight;
  final bool isCompact;
  final FullscreenMoreVideosController moreCtrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final channelName = video.channelName;
    final viewsStr = VideoCardFormatters.formatViews(video.views);
    final timeStr = VideoCardFormatters.formatTimestamp(video.uploadedAt);
    final subtitle = '$channelName  •  $viewsStr views  •  $timeStr';

    return MouseRegion(
      onEnter: (_) => moreCtrl.setCardHovered(video.id, true),
      onExit: (_) => moreCtrl.setCardHovered(video.id, false),
      child: Obx(() {
        final isHovered = moreCtrl.isCardHovered(video.id);

        return AnimatedScale(
          scale: isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: cardWidth,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                splashColor: Colors.white.withValues(alpha: 0.1),
                highlightColor: Colors.white.withValues(alpha: 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── 16:9 Thumbnail ─────────────────────────────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: cardWidth,
                        height: thumbnailHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (video.thumbnailUrl.isNotEmpty)
                              CachedNetworkImage(
                                imageUrl:
                                    video.thumbnailUrl.replaceAll(' ', '%20'),
                                fit: BoxFit.cover,
                                memCacheWidth: 640,
                                placeholder: (context, url) => const ColoredBox(
                                  color: Color(0xFF1B1B1F),
                                ),
                                errorWidget: (context, url, error) =>
                                    const ColoredBox(
                                  color: Color(0xFF1B1B1F),
                                  child: Icon(
                                    Icons.video_library_outlined,
                                    color: Colors.white38,
                                    size: 32,
                                  ),
                                ),
                              )
                            else
                              const ColoredBox(
                                color: Color(0xFF1B1B1F),
                                child: Icon(
                                  Icons.video_library_outlined,
                                  color: Colors.white38,
                                  size: 32,
                                ),
                              ),

                            // Duration Badge (bottom-right)
                            if (video.duration.isNotEmpty)
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    video.duration,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),

                            // Fact Checked Badge (top-left)
                            if ((video.isFactChecked || video.hasAiCredibility) &&
                                video.canPublicViewFactCheck)
                              const VideoCardFactCheckBadge(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Info Row (Avatar, Title, Metadata, 3-dots) ─────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        VideoCardAvatar(
                          imageUrl: video.channelAvatarUrl,
                          radius: isCompact ? 15 : 17,
                          placeholderText:
                              channelName.isEmpty ? '?' : channelName,
                        ),

                        const SizedBox(width: 10),

                        // Title & Metadata
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                video.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isCompact ? 12.5 : 13.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: isCompact ? 11 : 11.5,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Options 3-dots
                        IconButton(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white70,
                            size: 19,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Options',
                          onPressed: () =>
                              VideoOptionsSheet.show(context, video),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
