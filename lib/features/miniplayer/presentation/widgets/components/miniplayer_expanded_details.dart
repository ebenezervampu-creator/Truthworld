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
                activeTrackColor: AppColors.brand,
                inactiveTrackColor: Colors.white.withValues(
                  alpha: 0.24,
                ),
                thumbColor: AppColors.brand,
                overlayColor: AppColors.brand.withValues(alpha: 0.15),
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
          Obx(() {
            final isAutoplayOn = controller.isAutoplay.value;
            final hasPrev = controller.hasPreviousVideo;
            final hasNext = controller.hasNextVideo;
            final playing = controller.isPlaying.value;

            final playButton = Material(
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
                    color: Colors.black,
                    size: 32,
                  ),
                ),
              ),
            );

            if (!isAutoplayOn) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [playButton],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: hasPrev ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !hasPrev,
                    child: IconButton(
                      tooltip: hasPrev ? 'Previous Video' : 'No previous video',
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: AppColors.textPrimary,
                        size: 28,
                      ),
                      onPressed: hasPrev ? controller.playPrevious : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                playButton,
                const SizedBox(width: 16),
                Opacity(
                  opacity: hasNext ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !hasNext,
                    child: IconButton(
                      tooltip: hasNext ? 'Next Video' : 'No next video',
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: AppColors.textPrimary,
                        size: 28,
                      ),
                      onPressed: hasNext ? controller.playNext : null,
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          Obx(() {
            final info = controller.videoInfo.value;
            final clip = controller.activeClip.value;
            final isAudio = controller.isAudioOnly.value;
            if (info == null) return const SizedBox.shrink();

            final title = clip != null ? clip.title : info.title;
            final channel = clip != null && clip.channelName.isNotEmpty
                ? clip.channelName
                : info.channelName;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (clip != null || isAudio)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        if (clip != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.brand.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.content_cut_rounded,
                                  color: Colors.white,
                                  size: 11,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'CLIP MODE',
                                  style: GoogleFonts.robotoMono(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: controller.clearActiveClip,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brand,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'WATCH FULL',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (isAudio && clip == null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.brand.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.headphones_rounded,
                                  color: Colors.white,
                                  size: 11,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'AUDIO ONLY',
                                  style: GoogleFonts.robotoMono(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                Text(
                  title,
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
                  clip != null
                      ? '$channel  •  Clip from ${info.title}'
                      : channel,
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
