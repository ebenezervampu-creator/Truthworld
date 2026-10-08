import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/components/miniplayer_audio_stage.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/components/miniplayer_overlay_controls.dart';
import 'package:truthworld/features/miniplayer/presentation/widgets/components/miniplayer_video_progress_bar.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

/// Video display frame with embedded overlay controls, subtitles, audio-only stage, and progress bar.
class MiniplayerVideoFrame extends StatelessWidget {
  final MiniplayerController controller;
  final bool isMobile;

  const MiniplayerVideoFrame({
    required this.controller,
    this.isMobile = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail fallback (always behind the video).
        Obx(() {
          final url = controller.videoInfo.value?.thumbnailUrl ?? '';
          if (url.isEmpty) {
            return Container(color: AppColors.bgSurface);
          }
          return CachedNetworkImage(
            imageUrl: url.replaceAll(' ', '%20'),
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(color: AppColors.bgSurface),
            errorWidget: (_, _, _) => Container(color: AppColors.bgSurface),
          );
        }),

        // Audio-Only Stage (when audio mode is active)
        Obx(() {
          final isAudio = controller.isAudioOnly.value;
          if (!isAudio) return const SizedBox.shrink();
          final isPlaying = controller.isPlaying.value;
          final thumb = controller.videoInfo.value?.thumbnailUrl ?? '';
          return MiniplayerAudioStage(
            controller: controller,
            isPlaying: isPlaying,
            thumbnailUrl: thumb,
          );
        }),

        // Actual video playback (kept offstage when in audio-only mode to maintain audio decoding).
        Obx(() {
          final isReady = controller.isVideoReady.value;
          final vpc = controller.videoPlayerController;
          final isAudio = controller.isAudioOnly.value;
          if (vpc == null || !isReady) {
            return const SizedBox.shrink();
          }
          double w = 16;
          double h = 9;
          try {
            w = vpc.value.size.width;
            h = vpc.value.size.height;
          } catch (e, s) {
            ErrorHandler.log(
              e,
              stackTrace: s,
              tag: 'MiniplayerWidget.getVideoSize',
            );
          }
          if (w <= 0) w = 16;
          if (h <= 0) h = 9;

          return Offstage(
            offstage: isAudio,
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: w,
                height: h,
                child: VideoPlayer(vpc),
              ),
            ),
          );
        }),

        // Clip Mode Indicator Pill (top-left)
        Obx(() {
          final clip = controller.activeClip.value;
          if (clip == null) return const SizedBox.shrink();
          return Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.brand.withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
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
                    'CLIP',
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        // Buffering spinner.
        Obx(() {
          if (!controller.isBuffering.value) return const SizedBox.shrink();
          return const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: AppColors.brand,
                strokeWidth: 2.5,
              ),
            ),
          );
        }),

        // Error state.
        Obx(() {
          final msg = controller.error.value;
          if (msg.isEmpty) return const SizedBox.shrink();
          return Container(
            color: AppColors.bgPage.withValues(alpha: 0.88),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: controller.attemptRecovery,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.bgDivider.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            color: AppColors.textPrimary,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Retry',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        // Overlay controls:
        // On mobile viewports, mobile controls (pause, close, expand) are directly rendered.
        // On desktop, overlay controls fade in on hover, when paused, or on key triggers.
        if (isMobile)
          MiniplayerMobileControls(controller: controller)
        else
          Obx(() {
            final showOverlay =
                controller.isHovering.value ||
                !controller.isPlaying.value ||
                controller.showMobileControls.value;
            return AnimatedOpacity(
              opacity: showOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !showOverlay,
                child: MiniplayerDesktopControls(controller: controller),
              ),
            );
          }),

        // Subtitles Overlay in Miniplayer
        Obx(() {
          if (!controller.subtitlesEnabled.value) {
            return const SizedBox.shrink();
          }
          final text = controller.currentSubtitle.value;
          if (text.isEmpty) return const SizedBox.shrink();
          return Positioned(
            bottom: 12,
            left: 8,
            right: 8,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),

        // Thin progress bar at the bottom of the video.
        Align(
          alignment: Alignment.bottomCenter,
          child: MiniplayerVideoProgressBar(controller: controller),
        ),
      ],
    );
  }
}
