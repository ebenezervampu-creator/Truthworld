import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_badges.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_controls_buttons.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_volume_and_time.dart';

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

  @override
  Widget build(BuildContext context) {
    final isMobileDevice =
        Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS;

    if (isMobileDevice) {
      return Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TimeDisplay(ctrl: ctrl),
            ),
          ),
          Obx(
            () => Tooltip(
              message: ctrl.subtitlesEnabled.value
                  ? 'Subtitles (on)'
                  : 'Subtitles (off)',
              child: IconBtn(
                icon: ctrl.subtitlesEnabled.value
                    ? Icons.closed_caption_rounded
                    : Icons.closed_caption_outlined,
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
          Tooltip(
            message: 'Settings',
            child: IconBtn(
              icon: Icons.settings_outlined,
              onTap: () => ctrl.openSettings(context),
            ),
          ),
          Obx(
            () => Tooltip(
              message: ctrl.isFullScreen.value
                  ? 'Exit full screen (f)'
                  : 'Full screen (f)',
              child: IconBtn(
                icon: ctrl.isFullScreen.value
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                onTap: ctrl.toggleFullscreen,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        // Left cluster — hide on narrow
        if (!isNarrow && !isMedium) ...[
          Obx(
            () => IconBtn(
              icon: ctrl.isPlaying.value
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              onTap: ctrl.togglePlayPause,
            ),
          ),
          Obx(
            () {
              ctrl.isAudioOnly.value;
              return Opacity(
                opacity: ctrl.hasPreviousVideo ? 1.0 : 0.3,
                child: IconBtn(
                  icon: Icons.skip_previous_rounded,
                  onTap: ctrl.hasPreviousVideo ? ctrl.playPrevious : null,
                ),
              );
            },
          ),
          Obx(
            () {
              ctrl.isAudioOnly.value;
              return Opacity(
                opacity: ctrl.hasNextVideo ? 1.0 : 0.3,
                child: IconBtn(
                  icon: Icons.skip_next_rounded,
                  onTap: ctrl.hasNextVideo ? ctrl.playNext : null,
                ),
              );
            },
          ),
          VolumeControl(ctrl: ctrl),
        ] else if (isMedium) ...[
          Obx(() => IconBtn(icon: ctrl.volumeIcon, onTap: ctrl.toggleMute)),
        ],

        // Time display & chapters
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: TimeDisplay(ctrl: ctrl),
          ),
        ),

        // Right cluster
        if (!isNarrow) AbrBadge(ctrl: ctrl),

        // CC / Subtitles (always present alongside Settings)
        Obx(
          () => Tooltip(
            message: ctrl.subtitlesEnabled.value
                ? 'Subtitles (on)'
                : 'Subtitles (off)',
            child: IconBtn(
              icon: ctrl.subtitlesEnabled.value
                  ? Icons.closed_caption_rounded
                  : Icons.closed_caption_outlined,
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

        // Audio Only
        Obx(
          () => Tooltip(
            message: ctrl.isAudioOnly.value ? 'Audio only (on)' : 'Audio only',
            child: IconBtn(
              icon: ctrl.isAudioOnly.value
                  ? Icons.music_note_rounded
                  : Icons.music_note_outlined,
              onTap: () {
                String? url;
                String? title;
                String? art;
                try {
                  if (ctrl.tag != null &&
                      Get.isRegistered<VideoController>(tag: ctrl.tag)) {
                    final vc = Get.find<VideoController>(tag: ctrl.tag);
                    url = vc.currentResolution.value?.url;
                    title = vc.video.title;
                    art = vc.video.thumbnailUrl;
                  }
                } catch (e, stackTrace) {
                  ErrorHandler.log(
                    e,
                    stackTrace: stackTrace,
                    tag: 'PlayerControls.toggleAudioOnly.findVideo',
                  );
                }
                ctrl.toggleAudioOnly(
                  videoUrl: url,
                  title: title,
                  artworkUrl: art,
                );
              },
            ),
          ),
        ),

        // Settings
        Tooltip(
          message: 'Settings',
          child: IconBtn(
            icon: Icons.settings_outlined,
            onTap: () => ctrl.openSettings(context),
          ),
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
              onTap: ctrl.toggleFullscreen,
            ),
          ),
        ),
      ],
    );
  }
}
