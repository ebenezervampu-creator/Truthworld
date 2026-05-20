import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/miniplayer/data/models/miniplayer_model.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';

/// Production-grade TruthWorld-style floating miniplayer.
///
/// Mirrors TruthWorld web's miniplayer:
///   • A 16:9 video frame (~400px wide) plus a compact info row beneath.
///   • Overlay controls fade in on hover: expand (top-left), close (top-right),
///     center play/pause.
///   • Thin progress bar at the bottom of the video frame.
///   • The whole card is draggable anywhere in the viewport (pointer-drag on
///     the header strip or the title row).
///   • Keyboard shortcut: `I` to expand to the full video screen, `Esc` to
///     close the expanded mode.
///   • A separate full-screen expanded mode is used for one-tap dive in.
class MiniplayerWidget extends GetView<MiniplayerController> {
  const MiniplayerWidget({super.key});

  @override
  String? get tag => 'miniplayer';

  // Theme tokens
  static const Color _bg = AppColors.bgPage;
  static const Color _card = AppColors.bgSurface;
  static const Color _brand = AppColors.brand;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;
  static const Color _border = AppColors.bgDivider;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<MiniplayerController>(tag: 'miniplayer')) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      final mode = controller.mode.value;
      if (mode == MiniplayerMode.dismissed) return const SizedBox.shrink();

      return LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          // Expanded view branch removed per request
          return _FloatingCard(controller: controller, screenSize: size);
        },
      );
    });
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FLOATING CARD — the TruthWorld-style miniplayer
// ═════════════════════════════════════════════════════════════════════════════

class _FloatingCard extends StatelessWidget {
  final MiniplayerController controller;
  final Size screenSize;
  const _FloatingCard({required this.controller, required this.screenSize});

  @override
  Widget build(BuildContext context) {
    final width = MiniplayerConfig.widthForScreen(screenSize.width);
    final height = MiniplayerConfig.heightForWidth(width);
    final cardSize = Size(width, height);

    return Obx(() {
      final pos = controller.effectiveOffset(cardSize, screenSize);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: pos.dx,
            top: pos.dy,
            width: width,
            height: height,
            child: FocusableActionDetector(
              autofocus: false,
              shortcuts: <ShortcutActivator, Intent>{
                LogicalKeySet(LogicalKeyboardKey.escape):
                    const _DismissIntent(),
              },
              actions: <Type, Action<Intent>>{
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
          ),
        ],
      );
    });
  }
}

class _CardBody extends StatelessWidget {
  final MiniplayerController controller;
  final Size cardSize;
  final Size screenSize;
  const _CardBody({
    required this.controller,
    required this.cardSize,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    final videoHeight = cardSize.width / MiniplayerConfig.videoAspectRatio;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: MiniplayerWidget._bg,
          borderRadius: BorderRadius.circular(MiniplayerConfig.borderRadius),
          border: Border.all(
            color: MiniplayerWidget._border.withValues(alpha: 0.4),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: MiniplayerConfig.elevation,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: videoHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) =>
                    controller.onPanCard(d.delta, cardSize, screenSize),
                onTap: controller.openFullScreen,
                child: _VideoFrame(controller: controller),
              ),
            ),
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
  final MiniplayerController controller;
  const _VideoFrame({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail fallback (always behind the video).
        Obx(() {
          final info = controller.videoInfo.value;
          final url = info?.thumbnailUrl ?? '';
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
          // Always access an observable to avoid Obx crash
          final isReady = controller.isVideoReady.value;
          final vpc = controller.videoPlayerController;
          if (vpc == null || !isReady) {
            return const SizedBox.shrink();
          }
          return FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: vpc.value.size.width,
              height: vpc.value.size.height,
              child: VideoPlayer(vpc),
            ),
          );
        }),

        // Buffering spinner.
        Obx(() {
          final isBuffering = controller.isBuffering.value;
          if (!isBuffering) return const SizedBox.shrink();
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
            color: Colors.black.withValues(alpha: 0.7),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                msg,
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  color: MiniplayerWidget._textPrimary,
                  fontSize: 12,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }),

        // Overlay controls — fade in on hover or when paused.
        Obx(() {
          final showOverlay =
              controller.isHovering.value || !controller.isPlaying.value;
          return AnimatedOpacity(
            opacity: showOverlay ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !showOverlay,
              child: Stack(
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
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.25),
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

                  // Top-right: Close button.
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _OverlayIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close (Esc)',
                      onTap: controller.dismiss,
                    ),
                  ),

                  // Center: Play / Pause.
                  Center(child: _CenterPlayButton(controller: controller)),
                ],
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
  final MiniplayerController controller;
  const _ExpandButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Expand (I)',
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
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
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  'Expand',
                  style: GoogleFonts.roboto(
                    color: Colors.white,
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
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'I',
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
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
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _OverlayIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _CenterPlayButton extends StatelessWidget {
  final MiniplayerController controller;
  const _CenterPlayButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final playing = controller.isPlaying.value;
      return Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: controller.togglePlayPause,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
        ),
      );
    });
  }
}

class _VideoProgressBar extends StatelessWidget {
  final MiniplayerController controller;
  const _VideoProgressBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pos = controller.currentPosition.value.inMilliseconds;
      final dur = controller.totalDuration.value.inMilliseconds;
      final value = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
      return SizedBox(
        height: 3,
        child: LinearProgressIndicator(
          value: value,
          minHeight: 3,
          backgroundColor: Colors.white.withValues(alpha: 0.18),
          valueColor: const AlwaysStoppedAnimation<Color>(
            MiniplayerWidget._brand,
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info bar beneath the video (title, channel + time, expand chevron)
// ─────────────────────────────────────────────────────────────────────────────

class _InfoBar extends StatelessWidget {
  final MiniplayerController controller;
  final Size cardSize;
  final Size screenSize;
  const _InfoBar({
    required this.controller,
    required this.cardSize,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MiniplayerConfig.infoBarHeight,
      child: Material(
        color: MiniplayerWidget._bg,
        child: InkWell(
          onTap: controller.openFullScreen,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanUpdate: (d) =>
                controller.onPanCard(d.delta, cardSize, screenSize),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(child: _TitleAndMeta(controller: controller)),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleAndMeta extends StatelessWidget {
  final MiniplayerController controller;
  const _TitleAndMeta({required this.controller});

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
            style: GoogleFonts.roboto(
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
            style: GoogleFonts.roboto(
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

// ─────────────────────────────────────────────────────────────────────────────
// Keyboard intents
// ─────────────────────────────────────────────────────────────────────────────

class _DismissIntent extends Intent {
  const _DismissIntent();
}
