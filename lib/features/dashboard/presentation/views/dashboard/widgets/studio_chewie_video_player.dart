import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/audio_track_models.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/studio_chewie_video_player_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Production Chewie video player embedded inside TruthWorld Studio video track cards.
///
/// Features:
///   • Never plays video in raw — plays using processed adaptive resolutions (1080p, 720p, 480p, etc.).
///   • Full native Chewie player controls (play/pause, seek scrubber, duration, fullscreen, volume).
///   • Dynamic resolution switcher bar allowing instant inspection across all OTT resolution tiers.
///   • Zero white-on-white accessibility compliance.
///   • Zero setState declarative GetX architecture.
class StudioChewieVideoPlayer extends StatelessWidget {
  const StudioChewieVideoPlayer({
    required this.video,
    required this.track,
    required this.tag,
    this.onClosePlayer,
    super.key,
  });

  final Video video;
  final VideoTrackItem track;
  final String tag;
  final VoidCallback? onClosePlayer;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      StudioChewieVideoPlayerController(
        video: video,
        track: track,
      ),
      tag: tag,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Main Video Player Viewport ──────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Obx(() {
                    if (controller.isLoading.value) {
                      return const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      );
                    }

                    if (controller.errorMessage.value != null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.white70,
                                size: 36,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                controller.errorMessage.value!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: controller.retry,
                                    icon: const Icon(Icons.refresh_rounded, color: Colors.black, size: 16),
                                    label: const Text(
                                      'Retry',
                                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    ),
                                  ),
                                  if (onClosePlayer != null) ...[
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: onClosePlayer,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                        side: const BorderSide(color: AppColors.bgElevated),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (controller.chewieController != null) {
                      return Chewie(controller: controller.chewieController!);
                    }

                    return const SizedBox.shrink();
                  }),

                  // Close button overlay in top-right
                  if (onClosePlayer != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onClosePlayer,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Switching resolution spinner overlay
                  Obx(() {
                    if (controller.isSwitchingResolution.value) {
                      return const ColoredBox(
                        color: Colors.black45,
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ],
              ),
            ),
          ),
        ),

        // ── Resolution Selection Ladder Bar ─────────────────────────────────────
        Obx(() {
          final resList = controller.availableResolutions;
          if (resList.length <= 1) return const SizedBox.shrink();

          final current = controller.currentResolution.value;

          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.bgSurface),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Resolutions:',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...resList.map((res) {
                    final isSelected = current?.label == res.label || current?.url == res.url;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => controller.switchResolution(res),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : AppColors.bgSurface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            res.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
