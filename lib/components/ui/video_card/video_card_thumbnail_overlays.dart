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
class VideoCardFactCheckBadge extends StatelessWidget {
  const VideoCardFactCheckBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: AppTheme.spacing.xs,
      left: AppTheme.spacing.xs,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacing.xs * 1.5,
          vertical: AppTheme.spacing.xs / 2,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.95), // Emerald
          borderRadius: AppTheme.radius.circularMd,
          border: Border.all(
            color: AppColors.textPrimary.withValues(alpha: 0.15),
            width: 0.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_rounded,
              color: AppColors.textPrimary,
              size: 11,
            ),
            SizedBox(width: 4),
            Text(
              'Fact Checked',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 9,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Duration indicator badge displayed on the bottom-right of video thumbnails.
class VideoCardDurationBadge extends StatelessWidget {
  const VideoCardDurationBadge({
    required this.duration,
    super.key,
  });

  final String duration;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgPage.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          duration,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
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
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          height: 3,
          width: double.infinity,
          color: AppColors.textPrimary.withValues(alpha: 0.2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: (progress / 100).clamp(0.0, 1.0),
              child: Container(
                color: AppColors.error,
              ),
            ),
          ),
        ),
      );
    });
  }
}
