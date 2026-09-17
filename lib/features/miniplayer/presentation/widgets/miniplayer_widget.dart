import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

/// Production-grade YouTube-style floating miniplayer.
///
/// Mirrors YouTube web's miniplayer:
///   • A 16:9 video frame (~400px wide) plus a compact info row beneath.
///   • Overlay controls fade in on hover: expand (top-left), close (top-right),
///     center play/pause.
///   • Thin progress bar at the bottom of the video frame.
///   • The whole card is draggable anywhere in the viewport (pointer-drag on
///     the header strip or the title row).
///   • Keyboard shortcut: `I` to expand to the full video screen, `Esc` to
///     close the expanded mode.
///   • A separate full-screen expanded mode is used for one-tap dive in.
class MiniplayerWidget extends StatelessWidget {
  const MiniplayerWidget({super.key});

  // Theme tokens
  static const Color _bg = AppColors.bgPage;
  static const Color _card = AppColors.bgSurface;
  static const Color _brand = AppColors.brand;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;
  static const Color _border = AppColors.bgDivider;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final controller = MiniplayerController.to;
      final mode = controller.mode.value;
      if (mode == MiniplayerMode.dismissed) return const SizedBox.shrink();

      return LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (mode == MiniplayerMode.expanded) {
            return _ExpandedView(controller: controller, screenSize: size);
          }
          return _FloatingCard(controller: controller, screenSize: size);
        },
      );
    });
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FLOATING CARD — the YouTube-style miniplayer
// ═════════════════════════════════════════════════════════════════════════════

class _FloatingCard extends StatelessWidget {
  const _FloatingCard({required this.controller, required this.screenSize});
  final MiniplayerController controller;
  final Size screenSize;

