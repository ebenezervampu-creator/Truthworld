// ignore: implementation_imports
import 'package:chewie/src/center_play_button.dart';
// ignore: implementation_imports
import 'package:chewie/src/center_seek_button.dart';
import 'package:flutter/foundation.dart';
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

  bool _useChewieMobileButtons(BuildContext context) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return true;
    }
    if (kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        return true;
      }
      final screenWidth = MediaQuery.of(context).size.width;
      if (screenWidth < 600 || maxControlsWidth < 600) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = maxControlsWidth < 600;
    final useChewie = _useChewieMobileButtons(context);

    if (useChewie) {
      return Obx(() {
        final isFinished = (ctrl.vv.position >= ctrl.vv.duration) &&
            ctrl.vv.duration.inSeconds > 0;
        final isPlaying = ctrl.isPlaying.value;
        const buttonBg = Colors.black54;

        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CenterSeekButton(
              iconData: Icons.replay_10_rounded,
              backgroundColor: buttonBg,
              iconColor: Colors.white,
              show: true,
              iconSize: 28,
              onPressed: () => ctrl.seekRelative(-10),
            ),
            const SizedBox(width: 24),
            CenterPlayButton(
              backgroundColor: buttonBg,
              iconColor: Colors.white,
              isFinished: isFinished,
              isPlaying: isPlaying,
              show: true,
              onPressed: ctrl.togglePlayPause,
            ),
            const SizedBox(width: 24),
            CenterSeekButton(
              iconData: Icons.forward_10_rounded,
              backgroundColor: buttonBg,
              iconColor: Colors.white,
              show: true,
              iconSize: 28,
              onPressed: () => ctrl.seekRelative(10),
            ),
          ],
        );
      });
    }

    // Substantially increased dimensions for desktop & mobile ergonomics
    final playDiameter = isMobile ? 64.0 : 72.0;
    final skipDiameter = isMobile ? 48.0 : 52.0;
    final playIconSize = isMobile ? 32.0 : 36.0;
    final skipIconSize = isMobile ? 24.0 : 28.0;
    final spacing = isMobile ? 24.0 : 36.0;

    return Obx(
      () => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CenterBtn(
            icon: Icons.replay_10_rounded,
            onTap: () => ctrl.seekRelative(-10),
            size: skipIconSize,
            buttonDiameter: skipDiameter,
            tooltip: 'Rewind 10 seconds (j)',
          ),
          SizedBox(width: spacing),
          CenterBtn(
            onTap: ctrl.togglePlayPause,
            size: playIconSize,
            buttonDiameter: playDiameter,
            isPrimary: true,
            tooltip: ctrl.isPlaying.value ? 'Pause (k)' : 'Play (k)',
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                ctrl.isPlaying.value
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                key: ValueKey<bool>(ctrl.isPlaying.value),
                size: playIconSize,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    color: Color(0xCC000000),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: spacing),
          CenterBtn(
            icon: Icons.forward_10_rounded,
            onTap: () => ctrl.seekRelative(10),
            size: skipIconSize,
            buttonDiameter: skipDiameter,
            tooltip: 'Forward 10 seconds (l)',
          ),
        ],
      ),
    );
  }
}
