import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/show_dialog.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Minimal floating horizontal action dock for TruthWorld fullscreen player.
/// Replaces the bulky vertical action bar with a sleek, translucent glass pill.
class FullscreenFloatingActionDock extends StatelessWidget {
  const FullscreenFloatingActionDock({
    required this.ctrl,
    this.vc,
    super.key,
  });

  final TowerPlayerController ctrl;
  final VideoController? vc;

  @override
  Widget build(BuildContext context) {
    final videoCtrl = vc ?? ctrl.videoController;
    if (videoCtrl == null) return const SizedBox.shrink();

    final isCompact = MediaQuery.of(context).size.width < 500;

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0x730F0F12), // rgba(15, 15, 18, 0.45)
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Like
          Obx(() {
            final isLiked = videoCtrl.isLiked.value;
            return _DockBtn(
              icon: isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
              isActive: isLiked,
              onTap: () {
                videoCtrl.toggleLike();
                ctrl.startHideTimer();
              },
              tooltip: isLiked ? 'Liked' : 'Like',
            );
          }),
          // Comments
          Obx(() {
            final isCommentsOpen = ctrl.overlayManager.isCommentsOpen || ctrl.showCommentsPopup.value;
            return _DockBtn(
              icon: isCommentsOpen
                  ? Icons.chat_bubble_rounded
                  : Icons.chat_bubble_outline_rounded,
              isActive: isCommentsOpen,
              onTap: () {
                ctrl.overlayManager.toggle(TowerPlayerOverlay.comments);
                ctrl.showCommentsPopup.value = ctrl.overlayManager.isCommentsOpen;
                ctrl.showTranscriptPopup.value = false;
                ctrl.showFactCheckPopup.value = false;
                ctrl.showLiveChat.value = false;
                ctrl.startHideTimer();
              },
              tooltip: 'Comments',
            );
          }),
          // Claims
          Obx(() {
            final isFactCheckOpen = ctrl.overlayManager.isFactCheckOpen || ctrl.showFactCheckPopup.value;
            return _DockBtn(
              icon: isFactCheckOpen
                  ? Icons.fact_check_rounded
                  : Icons.fact_check_outlined,
              isActive: isFactCheckOpen,
              onTap: () {
                ctrl.overlayManager.toggle(TowerPlayerOverlay.factCheck);
                ctrl.showFactCheckPopup.value = ctrl.overlayManager.isFactCheckOpen;
                ctrl.showCommentsPopup.value = false;
                ctrl.showTranscriptPopup.value = false;
                ctrl.showLiveChat.value = false;
                ctrl.startHideTimer();
              },
              tooltip: 'Claims & Fact-Check',
            );
          }),
          // Share (hidden on compact screens, accessible via More menu)
          if (!isCompact)
            _DockBtn(
              icon: Icons.share_outlined,
              onTap: () {
                final url = 'https://truthworld.app/video/${videoCtrl.video.id}';
                Clipboard.setData(ClipboardData(text: url));
                AppSnackbar.info('Video link copied to clipboard');
                ctrl.startHideTimer();
              },
              tooltip: 'Share',
            ),
          // More videos (hidden on compact screens, accessible via More menu)
          if (!isCompact)
            Obx(() {
              final isMoreVideosOpen = ctrl.showMoreVideos.value;
              return _DockBtn(
                icon: isMoreVideosOpen
                    ? Icons.video_collection_rounded
                    : Icons.video_collection_outlined,
                isActive: isMoreVideosOpen,
                onTap: () {
                  ctrl.toggleMoreVideos();
                  ctrl.startHideTimer();
                },
                tooltip: 'More videos',
              );
            }),
          // More (⋯)
          Theme(
            data: Theme.of(context).copyWith(
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: Colors.white,
                size: 18,
              ),
              tooltip: 'More actions',
              padding: EdgeInsets.zero,
              color: const Color(0xFF161616),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              onSelected: (val) {
                ctrl.startHideTimer();
                switch (val) {
                  case 'share':
                    final url = 'https://truthworld.app/video/${videoCtrl.video.id}';
                    Clipboard.setData(ClipboardData(text: url));
                    AppSnackbar.info('Video link copied to clipboard');
                  case 'more_videos':
                    ctrl.toggleMoreVideos();
                  case 'claims':
                    ctrl.overlayManager.toggle(TowerPlayerOverlay.factCheck);
                    ctrl.showFactCheckPopup.value = ctrl.overlayManager.isFactCheckOpen;
                    ctrl.showCommentsPopup.value = false;
                    ctrl.showTranscriptPopup.value = false;
                    ctrl.showLiveChat.value = false;
                  case 'save':
                    showModernizedPlaylistDialog(
                      context: context,
                      videoId: videoCtrl.video.id,
                    );
                  case 'transcript':
                    ctrl.overlayManager.toggle(TowerPlayerOverlay.transcript);
                    ctrl.showTranscriptPopup.value = ctrl.overlayManager.isTranscriptOpen;
                    ctrl.showCommentsPopup.value = false;
                    ctrl.showFactCheckPopup.value = false;
                    ctrl.showLiveChat.value = false;
                    if (ctrl.showTranscriptPopup.value) {
                      videoCtrl.loadTranscriptForVideo();
                    }
                  case 'chat':
                    ctrl.overlayManager.toggle(TowerPlayerOverlay.liveChat);
                    ctrl.showLiveChat.value = ctrl.overlayManager.isLiveChatOpen;
                    ctrl.showCommentsPopup.value = false;
                    ctrl.showFactCheckPopup.value = false;
                    ctrl.showTranscriptPopup.value = false;
                  case 'stats':
                    ctrl.overlayManager.toggle(TowerPlayerOverlay.statsForNerds);
                    ctrl.showStatsForNerds.value = ctrl.overlayManager.isStatsForNerdsOpen;
                }
              },
              itemBuilder: (context) => [
                if (isCompact) ...[
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(
                          Icons.share_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Share',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'more_videos',
                    child: Row(
                      children: [
                        Icon(
                          Icons.video_collection_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'More Videos',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
                const PopupMenuItem(
                  value: 'claims',
                  child: Row(
                    children: [
                      Icon(
                        Icons.fact_check_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Claims & Fact-Check',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'save',
                  child: Row(
                    children: [
                      Icon(
                        Icons.playlist_add_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Save to Playlist',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'transcript',
                  child: Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Transcript',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'chat',
                  child: Row(
                    children: [
                      Icon(
                        Icons.forum_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Live Chat',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'stats',
                  child: Row(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Playback Statistics',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DockBtn extends StatelessWidget {
  const _DockBtn({
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 17,
          color: isActive ? AppColors.brand : Colors.white,
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: btn,
      );
    }
    return btn;
  }
}

/// Legacy compatibility wrapper for FullscreenVerticalActionsBar.
/// Points to FullscreenFloatingActionDock to eliminate the heavy vertical grey rail.
class FullscreenVerticalActionsBar extends StatelessWidget {
  const FullscreenVerticalActionsBar({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return FullscreenFloatingActionDock(ctrl: ctrl);
  }
}