  @override
  Widget build(BuildContext context) {
    final isMobile = MiniplayerConfig.isMobileLayout(screenSize.width);
    final width = MiniplayerConfig.widthForScreen(screenSize.width);
    final height =
        MiniplayerConfig.heightForWidth(width, isMobile: isMobile) +
        2.0; // Account for top/bottom borders
    final cardSize = Size(width, height);

    final cardContent = SizedBox(
      width: width,
      height: height,
      child: FocusableActionDetector(
        shortcuts: <ShortcutActivator, Intent>{
          LogicalKeySet(LogicalKeyboardKey.keyI): const _ExpandIntent(),
          LogicalKeySet(LogicalKeyboardKey.escape):
              const _DismissIntent(),
        },
        actions: <Type, Action<Intent>>{
          _ExpandIntent: CallbackAction<_ExpandIntent>(
            onInvoke: (_) {
              controller.openFullScreen();
              return null;
            },
          ),
          _DismissIntent: CallbackAction<_DismissIntent>(
            onInvoke: (_) {
              controller.dismiss();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          onEnter: (_) => controller.setHovering(true),
          onExit: (_) => controller.setHovering(false),
          child: _CardBody(
            controller: controller,
            cardSize: cardSize,
            screenSize: screenSize,
          ),
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Obx(() {
          final pos = controller.effectiveOffset(cardSize, screenSize);
          return Positioned(
            left: pos.dx,
            top: pos.dy,
            width: width,
            height: height,
            child: cardContent,
          );
        }),
      ],
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.controller,
    required this.cardSize,
    required this.screenSize,
  });
  final MiniplayerController controller;
  final Size cardSize;
  final Size screenSize;

  @override
  Widget build(BuildContext context) {
    final isMobile = MiniplayerConfig.isMobileLayout(screenSize.width);
    final videoHeight = isMobile
        ? (cardSize.height - 2.0)
        : (cardSize.width / MiniplayerConfig.videoAspectRatio);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: MiniplayerWidget._bg,
          borderRadius: BorderRadius.circular(MiniplayerConfig.borderRadius),
          border: Border.all(
            color: MiniplayerWidget._border.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.bgPage.withValues(alpha: 0.55),
              blurRadius: MiniplayerConfig.elevation,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: cardSize.width,
              height: videoHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) =>
                    controller.onPanCard(d.delta, cardSize, screenSize),
                onTap: controller.openFullScreen,
                child: _VideoFrame(
                  controller: controller,
                  isMobile: isMobile,
                ),
              ),
            ),
            if (!isMobile)
              _InfoBar(
                controller: controller,
                cardSize: cardSize,
                screenSize: screenSize,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Video frame with overlay controls + progress bar
// ─────────────────────────────────────────────────────────────────────────────

class _VideoFrame extends StatelessWidget {
  const _VideoFrame({
    required this.controller,
    this.isMobile = false,
  });
  final MiniplayerController controller;
  final bool isMobile;

  Widget _buildMobileControls() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Subtle vignette
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.bgPage.withValues(alpha: 0.40),
                  Colors.transparent,
                  AppColors.bgPage.withValues(alpha: 0.30),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // Tap area to open full screen
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: controller.openFullScreen,
          ),
        ),

        // Left / Top-left: Play / Pause circular button
        Positioned(
          top: 8,
          left: 8,
          child: Obx(() {
            final playing = controller.isPlaying.value;
            return Material(
              color: AppColors.bgPage.withValues(alpha: 0.65),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: controller.togglePlayPause,
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }),
        ),

        // Right / Top-right: Close circular button
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: AppColors.bgPage.withValues(alpha: 0.65),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: controller.dismiss,
              child: const Padding(
                padding: EdgeInsets.all(7),
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopControls() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Subtle vignette so icons stay legible.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.bgPage.withValues(alpha: 0.35),
                  Colors.transparent,
                  AppColors.bgPage.withValues(alpha: 0.25),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // Top-left: Expand button + "I" hotkey hint.
        Positioned(
          top: 6,
          left: 6,
          child: _ExpandButton(controller: controller),
        ),

        // Top-right: Close and CC buttons.
        Positioned(
          top: 6,
          right: 6,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(() {
                final enabled = controller.subtitlesEnabled.value;
                return _OverlayIconButton(
                  icon: enabled
                      ? Icons.subtitles_rounded
                      : Icons.subtitles_outlined,
                  tooltip: 'Subtitles (CC)',
                  onTap: controller.toggleSubtitles,
                );
              }),
              const SizedBox(width: 6),
              _OverlayIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Close (Esc)',
                onTap: controller.dismiss,
              ),
            ],
          ),
        ),

        // Center: Play / Pause.
        Center(
          child: _CenterPlayButton(controller: controller),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail fallback (always behind the video).
        Obx(() {
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
        }),

        // Actual video.
        Obx(() {
          final isReady = controller.isVideoReady.value;
          final vpc = controller.videoPlayerController;
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
          return FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: w,
              height: h,
              child: VideoPlayer(vpc),
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
                color: MiniplayerWidget._brand,
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
                      color: MiniplayerWidget._textPrimary,
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
                        color: MiniplayerWidget._card,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: MiniplayerWidget._border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            color: MiniplayerWidget._textPrimary,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Retry',
                            style: TextStyle(
                              color: MiniplayerWidget._textPrimary,
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

        // Overlay controls — fade in on hover, when paused, or on mobile tap.
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
              child: isMobile ? _buildMobileControls() : _buildDesktopControls(),
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
          child: _VideoProgressBar(controller: controller),
        ),
      ],
    );
  }
}

class _ExpandButton extends StatelessWidget {
  const _ExpandButton({required this.controller});
  final MiniplayerController controller;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Expand (I)',
      child: Material(
        color: AppColors.bgPage.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: controller.openFullScreen,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.open_in_full_rounded,
                  size: 14,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Expand',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'I',
                    style: GoogleFonts.robotoMono(
                      color: AppColors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
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

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 18,
  }) : iconColor = AppColors.textPrimary;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.bgPage.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: size, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _CenterPlayButton extends StatelessWidget {
  const _CenterPlayButton({required this.controller});
  final MiniplayerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.error.value.isNotEmpty) return const SizedBox.shrink();
      final playing = controller.isPlaying.value;
      return Material(
        color: AppColors.bgPage.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: controller.togglePlayPause,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 32,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      );
    });
  }
}

class _VideoProgressBar extends StatelessWidget {
  _VideoProgressBar({required this.controller});
  final MiniplayerController controller;

  final RxBool _isDragging = false.obs;
  final RxnDouble _dragRatio = RxnDouble();

