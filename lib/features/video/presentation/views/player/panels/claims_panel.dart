import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/settings_tiles.dart';
import 'package:truthworld/features/video/presentation/widgets/video_claims_bottom_sheet.dart';

/// In-player panel for browsing and selecting AI Credibility Claims as chapters
class ClaimsPanel extends StatelessWidget {
  const ClaimsPanel({required this.ctrl, super.key});
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
        tag: 'ClaimsPanel.findVideoController',
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

    final claims = ctrl.timestampedClaims;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelHeader(
          title: 'Credibility Claims',
          onBack: () => ctrl.activePanel.value = '',
          onClose: null,
        ),
        Flexible(
          child: claims.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No fact-checked claims available for this video',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: claims.length,
                  itemBuilder: (_, i) {
                    final claim = claims[i];
                    return ClaimChapterTile(
                      claim: claim,
                      video: video,
                      playerCtrl: ctrl,
                      index: i,
                      onTapOverride: () {
                        ctrl.seekTo(claim.startDuration);
                        ctrl.videoPlayerController.play();
                        ctrl.activeClaim.value = claim;
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
