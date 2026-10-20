import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_registry.dart';
import 'package:video_player/video_player.dart';

/// Dedicated full-frame video view rendered exclusively when the application is
/// active in native Picture-in-Picture (PiP) mode.
///
/// Strips away all surrounding application chrome (scaffolds, bottom bars, drawer,
/// recommendations feed) so that the floating PiP window renders exclusively the
/// pure video frame edge-to-edge.
class PipDedicatedView extends StatelessWidget {
  const PipDedicatedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: Obx(() {
          final miniplayer = _lookupMiniplayer();
          VideoPlayerController? vpc;
          var hasSubtitles = false;
          var currentSubtitle = '';

          if (miniplayer != null && miniplayer.isVisible) {
            // Touch reactive observables to ensure Obx rebuilds the moment initialization completes
            miniplayer.isVideoReady.value;
            miniplayer.isBuffering.value;
            miniplayer.isPlaying.value;

            if (miniplayer.internalVpc != null &&
                miniplayer.internalVpc!.value.isInitialized) {
              vpc = miniplayer.internalVpc;
              hasSubtitles = miniplayer.subtitlesEnabled.value;
              currentSubtitle = miniplayer.currentSubtitle.value;
            }
          } else if (TowerPlayerRegistry.activePlayers.isNotEmpty) {
            final towerCtrl = TowerPlayerRegistry.activePlayers.last;
            towerCtrl.isPlaying.value;
            if (towerCtrl.videoPlayerController.value.isInitialized) {
              vpc = towerCtrl.videoPlayerController;
              hasSubtitles = towerCtrl.subtitlesEnabled.value;
              currentSubtitle = towerCtrl.currentSubtitle.value;
            }
          }

          if (vpc == null) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            );
          }

          final aspect = vpc.value.aspectRatio > 0
              ? vpc.value.aspectRatio
              : MiniplayerConfig.videoAspectRatio;

          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: aspect,
                  child: VideoPlayer(vpc),
                ),
              ),
              if (hasSubtitles && currentSubtitle.trim().isNotEmpty)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 6,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        currentSubtitle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  MiniplayerController? _lookupMiniplayer() {
    if (Get.isRegistered<MiniplayerController>(tag: 'miniplayer')) {
      return Get.find<MiniplayerController>(tag: 'miniplayer');
    }
    if (Get.isRegistered<MiniplayerController>()) {
      return Get.find<MiniplayerController>();
    }
    return null;
  }
}
