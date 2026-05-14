import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';

/// Production-grade, YouTube-style miniplayer widget.
///
/// Architecture:
///  - Uses `GetView<MiniplayerController>` with tag 'miniplayer'.
///  - Each UI section wraps only the *specific* Rx variable it depends on
///    in its own `Obx`, so a position update doesn't rebuild the title bar,
///    and a mode change doesn't rebuild the progress bar.
///  - Fully responsive: adapts width and layout for mobile / tablet / desktop.
///  - Supports drag-to-expand/collapse gestures.
class MiniplayerWidget extends GetView<MiniplayerController> {
  const MiniplayerWidget({super.key});

  @override
  String? get tag => 'miniplayer';

  // ── Theme shortcuts ──
  static const _bg = AppColors.bgPage;
  static const _card = AppColors.bgSurface;
  static const _crimson = AppColors.brand;
  static const _textPrimary = AppColors.textPrimary;
  static const _textSecondary = AppColors.textSecondary;
  static const _border = AppColors.bgDivider;

  @override
  Widget build(BuildContext context) {
    // Check if controller is registered - if not, render nothing
    if (!Get.isRegistered<MiniplayerController>(tag: 'miniplayer')) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      final currentMode = controller.mode.value;
      if (currentMode == MiniplayerMode.dismissed) {
        return const SizedBox.shrink();
      }

      return _MiniplayerPanel(controller: controller);
    });
  }
}

