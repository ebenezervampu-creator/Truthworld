import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';

class FullscreenVerticalActionsBar extends StatelessWidget {
  final TowerPlayerController ctrl;
  const FullscreenVerticalActionsBar({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<VideoController>(tag: ctrl.tag)) {
      return const SizedBox.shrink();
    }

    final vc = Get.find<VideoController>(tag: ctrl.tag);
    final mainController = Get.isRegistered<MainController>()
        ? Get.find<MainController>()
        : Get.put(MainController());
    final playlistController = Get.isRegistered<PlaylistController>()
        ? Get.find<PlaylistController>()
        : Get.put(PlaylistController());

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Like
          Obx(() {
            final count =
                mainController.videoLikes[vc.video.id] ?? vc.video.likeCount;
            return _buildVerticalIconBtn(
              icon: vc.isLiked.value
                  ? Icons.thumb_up_rounded
                  : Icons.thumb_up_outlined,
              onTap: () => vc.toggleLike(),
              isActive: vc.isLiked.value,
              badgeCount: count,
            );
          }),
          const SizedBox(height: 12),

          // Dislike
          Obx(
            () => _buildVerticalIconBtn(
              icon: vc.isDisliked.value
                  ? Icons.thumb_down_rounded
                  : Icons.thumb_down_outlined,
              onTap: () => vc.toggleDislike(),
              isActive: vc.isDisliked.value,
            ),
          ),
          const SizedBox(height: 12),

          // Share
          _buildVerticalIconBtn(
            icon: Icons.reply_rounded,
            onTap: () => mainController.shareVideo(
              vc.video.id,
              vc.video.title,
              thumbnailUrl: vc.video.thumbnailUrl,
              channelName: vc.video.channelName,
              durationMs: vc.video.durationValue.inMilliseconds,
              currentPosition: vc.videoPlayerController?.value.position,
            ),
            flipHorizontal: true,
          ),
          const SizedBox(height: 12),

          // Watch Later
          Obx(() {
            final isInWatchLater = playlistController.isInWatchLater(
              vc.video.id,
            );
            return _buildVerticalIconBtn(
              icon: isInWatchLater
                  ? Icons.schedule_rounded
                  : Icons.schedule_outlined,
              onTap: () => playlistController.toggleWatchLater(vc.video.id),
              isActive: isInWatchLater,
            );
          }),
          const SizedBox(height: 12),

          // Save
          _buildVerticalIconBtn(
            icon: Icons.bookmark_border_rounded,
            onTap: () {
              AppSnackbar.show(
                'Saved',
                'Video added to your library',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.black87,
                colorText: Colors.white,
              );
            },
          ),
          const SizedBox(height: 12),

          // Comments
          Obx(
            () => _buildVerticalIconBtn(
              icon: Icons.chat_bubble_outline_rounded,
              onTap: () {
                ctrl.showTranscriptPopup.value = false;
                ctrl.showCommentsPopup.toggle();
                ctrl.startHideTimer();
              },
              isActive: ctrl.showCommentsPopup.value,
            ),
          ),
          const SizedBox(height: 12),

          // Transcript
          Obx(
            () => _buildVerticalIconBtn(
              icon: Icons.description_outlined,
              onTap: () {
                ctrl.showCommentsPopup.value = false;
                ctrl.showTranscriptPopup.toggle();
                ctrl.startHideTimer();
              },
              isActive: ctrl.showTranscriptPopup.value,
            ),
          ),
          const SizedBox(height: 12),

          // More
          _buildVerticalIconBtn(
            icon: Icons.more_vert_rounded,
            onTap: () {
              ctrl.settingsOpen.value = true;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalIconBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
    int? badgeCount,
    bool flipHorizontal = false,
  }) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? PT.primary.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: isActive ? PT.primary : Colors.white,
              textDirection: flipHorizontal ? TextDirection.rtl : null,
            ),
          ),
        ),
        if (badgeCount != null && badgeCount > 0)
          Positioned(
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: PT.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
