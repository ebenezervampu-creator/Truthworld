import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card/video_card_avatar.dart';
import 'package:truthworld/components/ui/video_card/video_card_controller.dart';
import 'package:truthworld/components/ui/video_card/video_card_controller_registry.dart';
import 'package:truthworld/components/ui/video_card/video_card_formatters.dart';
import 'package:truthworld/components/ui/video_card/video_card_thumbnail_overlays.dart';
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/core/services/user_preferences_service.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Full-width YouTube-style video recommendation card matching the mobile watch screen:
/// - Edge-to-edge 16:9 thumbnail with zero visual clutter.
/// - Dark duration badge at the bottom-right corner.
/// - Real-time watch progress bar on the bottom edge.
/// - Channel circular avatar, 2-line bold title, metadata (Channel · ▷Views · Time ago).
/// - Horizontal three-dots action menu (`Icons.more_horiz`).
class RecommendationVideoCard extends StatelessWidget {
  const RecommendationVideoCard({
    required this.video,
    super.key,
    this.heroPrefix = 'rec_video',
    this.onTap,
  });

  final Video video;
  final String heroPrefix;
  final VoidCallback? onTap;

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
    if (Get.isRegistered<UserPreferencesService>() &&
        UserPreferencesService.to.isVideoBlocked(video)) {
      return const SizedBox.shrink();
    }

    final tag = 'rec_${video.id}_$heroPrefix';
    final controller = Get.isRegistered<VideoCardController>(tag: tag)
        ? Get.find<VideoCardController>(tag: tag)
        : Get.put(
            VideoCardController(
              video: video,
              disableHoverPreview: true,
              heroPrefix: heroPrefix,
              customOnTap: onTap,
            ),
            tag: tag,
          );
    VideoCardControllerRegistry.recordAccess(tag);

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (onTap != null) {
              onTap!();
            } else {
              controller.handleTap(context);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThumbnail(context),
              _buildInfo(context, controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    final isMobileDevice = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final isDesktop =
        !isMobileDevice && MediaQuery.sizeOf(context).width >= 1000;
    final cacheDimension = isDesktop ? 1080 : 720;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-width crystal clear thumbnail
          CachedNetworkImage(
            imageUrl: video.thumbnailUrl,
            fit: BoxFit.cover,
            memCacheWidth: cacheDimension,
            maxWidthDiskCache: cacheDimension,
            placeholder: (context, url) => const ColoredBox(
              color: Color(0xFF161618),
            ),
            errorWidget: (context, url, error) => const ColoredBox(
              color: Color(0xFF161618),
              child: Center(
                child: Icon(
                  Icons.play_circle_outline_rounded,
                  size: 48,
                  color: Colors.white38,
                ),
              ),
            ),
          ),

          // 2. Clean duration badge at bottom-right
          if (formatDurationBadge(video.duration).isNotEmpty)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if ((video.isFactChecked || video.hasAiCredibility) &&
                        video.canPublicViewFactCheck) ...[
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF00E676),
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      formatDurationBadge(video.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Watch progress indicator along the bottom edge
          VideoCardWatchProgressBar(videoId: video.id),
        ],
      ),
    );
  }

  Widget _buildInfo(BuildContext context, VideoCardController controller) {
    return Obx(() {
      final avatarUrl = controller.realChannelAvatarUrl.value;
      final channelName = controller.realChannelName.value.isNotEmpty
          ? controller.realChannelName.value
          : video.channelName;
      final viewsCount = VideoCardFormatters.formatViews(video.views);
      final timeAgo = FormatUtils.formatDate(video.uploadedAt.toDate());

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Circular channel avatar (radius 18 = 36px diameter)
            VideoCardAvatar(
              imageUrl: avatarUrl,
              radius: 18,
              placeholderText: channelName.isEmpty ? '?' : channelName,
            ),
            const SizedBox(width: 12),
            // Title and Metadata column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$channelName   \u25B7$viewsCount   $timeAgo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 12.5,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            // Horizontal 3-dots action menu icon
            IconButton(
              icon: const Icon(
                Icons.more_horiz,
                size: 20,
                color: Colors.white,
              ),
              onPressed: () => VideoOptionsSheet.show(context, video),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    });
  }

  /// Strips redundant leading zeroes on single-digit minutes (e.g. "07:37" -> "7:37")
  /// to match YouTube mobile recommendation badge formatting in Image 2.
  static String formatDurationBadge(String rawDuration) {
    var dur = rawDuration.trim();
    if (dur.isEmpty) return '';
    if (dur.length == 5 && dur.startsWith('0') && dur[1] != '0' && dur[1] != ':') {
      dur = dur.substring(1);
    }
    return dur;
  }
}