/// The actual floating panel. This is a separate StatelessWidget so
/// the top-level `Obx` only pays for mode changes.
class _MiniplayerPanel extends StatelessWidget {
  final MiniplayerController controller;
  const _MiniplayerPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Obx(() {
      final progress = controller.dragProgress.value;
      final mode = controller.mode.value;
      if (mode == MiniplayerMode.dismissed) return const SizedBox.shrink();

      // ── Layout interpolation ──
      final collapsedW = _collapsedWidth(screenSize.width);
      final collapsedH = MiniplayerConfig.collapsedHeight;
      final expandedW = screenSize.width;
      final expandedH = screenSize.height;

      final width = _lerp(collapsedW, expandedW, progress);
      final height = _lerp(collapsedH, expandedH, progress);
      final bottom = _lerp(16.0 + bottomPadding, 0.0, progress);
      final right = _lerp(16.0, 0.0, progress);
      final radius = _lerp(MiniplayerConfig.borderRadius, 0.0, progress);

      return Positioned(
        bottom: bottom,
        right: right,
        width: width,
        height: height,
        child: SafeArea(
          // Material provides InkWell/Theme context, Overlay provides Tooltip/Popup context
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: width,
              height: height,
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => GestureDetector(
                      onVerticalDragUpdate: (d) =>
                          controller.onDragUpdate(d.delta.dy, screenSize.height),
                      onVerticalDragEnd: (_) => controller.onDragEnd(),
                      child: AnimatedContainer(
                        duration: mode == MiniplayerMode.dragging
                            ? Duration.zero
                            : MiniplayerConfig.animationDuration,
                        curve: MiniplayerConfig.animationCurve,
                        width: width,
                        height: height,
                        decoration: BoxDecoration(
                          color: MiniplayerWidget._bg,
                          borderRadius: BorderRadius.circular(radius),
                          border: progress < 0.5
                              ? Border.all(
                                  color: MiniplayerWidget._border
                                      .withValues(alpha: 0.4),
                                  width: 1.0,
                                )
                              : null,
                          boxShadow: progress < 1.0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: MiniplayerConfig.elevation,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: progress < 0.15
                            ? _CollapsedLayout(controller: controller)
                            : _ExpandedLayout(
                                controller: controller, progress: progress),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  double _collapsedWidth(double screenWidth) {
    // Simple responsive width: 30% of screen width, clamped to reasonable range
    final targetWidth = screenWidth * MiniplayerConfig.collapsedWidthFraction;
    return targetWidth.clamp(
      MiniplayerConfig.minCollapsedWidth,
      MiniplayerConfig.maxCollapsedWidth,
    ).toDouble();
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;
}

// ═════════════════════════════════════════════════════════════════════════════
// COLLAPSED LAYOUT — slim bar with thumbnail, title, play/close
// ═════════════════════════════════════════════════════════════════════════════

class _CollapsedLayout extends StatelessWidget {
  final MiniplayerController controller;
  const _CollapsedLayout({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Progress bar (top edge) ──
        _MiniProgressBar(controller: controller),

        // ── Content row ──
        Expanded(
          child: InkWell(
            onTap: controller.expand,
            child: Row(
              children: [
                // Thumbnail (tap to expand)
                _CollapsedThumbnail(controller: controller),

                const SizedBox(width: 10),

                // Title + channel (tap to expand)
                Expanded(child: _CollapsedInfo(controller: controller)),

                // Play / Pause
                _PlayPauseButton(controller: controller, size: 20),

                const SizedBox(width: 4),

                // Close
                _IconBtn(
                  icon: Icons.close_rounded,
                  size: 18,
                  onTap: controller.dismiss,
                  tooltip: 'Close',
                ),

                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CollapsedThumbnail extends StatelessWidget {
  final MiniplayerController controller;
  const _CollapsedThumbnail({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final info = controller.videoInfo.value;
      final url = info?.thumbnailUrl ?? '';
      return SizedBox(
        width: MiniplayerConfig.collapsedHeight * 16 / 9,
        height: MiniplayerConfig.collapsedHeight,
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url.replaceAll(' ', '%20'),
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    Container(color: MiniplayerWidget._card),
                errorWidget: (_, _, _) => Container(
                  color: MiniplayerWidget._card,
                  child: const Icon(Icons.video_library_outlined,
                      color: MiniplayerWidget._textSecondary, size: 20),
                ),
              )
            : Container(
                color: MiniplayerWidget._card,
                child: const Icon(Icons.video_library_outlined,
                    color: MiniplayerWidget._textSecondary, size: 20),
              ),
      );
    });
  }
}

class _CollapsedInfo extends StatelessWidget {
  final MiniplayerController controller;
  const _CollapsedInfo({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final info = controller.videoInfo.value;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info?.title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.roboto(
              color: MiniplayerWidget._textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            info?.channelName ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.roboto(
              color: MiniplayerWidget._textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      );
    });
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EXPANDED LAYOUT — full player with controls
// ═════════════════════════════════════════════════════════════════════════════

class _ExpandedLayout extends StatelessWidget {
  final MiniplayerController controller;
  final double progress;
  const _ExpandedLayout({required this.controller, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Top bar (collapse handle + title) ──
        _ExpandedTopBar(controller: controller),

        // ── Video area ──
        Expanded(
          flex: 5,
          child: InkWell(
            onTap: controller.togglePlayPause,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail fallback
                _ExpandedThumbnail(controller: controller),

                // Actual video
                Obx(() {
                  if (controller.chewieController == null) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: MiniplayerWidget._crimson,
                        strokeWidth: 2.5,
                      ),
                    );
                  }
                  return AspectRatio(
                    aspectRatio:
                        controller.videoPlayerController!.value.aspectRatio,
                    child: VideoPlayer(controller.videoPlayerController!),
                  );
                }),

                // Play/Pause overlay
                _CenterPlayOverlay(controller: controller),

                // Buffering indicator
                Obx(() {
                  if (!controller.isBuffering.value) {
                    return const SizedBox.shrink();
                  }
                  return const Center(
                    child: CircularProgressIndicator(
                      color: MiniplayerWidget._crimson,
                      strokeWidth: 2.5,
                    ),
                  );
                }),

                // Error state overlay
                Obx(() {
                  final errorMsg = controller.error.value;
                  if (errorMsg.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    color: Colors.black.withValues(alpha: 0.8),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: MiniplayerWidget._crimson,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              errorMsg,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.roboto(
                                color: MiniplayerWidget._textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // ── Controls section ──
        Expanded(
          flex: 4,
          child: Container(
            color: MiniplayerWidget._bg,
            child: Column(
              children: [
                // Seek bar
                _SeekBar(controller: controller),

                const SizedBox(height: 8),

                // Playback controls
                _PlaybackControls(controller: controller),

                const SizedBox(height: 16),

                // Video info
                _ExpandedVideoInfo(controller: controller),

                const Spacer(),

                // Open full screen button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: controller.openFullScreen,
                      icon: const Icon(Icons.open_in_full_rounded, size: 18),
                      label: Text(
                        'Open Full Player',
                        style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: MiniplayerWidget._crimson.withValues(alpha: 0.6),
                        ),
                        foregroundColor: MiniplayerWidget._crimson,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpandedTopBar extends StatelessWidget {
  final MiniplayerController controller;
  const _ExpandedTopBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: MiniplayerWidget._bg,
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.keyboard_arrow_down_rounded,
            size: 28,
            onTap: controller.collapse,
            tooltip: 'Minimize',
          ),
          const Spacer(),
          _IconBtn(
            icon: Icons.close_rounded,
            size: 22,
            onTap: controller.dismiss,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _ExpandedThumbnail extends StatelessWidget {
  final MiniplayerController controller;
  const _ExpandedThumbnail({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final url = controller.videoInfo.value?.thumbnailUrl ?? '';
      if (url.isEmpty) {
        return Container(color: MiniplayerWidget._card);
      }
      return CachedNetworkImage(
        imageUrl: url.replaceAll(' ', '%20'),
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(color: MiniplayerWidget._card),
        errorWidget: (_, _, _) => Container(color: MiniplayerWidget._card),
      );
    });
  }
}

class _CenterPlayOverlay extends StatelessWidget {
  final MiniplayerController controller;
  const _CenterPlayOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final playing = controller.isPlaying.value;
      return AnimatedOpacity(
        opacity: playing ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
      );
    });
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED COMPONENTS
// ═════════════════════════════════════════════════════════════════════════════

/// Thin progress bar shown at the top of the collapsed miniplayer.
class _MiniProgressBar extends StatelessWidget {
  final MiniplayerController controller;
  const _MiniProgressBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pos = controller.currentPosition.value.inMilliseconds;
      final dur = controller.totalDuration.value.inMilliseconds;
      final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
      return SizedBox(
        height: 2.5,
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: MiniplayerWidget._border.withValues(alpha: 0.3),
          valueColor:
              const AlwaysStoppedAnimation<Color>(MiniplayerWidget._crimson),
          minHeight: 2.5,
        ),
      );
    });
  }
}

/// Full seek bar for expanded mode.
class _SeekBar extends StatelessWidget {
  final MiniplayerController controller;
  const _SeekBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pos = controller.currentPosition.value;
      final dur = controller.totalDuration.value;
      final posMs = pos.inMilliseconds.toDouble();
      final durMs = dur.inMilliseconds.toDouble();

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: MiniplayerWidget._crimson,
                inactiveTrackColor:
                    MiniplayerWidget._border.withValues(alpha: 0.3),
                thumbColor: MiniplayerWidget._crimson,
                overlayColor: MiniplayerWidget._crimson.withValues(alpha: 0.15),
              ),
              child: Slider(
                value: durMs > 0 ? posMs.clamp(0.0, durMs) : 0.0,
                max: durMs > 0 ? durMs : 1.0,
                onChanged: (val) {
                  controller.seekTo(Duration(milliseconds: val.toInt()));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    controller.formatDuration(pos),
                    style: GoogleFonts.robotoMono(
                      color: MiniplayerWidget._textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    controller.formatDuration(dur),
                    style: GoogleFonts.robotoMono(
                      color: MiniplayerWidget._textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Center playback controls row for expanded mode.
class _PlaybackControls extends StatelessWidget {
  final MiniplayerController controller;
  const _PlaybackControls({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _IconBtn(
          icon: Icons.replay_10_rounded,
          size: 28,
          onTap: controller.seekBackward,
          tooltip: 'Rewind 10s',
        ),
        const SizedBox(width: 24),
        _PlayPauseButton(controller: controller, size: 40, showBg: true),
        const SizedBox(width: 24),
        _IconBtn(
          icon: Icons.forward_10_rounded,
          size: 28,
          onTap: controller.seekForward,
          tooltip: 'Forward 10s',
        ),
      ],
    );
  }
}

class _ExpandedVideoInfo extends StatelessWidget {
  final MiniplayerController controller;
  const _ExpandedVideoInfo({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final info = controller.videoInfo.value;
      if (info == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                color: MiniplayerWidget._textPrimary,
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
              style: GoogleFonts.roboto(
                color: MiniplayerWidget._textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Play / Pause toggle button.
class _PlayPauseButton extends StatelessWidget {
  final MiniplayerController controller;
  final double size;
  final bool showBg;
  const _PlayPauseButton({
    required this.controller,
    this.size = 24,
    this.showBg = false,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final playing = controller.isPlaying.value;
      final icon = playing ? Icons.pause_rounded : Icons.play_arrow_rounded;

      if (showBg) {
        return InkWell(
          onTap: controller.togglePlayPause,
          child: Container(
            width: size + 20,
            height: size + 20,
            decoration: BoxDecoration(
              color: MiniplayerWidget._crimson,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: MiniplayerWidget._crimson.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: size),
          ),
        );
      }

      return _IconBtn(
        icon: icon,
        size: size,
        onTap: controller.togglePlayPause,
        tooltip: playing ? 'Pause' : 'Play',
      );
    });
  }
}

/// Minimal icon button with ink splash.
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final String tooltip;
  const _IconBtn({
    required this.icon,
    required this.size,
    required this.onTap,
    this.tooltip = '',
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: MiniplayerWidget._textPrimary, size: size),
          ),
        ),
      ),
    );
  }
}






