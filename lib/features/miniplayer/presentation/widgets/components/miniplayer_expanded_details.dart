import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Bottom control surface and video details for the expanded miniplayer mode.
class MiniplayerExpandedDetails extends StatelessWidget {
  final MiniplayerController controller;

  const MiniplayerExpandedDetails({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgPage,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            final pos = controller.currentPosition.value;
            final dur = controller.totalDuration.value;
            final posMs = pos.inMilliseconds.toDouble();
            final durMs = dur.inMilliseconds.toDouble();
            return SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: AppColors.error,
                inactiveTrackColor: AppColors.bgDivider.withValues(
                  alpha: 0.3,
                ),
                thumbColor: AppColors.error,
                overlayColor: AppColors.error.withValues(alpha: 0.15),
              ),
              child: Slider(
                value: durMs > 0 ? posMs.clamp(0.0, durMs) : 0.0,
                max: durMs > 0 ? durMs : 1.0,
                onChanged: (val) =>
                    controller.seekTo(Duration(milliseconds: val.toInt())),
              ),
            );
          }),
          Obx(() {
            final pos = controller.formatDuration(
              controller.currentPosition.value,
            );
            final dur = controller.formatDuration(
              controller.totalDuration.value,
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    pos,
                    style: GoogleFonts.robotoMono(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    dur,
                    style: GoogleFonts.robotoMono(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Rewind 10s',
                icon: const Icon(
                  Icons.replay_10_rounded,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                onPressed: controller.seekBackward,
              ),
              const SizedBox(width: 16),
              Obx(() {
                final playing = controller.isPlaying.value;
                return Material(
                  color: AppColors.brand,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: controller.togglePlayPause,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: AppColors.textPrimary,
                        size: 32,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 16),
              IconButton(
                tooltip: 'Forward 10s',
                icon: const Icon(
                  Icons.forward_10_rounded,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                onPressed: controller.seekForward,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            final info = controller.videoInfo.value;
            if (info == null) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info.channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
