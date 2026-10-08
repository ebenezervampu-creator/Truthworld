import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_screen/video_banners_section.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_screen/video_playlist_drawer.dart';
import 'package:truthworld/features/video/presentation/widgets/video_action_buttons.dart';
import 'package:truthworld/features/video/presentation/widgets/video_description_box.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Video information header section displaying title, contextual banners, action controls, and description.
class VideoInfoHeader extends StatelessWidget {
  const VideoInfoHeader({
    required this.controller,
    required this.mainController,
    required this.onSignInPrompt,
    this.channelController,
    this.isDesktop = false,
    this.videoTag,
    super.key,
  });

  final VideoController controller;
  final MainController mainController;
  final ChannelController? channelController;
  final VoidCallback onSignInPrompt;
  final bool isDesktop;
  final String? videoTag;

  @override
  Widget build(BuildContext context) {
    final ctrl = controller;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClickableUrlText(
              text: ctrl.video.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            Obx(() {
              final banners = <Widget>[];
              if (ctrl.navigatedFromPlaylist.value &&
                  ctrl.currentPlaylist.value != null) {
                banners.add(
                  VideoPlaylistBanner(
                    controller: ctrl,
                    playlist: ctrl.currentPlaylist.value!,
                  ),
                );
              }
              if (ctrl.navigatedFromTopic.value &&
                  ctrl.videoTopicsList.isNotEmpty) {
                banners.add(
                  VideoTopicBanner(
                    controller: ctrl,
                    topic: ctrl.videoTopicsList.first,
                    videoTag: videoTag,
                  ),
                );
              }
              if (banners.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: banners,
              );
            }),
            const SizedBox(height: 12),
            VideoActionButtons.build(
              context: context,
              controller: ctrl,
              mainController: mainController,
              channelController: channelController,
              onSignInPrompt: onSignInPrompt,
            ),
            const SizedBox(height: 12),
            VideoDescriptionBox(
              controller: ctrl,
              mainController: mainController,
            ),
            if (!isDesktop)
              Obx(() {
                if (ctrl.navigatedFromPlaylist.value &&
                    ctrl.currentPlaylist.value != null &&
                    ctrl.playlistVideos.isNotEmpty &&
                    ctrl.showPlaylistDrawer.value) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: VideoPlaylistDrawer(controller: ctrl),
                  );
                }
                return const SizedBox.shrink();
              }),
          ],
        ),
      ),
    );
  }
}
