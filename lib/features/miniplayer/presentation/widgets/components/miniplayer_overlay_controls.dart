import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/miniplayer/presentation/controllers/miniplayer_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Reusable circular icon button with tooltip for miniplayer overlay controls.
class MiniplayerOverlayIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;
  final Color iconColor;

  const MiniplayerOverlayIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 18,
    Color? iconColor,
    super.key,
  }) : iconColor = iconColor ?? AppColors.textPrimary;

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

/// Expand button with "I" hotkey hint pill for the desktop miniplayer.
class MiniplayerExpandButton extends StatelessWidget {
  final MiniplayerController controller;

  const MiniplayerExpandButton({
    required this.controller,
    super.key,
  });

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

/// Center play/pause button for the miniplayer overlay.
class MiniplayerCenterPlayButton extends StatelessWidget {
  final MiniplayerController controller;

  const MiniplayerCenterPlayButton({
    required this.controller,
    super.key,
  });

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

/// Mobile overlay controls with top-left play/pause and top-right close button.
class MiniplayerMobileControls extends StatelessWidget {
  final MiniplayerController controller;

  const MiniplayerMobileControls({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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
            return Tooltip(
              message: playing ? 'Pause' : 'Play',
              child: Material(
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
              ),
            );
          }),
        ),

        // Right / Top-right: Close circular button
        Positioned(
          top: 8,
          right: 8,
          child: Tooltip(
            message: 'Close',
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
        ),

        // Bottom-left: Picture-in-Picture circular button
        Positioned(
          bottom: 8,
          left: 8,
          child: Tooltip(
            message: 'Picture in Picture',
            child: Material(
              color: AppColors.bgPage.withValues(alpha: 0.65),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: controller.enterPip,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.picture_in_picture_alt_rounded,
                    size: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Bottom-right: Expand circular button
        Positioned(
          bottom: 8,
          right: 8,
          child: Tooltip(
            message: 'Expand',
            child: Material(
              color: AppColors.bgPage.withValues(alpha: 0.65),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: controller.openFullScreen,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.open_in_full_rounded,
                    size: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Desktop overlay controls with expand hotkey button, subtitles CC, close, and center play.
class MiniplayerDesktopControls extends StatelessWidget {
  final MiniplayerController controller;

  const MiniplayerDesktopControls({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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
          child: MiniplayerExpandButton(controller: controller),
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
                return MiniplayerOverlayIconButton(
                  icon: enabled
                      ? Icons.subtitles_rounded
                      : Icons.subtitles_outlined,
                  tooltip: 'Subtitles (CC)',
                  onTap: controller.toggleSubtitles,
                );
              }),
              const SizedBox(width: 6),
              MiniplayerOverlayIconButton(
                icon: Icons.picture_in_picture_alt_rounded,
                tooltip: 'Picture in Picture (P)',
                onTap: controller.enterPip,
              ),
              const SizedBox(width: 6),
              MiniplayerOverlayIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Close (Esc)',
                onTap: controller.dismiss,
              ),
            ],
          ),
        ),

        // Center: Play / Pause.
        Center(
          child: MiniplayerCenterPlayButton(controller: controller),
        ),
      ],
    );
  }
}
