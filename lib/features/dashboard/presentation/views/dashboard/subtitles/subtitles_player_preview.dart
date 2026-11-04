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
    this.isMobile = false,
    super.key,
  });

  final SubtitlesController controller;
  final Color surfaceColor;
  final Color borderColor;
  final Color textColor;
  final bool isDarkMode;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (!isMobile) {
      return Container(
        width: 380,
        decoration: BoxDecoration(
          color: surfaceColor,
          border: Border(left: BorderSide(color: borderColor)),
        ),
        child: Column(
          children: [
            // Dock Header with title & close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.play_circle_filled_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Video Preview',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                    tooltip: 'Close Video Preview',
                    onPressed: controller.toggleVideoPreview,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildVideoViewport(context),
                    const SizedBox(height: 8),
                    SubtitlesVideoControlsBar(controller: controller),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

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
                    Expanded(
                      child: Text(
                        'Video Player & Real-time Subtitle Sync Preview',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                color: AppColors.bgPage,
                child: Column(
                  children: [
                    _buildVideoViewport(context),
                    const SizedBox(height: 8),
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

  Widget _buildVideoViewport(BuildContext context) {
    return Center(
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
                Obx(() {
                  if (controller.isVideoPlayerInitialized.value &&
                      controller.videoPlayerController != null) {
                    return VideoPlayer(controller.videoPlayerController!);
                  }
                  return Column(
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
                  );
                }),

                // Subtitle Overlay Box
                Obx(() {
                  final activeIdx = controller.activeCueIndex.value;
                  if (activeIdx >= 0 &&
                      activeIdx < controller.currentCues.length) {
                    final text = controller.currentCues[activeIdx].text;
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
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
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
    );
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryCompact = constraints.maxWidth < 360;
              final isCompact = constraints.maxWidth < 480;

              final posStr = SubtitlesController.formatDurationToTimecode(pos)
                  .split('.')
                  .first;
              final durStr = SubtitlesController.formatDurationToTimecode(dur)
                  .split('.')
                  .first;

              return Row(
                children: [
                  // Play/Pause
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: controller.togglePlayPause,
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                    tooltip: isPlaying ? 'Pause' : 'Play',
                  ),
                  const SizedBox(width: 4),

                  // Skip -5s
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
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
                  const SizedBox(width: 4),

                  // Skip +5s
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
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
                  Flexible(
                    child: Text(
                      isVeryCompact ? posStr : '$posStr / $durStr',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Add Cue at Current Playhead
                  if (isCompact)
                    Tooltip(
                      message: 'Add cue at current playhead ($posStr)',
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        onPressed: controller.addCueAtCurrentTime,
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          size: 20,
                          color: AppColors.brand,
                        ),
                      ),
                    )
                  else
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
              );
            },
          ),
        ],
      );
    });
  }
}
