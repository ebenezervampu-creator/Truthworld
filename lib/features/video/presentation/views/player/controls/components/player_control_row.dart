// ignore: implementation_imports
import 'package:chewie/src/animated_play_pause.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_controls_buttons.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_volume_and_time.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Minimal, restructured bottom controls row for TruthWorld player.
/// Left: Play/Pause, Volume slider, Timestamp.
/// Center: Clean open space.
/// Right: Subtitles (CC), Settings, and Modern Minimal Fullscreen.
class ControlRow extends StatelessWidget {
  const ControlRow({
    required this.ctrl,
    required this.isNarrow,
    required this.isMedium,
    super.key,
  });

  final TowerPlayerController ctrl;
  final bool isNarrow;
  final bool isMedium;

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
      if (screenWidth < 600 || isNarrow) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Left Group: Play/Pause, Volume, Time ──────────────────────────────
        Expanded(
          child: Row(
            children: [
              Obx(() {
                if (_useChewieMobileButtons(context)) {
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: ctrl.togglePlayPause,
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: AnimatedPlayPause(
                          color: AppColors.textPrimary,
                          size: 22,
                          playing: ctrl.isPlaying.value,
                        ),
                      ),
                    ),
                  );
                }
                return IconBtn(
                  icon: ctrl.isPlaying.value
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 22,
                  onTap: ctrl.togglePlayPause,
                );
              }),
              if (!isNarrow) ...[
                VolumeControl(ctrl: ctrl),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: TimeDisplay(ctrl: ctrl),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // ── Right Group: CC, Settings, Fullscreen ─────────────────────────────
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // CC / Subtitles
            Obx(
              () => Tooltip(
                message: ctrl.subtitlesEnabled.value
                    ? 'Subtitles (on)'
                    : 'Subtitles (off)',
                child: IconBtn(
                  icon: ctrl.subtitlesEnabled.value
                      ? Icons.closed_caption_rounded
                      : Icons.closed_caption_outlined,
                  size: 21,
                  onTap: () {
                    if (ctrl.subtitleTracks.isEmpty) {
                      ctrl.showToast('No captions available for this video');
                      return;
                    }
                    if (ctrl.subtitlesEnabled.value) {
                      ctrl.setSubtitles(enabled: false);
                    } else {
                      ctrl.setSubtitles(
                        enabled: true,
                        track: ctrl.subtitleTracks.first,
                      );
                    }
                  },
                ),
              ),
            ),

            // Settings
            Tooltip(
              message: 'Settings',
              child: IconBtn(
                icon: Icons.settings_outlined,
                size: 20,
                onTap: () => ctrl.openSettings(context),
              ),
            ),

            // Picture-in-Picture (PiP)
            if (!isNarrow)
              Tooltip(
                message: 'Picture in picture (p)',
                child: IconBtn(
                  icon: Icons.picture_in_picture_alt_rounded,
                  size: 20,
                  onTap: ctrl.togglePiP,
                ),
              ),

            // Theater Mode (Desktop)
            if (!isNarrow && !isMedium)
              Obx(
                () => Tooltip(
                  message: ctrl.isTheaterMode.value
                      ? 'Default view (t)'
                      : 'Theater mode (t)',
                  child: IconBtn(
                    icon: ctrl.isTheaterMode.value
                        ? Icons.branding_watermark_rounded
                        : Icons.rectangle_outlined,
                    size: 20,
                    onTap: ctrl.toggleTheaterMode,
                  ),
                ),
              ),

            // More videos (fullscreen recommended overlay)
            Obx(
              () => ctrl.isFullScreen.value
                  ? Tooltip(
                      message: 'More videos',
                      child: IconBtn(
                        icon: ctrl.showMoreVideos.value
                            ? Icons.video_collection_rounded
                            : Icons.video_collection_outlined,
                        size: 20,
                        onTap: ctrl.toggleMoreVideos,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Fullscreen
            Obx(
              () => Tooltip(
                message: ctrl.isFullScreen.value
                    ? 'Exit full screen (f)'
                    : 'Full screen (f)',
                child: IconBtn(
                  icon: ctrl.isFullScreen.value
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  size: 22,
                  onTap: ctrl.toggleFullscreen,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
