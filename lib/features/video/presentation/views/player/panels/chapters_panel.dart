import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/settings_tiles.dart';
import 'package:truthworld/features/video/presentation/widgets/video_chapters_bottom_sheet.dart';

class ChaptersPanel extends StatelessWidget {
  const ChaptersPanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    VideoController? vc;
    try {
      if (ctrl.tag != null &&
          Get.isRegistered<VideoController>(tag: ctrl.tag)) {
        vc = Get.find<VideoController>(tag: ctrl.tag);
      } else if (Get.isRegistered<VideoController>()) {
        vc = Get.find<VideoController>();
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'ChaptersPanel.findVideoController',
      );
    }

    final video =
        vc?.video ??
        Video(
          id: '',
          title: '',
          description: '',
          videoUrl: '',
          thumbnailUrl: '',
          duration: 0,
          ownerId: '',
          channelId: '',
          channelName: '',
          category: '',
          tags: const [],
          createdAt: DateTime.now(),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelHeader(
          title: 'Chapters',
          onBack: () => ctrl.activePanel.value = '',
          onClose: null,
        ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: ctrl.chapters.length,
            itemBuilder: (_, i) {
              final ch = ctrl.chapters[i];
              return ChapterTile(
                chapter: ch,
                video: video,
                playerCtrl: ctrl,
                index: i,
                onTapOverride: () {
                  ctrl.seekTo(ch.startTime);
                  ctrl.closeSettings();
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
