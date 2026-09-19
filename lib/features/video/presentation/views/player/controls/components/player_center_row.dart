import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_controls_buttons.dart';

class CenterRow extends StatelessWidget {
  const CenterRow({
    required this.ctrl,
    required this.maxControlsWidth,
    super.key,
  });
  final TowerPlayerController ctrl;
  final double maxControlsWidth;

  @override
  Widget build(BuildContext context) {
    final isMobile = maxControlsWidth < 600;
    final playSize = isMobile ? 48.0 : 68.0;
    final skipSize = isMobile ? 32.0 : 44.0;
    final spacing = isMobile ? 24.0 : 40.0;

    return Obx(
      () => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: ctrl.hasPreviousVideo ? 1.0 : 0.3,
            child: CenterBtn(
              icon: Icons.skip_previous_rounded,
              onTap: ctrl.hasPreviousVideo ? ctrl.playPrevious : null,
              size: skipSize,
            ),
          ),
          SizedBox(width: spacing),
          CenterBtn(
            icon: ctrl.isPlaying.value
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            onTap: ctrl.togglePlayPause,
            size: playSize,
            isPrimary: true,
          ),
          SizedBox(width: spacing),
          Opacity(
            opacity: ctrl.hasNextVideo ? 1.0 : 0.3,
            child: CenterBtn(
              icon: Icons.skip_next_rounded,
              onTap: ctrl.hasNextVideo ? ctrl.playNext : null,
              size: skipSize,
            ),
          ),
        ],
      ),
    );
  }
}
