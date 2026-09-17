import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

class SubtitlesPlayerPreview extends StatelessWidget {
  const SubtitlesPlayerPreview({
    required this.controller,
    required this.surfaceColor,
    required this.borderColor,
    required this.textColor,
    required this.isDarkMode,
    super.key,
  });

  final SubtitlesController controller;
  final Color surfaceColor;
  final Color borderColor;
  final Color textColor;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isExpanded = controller.showVideoPreview.value;

      return Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Column(
          children: [
            // Collapse / Expand Toggle Bar
            InkWell(
              onTap: controller.toggleVideoPreview,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.play_circle_filled_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Video Player & Real-time Subtitle Sync Preview',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),

            if (isExpanded) ...[
              Divider(height: 1, color: borderColor),
              Container(
                padding: const EdgeInsets.all(12),
                color: isDarkMode
                    ? const Color(0xFF0F0F0F)
                    : const Color(0xFF0F172A),
                child: Column(
                  children: [
                    // Video Viewport with Live Subtitle Overlay
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 220,
                          maxWidth: 420,
                        ),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (controller.isVideoPlayerInitialized.value &&
                                    controller.videoPlayerController != null)
                                  VideoPlayer(controller.videoPlayerController!)
                                else
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.video_library_rounded,
                                        size: 44,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Synchronized Video Preview',
                                        style: AppTextStyles.caption.copyWith(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),

                                // Subtitle Overlay Box
                                Obx(() {
                                  final activeIdx =
                                      controller.activeCueIndex.value;
                                  if (activeIdx >= 0 &&
                                      activeIdx < controller.currentCues.length) {
                                    final text =
                                        controller.currentCues[activeIdx].text;
                                    if (text.trim().isNotEmpty) {
                                      return Positioned(
                                        bottom: 12,
                                        left: 16,
                                        right: 16,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.8),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              text,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                shadows: [
                                                  Shadow(
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                  return const SizedBox.shrink();
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Video Scrubber & Playhead Controls
                    SubtitlesVideoControlsBar(controller: controller),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class SubtitlesVideoControlsBar extends StatelessWidget {
  const SubtitlesVideoControlsBar({
    required this.controller,
    super.key,
  });

  final SubtitlesController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pos = controller.currentVideoPosition.value;
      final dur = controller.videoDuration.value;
      final isPlaying = controller.isVideoPlaying.value;

      final posMs = pos.inMilliseconds.toDouble();
      final durMs = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
      final clampedPos = posMs.clamp(0.0, durMs);

      return Column(
        children: [
          // Scrubber Slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: AppColors.brand,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: clampedPos,
              max: durMs,
              onChanged: (val) {
                controller.seekTo(Duration(milliseconds: val.toInt()));
              },
            ),
          ),

          // Action Buttons Bar
          Row(
            children: [
              // Play/Pause
              IconButton(
                onPressed: controller.togglePlayPause,
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                tooltip: isPlaying ? 'Pause' : 'Play',
              ),

              // Skip -5s
              IconButton(
                onPressed: () {
                  final target = pos - const Duration(seconds: 5);
                  controller.seekTo(
                    target < Duration.zero ? Duration.zero : target,
                  );
                },
                icon: const Icon(
                  Icons.replay_5_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                tooltip: 'Rewind 5s',
              ),

              // Skip +5s
              IconButton(
                onPressed: () {
                  final target = pos + const Duration(seconds: 5);
                  controller.seekTo(
                    target > dur ? dur : target,
                  );
                },
                icon: const Icon(
                  Icons.forward_5_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                tooltip: 'Forward 5s',
              ),

              const SizedBox(width: 8),

              // Timecode display
              Text(
                '${SubtitlesController.formatDurationToTimecode(pos).split('.').first} / ${SubtitlesController.formatDurationToTimecode(dur).split('.').first}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),

              const Spacer(),

              // Add Cue at Current Playhead
              OutlinedButton.icon(
                onPressed: controller.addCueAtCurrentTime,
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                label: const Text(
                  '+ Cue at Playhead',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }
}
