import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_card/hover_preview_coordinator.dart';
import 'package:truthworld/components/ui/video_card/video_card_controller.dart';
import 'package:truthworld/core/services/watch_history_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/show_dialog.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Fact Checked badge displayed on the top-left of eligible video thumbnails.
///
/// Features an instantly recognizable emerald green circular badge with a bold
/// white right mark (checkmark) ensuring high contrast and immediate clarity.
class VideoCardFactCheckBadge extends StatelessWidget {
  const VideoCardFactCheckBadge({
    super.key,
    this.top,
    this.left,
    this.right,
    this.bottom,
    this.size,
  });

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final effectiveSize = size ?? 26.0;
    final effectiveTop = (top == null && bottom == null) ? 12.0 : top;
    final effectiveLeft = (left == null && right == null) ? 12.0 : left;

    return Positioned(
      top: effectiveTop,
      left: effectiveLeft,
      right: right,
      bottom: bottom,
      child: Tooltip(
        message: 'Fact Checked',
        child: Container(
          key: const ValueKey('video_card_fact_checked_badge'),
          width: effectiveSize,
          height: effectiveSize,
          decoration: BoxDecoration(
            color: const Color(0xFF029C5D),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.verified_rounded,
              color: Colors.white,
              size: (effectiveSize * 0.62).roundToDouble(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Duration indicator badge displayed on the bottom-right of video thumbnails.
///
/// When [isFactChecked] is true, displays a verified badge icon directly before
/// the duration inside the badge.
class VideoCardDurationBadge extends StatelessWidget {
  const VideoCardDurationBadge({
    required this.duration,
    this.isFactChecked = false,
    super.key,
  });

  final String duration;
  final bool isFactChecked;

  @override
  Widget build(BuildContext context) {
    if (duration.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFactChecked) ...[
              const Icon(
                Icons.verified_rounded,
                color: Color(0xFF00E676),
                size: 13,
              ),
              const SizedBox(width: 3.5),
            ],
            Text(
              duration,
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
    );
  }
}

/// Audio mute toggle button displayed on the active hover preview.
class VideoCardAudioToggle extends StatelessWidget {
  const VideoCardAudioToggle({
    required this.controller,
    super.key,
  });

  final VideoCardController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 8,
      left: 8,
      child: Obx(() {
        final isMuted = HoverPreviewCoordinator.globalMute.value;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final newMute = !HoverPreviewCoordinator.globalMute.value;
            HoverPreviewCoordinator.globalMute.value = newMute;
            if (newMute) {
              await controller.activePlayer?.setVolume(0.0);
            } else {
              HoverPreviewCoordinator.pauseAllMainPlayers();
              await controller.activePlayer?.setVolume(1.0);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.bgPage.withValues(alpha: 0.8),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Icon(
              isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: AppColors.textPrimary,
              size: 16,
            ),
          ),
        );
      }),
    );
  }
}

/// Hover action icon button helper with tooltip and circular ink surface.
class VideoCardHoverIconButton extends StatelessWidget {
  const VideoCardHoverIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    super.key,
    this.iconColor = AppColors.textPrimary,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.bgPage.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 18,
          ),
        ),
      ),
    );
  }
}

/// Quick actions (Watch Later, Add to Queue) displayed in thumbnail top-right on hover.
class VideoCardHoverActions extends StatelessWidget {
  const VideoCardHoverActions({
    required this.video,
    super.key,
  });

  final Video video;

  @override
  Widget build(BuildContext context) {
    final isSaved = Get.isRegistered<PlaylistController>() &&
        Get.find<PlaylistController>().isInWatchLater(video.id);

    return Positioned(
      top: 8,
      right: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VideoCardHoverIconButton(
            icon: isSaved
                ? Icons.check_circle_rounded
                : Icons.watch_later_outlined,
            tooltip: isSaved ? 'Saved to Watch Later' : 'Watch later',
            onTap: () {
              showModernizedPlaylistDialog(
                context: context,
                videoId: video.id,
              );
            },
          ),
          const SizedBox(height: 6),
          VideoCardHoverIconButton(
            icon: Icons.playlist_add_rounded,
            tooltip: 'Add to queue',
            onTap: () {
              AppSnackbar.show(
                'Added to queue',
                "'${video.title}' has been added to your play queue.",
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: AppColors.bgSurfaceHover,
                colorText: AppColors.textPrimary,
                margin: const EdgeInsets.all(20),
                borderRadius: 16,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Thin progress bar indicating current watch completion progress.
class VideoCardWatchProgressBar extends StatelessWidget {
  const VideoCardWatchProgressBar({
    required this.videoId,
    super.key,
  });

  final String videoId;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<WatchHistoryService>()) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      final progress = WatchHistoryService.to.watchProgressMap[videoId] ??
          WatchHistoryService.to.getProgress(videoId);
      if (progress <= 0) return const SizedBox.shrink();

      return Positioned(
        bottom: 2,
        left: 6,
        right: 6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Container(
            height: 3.5,
            width: double.infinity,
            color: Colors.white.withValues(alpha: 0.25),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (progress / 100).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Private video badge displayed on thumbnail when viewed by the channel owner.
class VideoCardPrivateBadge extends StatelessWidget {
  const VideoCardPrivateBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 14,
      right: 14,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 13,
            ),
            SizedBox(width: 4),
            Text(
              'Private',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Unlisted video badge displayed on thumbnail when viewed by the channel owner.
class VideoCardUnlistedBadge extends StatelessWidget {
  const VideoCardUnlistedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 14,
      right: 14,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.link_rounded,
              color: Colors.white,
              size: 13,
            ),
            SizedBox(width: 4),
            Text(
              'Unlisted',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Members-only video badge displayed on thumbnail.
class VideoCardMembersOnlyBadge extends StatelessWidget {
  const VideoCardMembersOnlyBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 14,
      right: 14,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.stars_rounded,
              color: Color(0xFF00E676),
              size: 13,
            ),
            SizedBox(width: 4),
            Text(
              'Members only',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subscribers-only video badge displayed on thumbnail.
class VideoCardSubscribersOnlyBadge extends StatelessWidget {
  const VideoCardSubscribersOnlyBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 14,
      right: 14,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.subscriptions_rounded,
              color: Colors.white,
              size: 13,
            ),
            SizedBox(width: 4),
            Text(
              'Subscribers only',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
