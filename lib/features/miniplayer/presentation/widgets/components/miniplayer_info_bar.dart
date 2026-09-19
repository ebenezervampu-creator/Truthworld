import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/components/miniplayer_overlay_controls.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Info bar beneath the video card for desktop floating miniplayer mode.
class MiniplayerInfoBar extends StatelessWidget {
  final MiniplayerController controller;
  final Size cardSize;
  final Size screenSize;

  const MiniplayerInfoBar({
    required this.controller,
    required this.cardSize,
    required this.screenSize,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MiniplayerConfig.infoBarHeight,
      child: Material(
        color: AppColors.bgPage,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: (d) =>
              controller.onPanCard(d.delta, cardSize, screenSize),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: controller.openFullScreen,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: MiniplayerTitleAndMeta(controller: controller),
                    ),
                  ),
                ),
                Obx(() {
                  final playing = controller.isPlaying.value;
                  return MiniplayerOverlayIconButton(
                    icon: playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    tooltip: playing ? 'Pause' : 'Play',
                    size: 20,
                    onTap: controller.togglePlayPause,
                  );
                }),
                const SizedBox(width: 4),
                MiniplayerOverlayIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onTap: controller.dismiss,
                ),
                const SizedBox(width: 4),
                MiniplayerOverlayIconButton(
                  icon: Icons.open_in_full_rounded,
                  tooltip: 'Expand',
                  onTap: controller.openFullScreen,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Title and metadata subtitle display for the miniplayer info bar.
class MiniplayerTitleAndMeta extends StatelessWidget {
  final MiniplayerController controller;

  const MiniplayerTitleAndMeta({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Obx(() {
          final info = controller.videoInfo.value;
          return Text(
            info?.title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          );
        }),
        const SizedBox(height: 2),
        Obx(() {
          final info = controller.videoInfo.value;
          final pos = controller.formatDuration(
            controller.currentPosition.value,
          );
          final dur = controller.formatDuration(controller.totalDuration.value);
          return Text(
            '${info?.channelName ?? ''}  •  $pos / $dur',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.2,
            ),
          );
        }),
      ],
    );
  }
}
