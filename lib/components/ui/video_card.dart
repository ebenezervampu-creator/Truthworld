import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card/video_card_barrel.dart';
import 'package:truthworld/core/services/user_preferences_service.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:visibility_detector/visibility_detector.dart';

export 'video_card/video_card_barrel.dart';

/// Declarative, performance-optimized video card component supporting
/// grid and list layouts, hover previews, and seamless video handoff.
@immutable
class VideoCard extends StatelessWidget {
  const VideoCard({
    required this.video,
    super.key,
    this.isGrid = false,
    this.heroPrefix = 'video_card',
    this.onTap,
    this.disableHoverPreview = false,
    this.isChannelContext = false,
  });

  final Video video;
  final bool isGrid;
  final String heroPrefix;
  final VoidCallback? onTap;
  final bool disableHoverPreview;
  final bool isChannelContext;

  @override
  Widget build(BuildContext context) {
    final hasPlayable = VideoVisibilityPolicy.hasPlayableMedia(video);
    final isExplicitlyHidden = video.isDraft ||
        video.isRejected ||
        video.status == VideoStatus.deleted ||
        video.status == VideoStatus.rejected ||
        video.visibility.trim().toLowerCase() == 'draft' ||
        video.visibility.trim().toLowerCase() == 'rejected' ||
        (video.isPrivate && !VideoVisibilityPolicy.isOwner(video)) ||
        !hasPlayable;

    if (isExplicitlyHidden) {
      return const SizedBox.shrink();
    }
    if (!VideoVisibilityPolicy.isValidVideo(video) && !hasPlayable) {
      return const SizedBox.shrink();
    }
    final isOwner = VideoVisibilityPolicy.isOwner(video);
    if (!isChannelContext && !isOwner) {
      if (Get.isRegistered<UserPreferencesService>() &&
          UserPreferencesService.to.isVideoBlocked(video)) {
        return const SizedBox.shrink();
      }
    }

    final tag = 'video_card_${video.id}_$heroPrefix';
    final controller = Get.isRegistered<VideoCardController>(tag: tag)
        ? Get.find<VideoCardController>(tag: tag)
        : Get.put(
            VideoCardController(
              video: video,
              disableHoverPreview: disableHoverPreview,
              heroPrefix: heroPrefix,
              customOnTap: onTap,
            ),
            tag: tag,
          );
    if (onTap != null) {
      controller.customOnTap = onTap;
    }
    VideoCardControllerRegistry.recordAccess(tag);

    final isMobileDevice = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    final cardContent = MouseRegion(
      onEnter: (_) => controller.handleHoverEnter(),
      onExit: (_) => controller.handleHoverExit(),
      child: Semantics(
        button: true,
        enabled: true,
        label: 'Video: ${video.title} by ${video.channelName}',
        onTap: () => controller.handleTap(context),
        child: Obx(() {
          final hovered = controller.isHovered;

          return AnimatedScale(
            scale: hovered ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: isGrid
                  ? EdgeInsets.zero
                  : EdgeInsets.only(bottom: AppTheme.spacing.md),
              decoration: isGrid
                  ? BoxDecoration(
                      color: const Color(0xFF0F0F11),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    )
                  : const BoxDecoration(
                      color: Colors.transparent,
                    ),
              clipBehavior: isGrid ? Clip.antiAlias : Clip.none,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => controller.handleTap(context),
                  borderRadius: BorderRadius.circular(16),
                  child: isGrid
                      ? _buildGridContent(context, controller)
                      : _buildListContent(context, controller),
                ),
              ),
            ),
          );
        }),
      ),
    );

    final isolatedCardContent = RepaintBoundary(child: cardContent);

    if (kIsWeb || !isMobileDevice || disableHoverPreview) {
      return isolatedCardContent;
    }

    return VisibilityDetector(
      key: Key('video_card_${video.id}_$heroPrefix'),
      onVisibilityChanged: (info) {
        controller.handleVisibilityChanged(info.visibleFraction);
      },
      child: isolatedCardContent,
    );
  }

  Widget _buildGridContent(
    BuildContext context,
    VideoCardController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        VideoCardThumbnail(video: video, controller: controller),
        VideoCardGridInfo(
          video: video,
          controller: controller,
          isChannelContext: isChannelContext,
        ),
      ],
    );
  }

  Widget _buildListContent(
    BuildContext context,
    VideoCardController controller,
  ) {
    final isMobileDevice = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final isDesktop = !isMobileDevice && MediaQuery.sizeOf(context).width >= 1000;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isCompact = availableWidth < 220;
        final defaultThumbWidth =
            isDesktop ? 260.0 : AppTheme.sizes.thumbnailMediumWidth;
        final thumbWidth = availableWidth > 260
            ? defaultThumbWidth
            : (availableWidth * 0.38).clamp(44.0, defaultThumbWidth);

        return Padding(
          padding: EdgeInsets.all(isCompact ? 4.0 : AppTheme.spacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: thumbWidth,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: VideoCardThumbnail(
                    video: video,
                    controller: controller,
                    borderRadius: BorderRadius.circular(isCompact ? 4 : 8),
                  ),
                ),
              ),
              SizedBox(width: isCompact ? 6 : 12),
              Expanded(
                child: VideoCardListInfo(
                  video: video,
                  controller: controller,
                  isCompact: isCompact,
                  isChannelContext: isChannelContext,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