  void _updateSeek(Offset localPosition, double width) {
    if (width <= 0) return;
    final ratio = (localPosition.dx / width).clamp(0.0, 1.0);
    _dragRatio.value = ratio;
    controller.seekToRatio(ratio);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            _updateSeek(details.localPosition, width);
          },
          onHorizontalDragStart: (details) {
            _isDragging.value = true;
            _updateSeek(details.localPosition, width);
          },
          onHorizontalDragUpdate: (details) {
            _updateSeek(details.localPosition, width);
          },
          onHorizontalDragEnd: (details) {
            _isDragging.value = false;
            _dragRatio.value = null;
          },
          onHorizontalDragCancel: () {
            _isDragging.value = false;
            _dragRatio.value = null;
          },
          child: Container(
            height: 18,
            color: Colors.transparent,
            alignment: Alignment.bottomCenter,
            child: Obx(() {
              final pos =
                  controller.currentPosition.value.inMilliseconds;
              final dur = controller.totalDuration.value.inMilliseconds;
              final actualValue = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
              final isDraggingVal = _isDragging.value;
              final dragRatioVal = _dragRatio.value;
              final value = isDraggingVal && dragRatioVal != null
                  ? dragRatioVal
                  : actualValue;
              final barHeight = isDraggingVal ? 6.0 : 4.0;

              return SizedBox(
                height: barHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: width,
                      height: barHeight,
                      color: AppColors.textPrimary.withValues(alpha: 0.25),
                    ),
                    Container(
                      width: width * value,
                      height: barHeight,
                      color: AppColors.error,
                    ),
                    if (isDraggingVal)
                      Positioned(
                        left: (width * value - 5).clamp(0.0, width - 10),
                        top: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.textPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info bar beneath the video (title, channel + time, play/pause, close, expand)
// ─────────────────────────────────────────────────────────────────────────────

class _InfoBar extends StatelessWidget {
  const _InfoBar({
    required this.controller,
    required this.cardSize,
    required this.screenSize,
  });
  final MiniplayerController controller;
  final Size cardSize;
  final Size screenSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MiniplayerConfig.infoBarHeight,
      child: Material(
        color: MiniplayerWidget._bg,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanUpdate: (d) =>
              controller.onPanCard(d.delta, cardSize, screenSize),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: controller.openFullScreen,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _TitleAndMeta(controller: controller),
                    ),
                  ),
                ),
                Obx(() {
                  final playing = controller.isPlaying.value;
                  return _OverlayIconButton(
                    icon: playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    tooltip: playing ? 'Pause' : 'Play',
                    size: 20,
                    onTap: controller.togglePlayPause,
                  );
                }),
                const SizedBox(width: 4),
                _OverlayIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onTap: controller.dismiss,
                ),
                const SizedBox(width: 4),
                _OverlayIconButton(
                  icon: Icons.open_in_full_rounded,
                  tooltip: 'Expand',
                  onTap: controller.openFullScreen,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleAndMeta extends StatelessWidget {
  const _TitleAndMeta({required this.controller});
  final MiniplayerController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Obx(() {
          final info = controller.videoInfo.value;
          return Text(
            info?.title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: MiniplayerWidget._textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          );
        }),
        const SizedBox(height: 2),
        Obx(() {
          final info = controller.videoInfo.value;
          final pos = controller.formatDuration(
            controller.currentPosition.value,
          );
          final dur = controller.formatDuration(controller.totalDuration.value);
          return Text(
            '${info?.channelName ?? ''}  •  $pos / $dur',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: MiniplayerWidget._textSecondary,
              fontSize: 11,
              height: 1.2,
            ),
          );
        }),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EXPANDED VIEW — full-screen player surface with controls
// ═════════════════════════════════════════════════════════════════════════════

class _ExpandedView extends StatelessWidget {
  const _ExpandedView({required this.controller, required this.screenSize});
  final MiniplayerController controller;
  final Size screenSize;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: FocusableActionDetector(
        autofocus: true,
        shortcuts: <ShortcutActivator, Intent>{
          LogicalKeySet(LogicalKeyboardKey.escape): const _CollapseIntent(),
          LogicalKeySet(LogicalKeyboardKey.space): const _TogglePlayIntent(),
          LogicalKeySet(LogicalKeyboardKey.keyK): const _TogglePlayIntent(),
          LogicalKeySet(LogicalKeyboardKey.keyJ): const _SeekBackwardIntent(),
          LogicalKeySet(LogicalKeyboardKey.keyL): const _SeekForwardIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _SeekBackwardIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowRight): const _SeekForwardIntent(),
        },
        actions: <Type, Action<Intent>>{
          _CollapseIntent: CallbackAction<_CollapseIntent>(
            onInvoke: (_) {
              controller.collapse();
              return null;
            },
          ),
          _TogglePlayIntent: CallbackAction<_TogglePlayIntent>(
            onInvoke: (_) {
              controller.togglePlayPause();
              return null;
            },
          ),
          _SeekBackwardIntent: CallbackAction<_SeekBackwardIntent>(
            onInvoke: (_) {
              controller.seekBackward();
              return null;
            },
          ),
          _SeekForwardIntent: CallbackAction<_SeekForwardIntent>(
            onInvoke: (_) {
              controller.seekForward();
              return null;
            },
          ),
        },
        child: Material(
          color: AppColors.bgPage,
          child: SafeArea(
            child: Column(
              children: [
                _ExpandedTopBar(controller: controller),
                Expanded(
                  flex: 5,
                  child: _ExpandedVideo(controller: controller),
                ),
                Expanded(
                  flex: 3,
                  child: _ExpandedDetails(controller: controller),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedTopBar extends StatelessWidget {
  const _ExpandedTopBar({required this.controller});
  final MiniplayerController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: MiniplayerWidget._bg,
      child: Row(
        children: [
          Tooltip(
            message: 'Minimize',
            child: IconButton(
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: MiniplayerWidget._textPrimary,
              ),
              onPressed: controller.collapse,
            ),
          ),
          const Spacer(),
          Obx(() {
            final enabled = controller.subtitlesEnabled.value;
            return Tooltip(
              message: 'Subtitles (CC)',
              child: IconButton(
                icon: Icon(
                  enabled ? Icons.subtitles_rounded : Icons.subtitles_outlined,
                  color: MiniplayerWidget._textPrimary,
                  size: 20,
                ),
                onPressed: controller.toggleSubtitles,
              ),
            );
          }),
          Tooltip(
            message: 'Open full screen',
            child: IconButton(
              icon: const Icon(
                Icons.open_in_full_rounded,
                color: MiniplayerWidget._textPrimary,
                size: 20,
              ),
              onPressed: controller.openFullScreen,
            ),
          ),
          Tooltip(
            message: 'Close',
            child: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: MiniplayerWidget._textPrimary,
              ),
              onPressed: controller.dismiss,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedVideo extends StatelessWidget {
  const _ExpandedVideo({required this.controller});
  final MiniplayerController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = constraints.maxWidth / 2;
        var doubleTapX = 0.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: controller.togglePlayPause,
          onDoubleTapDown: (details) => doubleTapX = details.localPosition.dx,
          onDoubleTap: () {
            if (doubleTapX < half) {
              controller.seekBackward();
            } else {
              controller.seekForward();
            }
          },
          child: Container(
            color: AppColors.bgPage,
            alignment: Alignment.center,
            child: Stack(
              fit: StackFit.expand,
              children: [
            Obx(() {
              final url = controller.videoInfo.value?.thumbnailUrl ?? '';
              if (url.isEmpty) return const SizedBox.shrink();
              return CachedNetworkImage(
                imageUrl: url.replaceAll(' ', '%20'),
                fit: BoxFit.contain,
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              );
            }),
            Obx(() {
              final isReady = controller.isVideoReady.value;
              final vpc = controller.videoPlayerController;
              final hasErr = controller.error.value.isNotEmpty;
              if (hasErr) return const SizedBox.shrink();
              if (vpc == null || !isReady) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: MiniplayerWidget._brand,
                    strokeWidth: 2.5,
                  ),
                );
              }
              return Center(
                child: AspectRatio(
                  aspectRatio: vpc.value.aspectRatio,
                  child: VideoPlayer(vpc),
                ),
              );
            }),
            Obx(() {
              if (controller.isPlaying.value ||
                  controller.error.value.isNotEmpty) {
                return const SizedBox.shrink();
              }
              return const Center(
                child: Icon(
                  Icons.play_circle_rounded,
                  color: AppColors.textPrimary,
                  size: 72,
                ),
              );
            }),
            Obx(() {
              final msg = controller.error.value;
              if (msg.isEmpty) return const SizedBox.shrink();
              return Container(
                color: AppColors.bgPage.withValues(alpha: 0.88),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: MiniplayerWidget._textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: controller.attemptRecovery,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: MiniplayerWidget._card,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: MiniplayerWidget._border.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                color: MiniplayerWidget._textPrimary,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Retry',
                                style: TextStyle(
                                  color: MiniplayerWidget._textPrimary,
                                  fontSize: 12,
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
            Obx(() {
              if (!controller.subtitlesEnabled.value) {
                return const SizedBox.shrink();
              }
              final text = controller.currentSubtitle.value;
              if (text.isEmpty) return const SizedBox.shrink();
              return Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
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
      },
    );
  }
}

class _ExpandedDetails extends StatelessWidget {
  const _ExpandedDetails({required this.controller});
  final MiniplayerController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MiniplayerWidget._bg,
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
                inactiveTrackColor: MiniplayerWidget._border.withValues(
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
                      color: MiniplayerWidget._textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    dur,
                    style: GoogleFonts.robotoMono(
                      color: MiniplayerWidget._textSecondary,
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
                  color: MiniplayerWidget._textPrimary,
                  size: 28,
                ),
                onPressed: controller.seekBackward,
              ),
              const SizedBox(width: 16),
              Obx(() {
                final playing = controller.isPlaying.value;
                return Material(
                  color: MiniplayerWidget._brand,
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
                  color: MiniplayerWidget._textPrimary,
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
                  style: const TextStyle(
                    color: MiniplayerWidget._textSecondary,
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

// ─────────────────────────────────────────────────────────────────────────────
// Keyboard intents
// ─────────────────────────────────────────────────────────────────────────────

class _ExpandIntent extends Intent {
  const _ExpandIntent();
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}

class _CollapseIntent extends Intent {
  const _CollapseIntent();
}

class _TogglePlayIntent extends Intent {
  const _TogglePlayIntent();
}

class _SeekBackwardIntent extends Intent {
  const _SeekBackwardIntent();
}

class _SeekForwardIntent extends Intent {
  const _SeekForwardIntent();
}
