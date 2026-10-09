import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/components/ui/video_card/video_card_controller.dart';
import 'package:truthworld/components/ui/video_card/video_card_thumbnail_overlays.dart';
import 'package:truthworld/core/widgets/mobile_friendly_video_player.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// 16:9 thumbnail view for VideoCard hosting player preview, poster, and interactive overlays.
class VideoCardThumbnail extends StatelessWidget {
  const VideoCardThumbnail({
    required this.video,
    required this.controller,
    super.key,
    this.borderRadius,
  });

  final Video video;
  final VideoCardController controller;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBorderRadius =
        borderRadius ?? const BorderRadius.vertical(top: Radius.circular(16));

    final isMobileDevice = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final isDesktop = !isMobileDevice && MediaQuery.sizeOf(context).width >= 1000;
    final cacheDimension = isDesktop ? 1080 : 720;

    return Hero(
      tag: '${controller.heroPrefix}_${video.id}',
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Obx(() {
            final isInitialized = controller.isControllerInitialized.value;
            final player = controller.activePlayer;
            final hovered = controller.isHovered;

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => controller.handleTap(context),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isInitialized && player != null)
                    IgnorePointer(
                      child: ClipRect(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: player.value.size.width > 0
                                ? player.value.size.width
                                : 160,
                            height: player.value.size.height > 0
                                ? player.value.size.height
                                : 90,
                            child: MobileFriendlyVideoPlayer(
                              controller: player,
                              looping: true,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: cacheDimension,
                      maxWidthDiskCache: cacheDimension,
                      placeholder: (context, url) =>
                          _buildThumbnailShimmer(theme),
                      errorWidget: (context, url, error) =>
                          _buildThumbnailError(theme),
                    ),
                  if (!isInitialized)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppColors.bgPage.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                  if ((video.isFactChecked || video.hasAiCredibility) &&
                      video.canPublicViewFactCheck)
                    const VideoCardFactCheckBadge(),
                  if (video.isPrivate)
                    const VideoCardPrivateBadge(),
                  if (!isInitialized)
                    VideoCardDurationBadge(duration: video.duration),
                  if (isInitialized)
                    VideoCardAudioToggle(controller: controller),
                  if (hovered)
                    VideoCardHoverActions(video: video),
                  VideoCardWatchProgressBar(videoId: video.id),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildThumbnailShimmer(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.3,
      ),
      highlightColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.1,
      ),
      child: Container(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Widget _buildThumbnailError(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.3),
            theme.colorScheme.secondary.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          size: 48,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
