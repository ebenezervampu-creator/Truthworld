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
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                // ── Left Group: Play/Pause, Volume, Time ──────────────────────────────
                Expanded(
                  child: Row(
                    children: [
                      Obx(() {
                        final isFinished = (ctrl.vv.position >= ctrl.vv.duration) &&
                            ctrl.vv.duration.inSeconds > 0;
                        final playIcon = isFinished
                            ? Icons.replay_rounded
                            : (ctrl.isPlaying.value
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded);
                        final playTip = isFinished
                            ? 'Replay (k)'
                            : (ctrl.isPlaying.value ? 'Pause (k)' : 'Play (k)');

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
                          icon: playIcon,
                          size: 22,
                          tooltip: playTip,
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
                            final hasCaptions = ctrl.subtitleTracks.isNotEmpty ||
                                ctrl.subtitleSegments.isNotEmpty ||
                                (ctrl.videoController?.transcriptSegments.isNotEmpty ?? false);
                            if (!hasCaptions) {
                              ctrl.showToast('No captions available for this video');
                              return;
                            }
                            if (ctrl.subtitlesEnabled.value) {
                              ctrl.setSubtitles(enabled: false);
                            } else {
                              final track = ctrl.subtitleTracks.isNotEmpty
                                  ? ctrl.subtitleTracks.first
                                  : null;
                              ctrl.setSubtitles(
                                enabled: true,
                                track: track,
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
            ),

            // ── Center: "More videos" pill in fullscreen situated after the progress bar ──
            Obx(() {
              final showPill = ctrl.isFullScreen.value &&
                  !ctrl.showMoreVideos.value &&
                  constraints.maxWidth >= 380;
              if (!showPill) return const SizedBox.shrink();

              return Center(
                child: MoreVideosPill(ctrl: ctrl),
              );
            }),
          ],
        );
      },
    );
  }
}

/// Jio Hotstar style "More videos" trigger pill situated in the horizontal center
/// of the bottom controls row, directly after the progress bar.
class MoreVideosPill extends StatelessWidget {
  const MoreVideosPill({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'More videos',
      hint: 'Swipe up or tap to open recommended videos',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            ctrl.cancelPendingTap();
            ctrl.openMoreVideos();
          },
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! < -100) {
              ctrl.openMoreVideos();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 4),
                Text(
                  'More videos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
