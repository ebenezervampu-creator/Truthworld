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

    // On Web, passing memCacheWidth/maxWidthDiskCache causes canvas downsampling and blurry rendering.
    // On Native mobile/desktop, decode and cache at 1280px (standard YouTube 720p HD specification)
    // so thumbnails remain razor-sharp on high-DPI retina mobile and desktop screens.
    final cacheDimension = kIsWeb ? null : 1280;

    return Hero(
      tag: '${controller.heroPrefix}_${video.id}',
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => controller.handleTap(context),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Static base thumbnail (isolated from hover rebuilds for maximum frame rate)
                CachedNetworkImage(
                  imageUrl: video.thumbnailUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: cacheDimension,
                  maxWidthDiskCache: cacheDimension,
                  filterQuality: FilterQuality.medium,
                  placeholder: (context, url) =>
                      _buildThumbnailShimmer(theme),
                  errorWidget: (context, url, error) =>
                      _buildThumbnailError(theme, cacheDimension),
                ),

                // 2. Interactive & reactive player / badge overlay
                Obx(() {
                  final isInitialized = controller.isControllerInitialized.value;
                  final player = controller.activePlayer;
                  final hovered = controller.isHovered;

                  return Stack(
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
                      if (video.isPrivate)
                        const VideoCardPrivateBadge(),
                      if (video.isUnlisted)
                        const VideoCardUnlistedBadge(),
                      if (video.isMembersOnly)
                        const VideoCardMembersOnlyBadge(),
                      if (video.isSubscribersOnly)
                        const VideoCardSubscribersOnlyBadge(),
                      if (!isInitialized)
                        VideoCardDurationBadge(
                          duration: video.duration,
                          isFactChecked: video.hasPublicAiCredibility,
                        ),
                      if (isInitialized)
                        VideoCardAudioToggle(controller: controller),
                      if (hovered)
                        VideoCardHoverActions(video: video),
                      VideoCardWatchProgressBar(videoId: video.id),
                    ],
                  );
                }),
              ],
            ),
          ),
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

  Widget _buildThumbnailError(ThemeData theme, int? cacheDimension) {
    // If the primary URL failed (e.g. CDN 403 or network issue before edge propagation),
    // seamlessly fallback to an authentic tokenized variant URL if available.
    final fallbackUrl = _getFallbackThumbnailUrl();
    if (fallbackUrl != null &&
        fallbackUrl.isNotEmpty &&
        fallbackUrl != video.thumbnailUrl) {
      return CachedNetworkImage(
        imageUrl: fallbackUrl,
        fit: BoxFit.cover,
        memCacheWidth: cacheDimension,
        maxWidthDiskCache: cacheDimension,
        filterQuality: FilterQuality.medium,
        placeholder: (context, url) => _buildThumbnailShimmer(theme),
        errorWidget: (context, url, error) => _buildPlaceholderContainer(theme),
      );
    }
    return _buildPlaceholderContainer(theme);
  }

  String? _getFallbackThumbnailUrl() {
    for (final variant in video.thumbnailVariants) {
      if (variant.isNotEmpty && variant != video.thumbnailUrl) {
        return variant;
      }
    }
    return null;
  }

  Widget _buildPlaceholderContainer(ThemeData theme) {
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
