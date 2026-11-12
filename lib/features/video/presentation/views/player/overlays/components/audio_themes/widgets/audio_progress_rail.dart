import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';

/// Minimalist audio playback progress rail with high-contrast timestamps.
class AudioProgressRail extends StatelessWidget {
  const AudioProgressRail({
    required this.ctrl,
    this.accentColor = Colors.white,
    super.key,
  });

  final TowerPlayerController ctrl;
  final Color accentColor;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final position = ctrl.rxValue.value.position;
      final duration = ctrl.rxValue.value.duration;
      final totalMs = duration.inMilliseconds;
      final currentMs = position.inMilliseconds.clamp(0, totalMs > 0 ? totalMs : 1);
      final progress = totalMs > 0 ? (currentMs / totalMs).clamp(0.0, 1.0) : 0.0;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: accentColor,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.20),
              thumbColor: accentColor,
              overlayColor: accentColor.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: progress,
              onChanged: (val) {
                final targetMs = (val * totalMs).round();
                ctrl.seekTo(Duration(milliseconds: targetMs));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
                    fontSize: 10.5,
                    fontFamily: 'RobotoMono',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
                    fontSize: 10.5,
                    fontFamily: 'RobotoMono',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}
