import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/components/player_controls_barrel.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_only_overlay.dart';

export 'package:truthworld/features/video/presentation/views/player/controls/components/player_controls_barrel.dart';

class MainControls extends StatelessWidget {
  const MainControls({
    required this.ctrl,
    required this.playerWidth,
    super.key,
  });
  final TowerPlayerController ctrl;
  final double playerWidth;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      ctrl.isFullScreen.value;
      final playerHeight = MediaQuery.of(context).size.height;
      final videoAspectRatio = ctrl.isInitialized.value
          ? ctrl.aspectRatio.value
          : null;
      final maxControlsWidth =
          (ctrl.isFullScreen.value &&
              videoAspectRatio != null &&
              videoAspectRatio < 1.0)
          ? (playerHeight * videoAspectRatio).clamp(0.0, playerWidth)
          : playerWidth;

      final isNarrow = maxControlsWidth < 550;
      final isMedium = maxControlsWidth >= 550 && maxControlsWidth < 800;

      return Stack(
        children: [
          // Background dismiss layer on Web: tapping outside buttons closes controls
          if (kIsWeb)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: ctrl.onBackgroundTapWeb,
              ),
            ),

          // Top controls (Fullscreen Top Bar)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ctrl.isFullScreen.value
                ? Center(
                    child: SizedBox(
                      width: maxControlsWidth,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {}, // Absorb taps
                        child: PlayerTopBar(ctrl: ctrl),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Top theme switcher pill in audio-only mode (non-fullscreen)
          if (!ctrl.isFullScreen.value &&
              ctrl.isAudioOnly.value &&
              !ctrl.isPiP.value)
            Positioned(
              top: 14,
              right: 14,
              child: AudioThemeSwitcherPill(ctrl: ctrl),
            ),

          // Top AI-dubbed audio chip (visible only when AI dub is playing)
          Positioned(
            top: ctrl.isFullScreen.value ? 56 : 14,
            left: 14,
            child: Obx(() {
              if (!ctrl.isAiDubPlaying.value) return const SizedBox.shrink();
              return Semantics(
                label: '${ctrl.activeAudioLang.value}, AI-dubbed audio',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'AI-dubbed audio',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          // Centre controls — play / prev / next
          Align(
            child: RepaintBoundary(
              child: CenterRow(ctrl: ctrl, maxControlsWidth: maxControlsWidth),
            ),
          ),

          // Bottom gradient + controls — wrapped in GestureDetector to absorb
          // taps so the outer player GestureDetector (togglePlayPause) doesn't fire.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: maxControlsWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: PlayerBottomBar(
                    ctrl: ctrl,
                    isNarrow: isNarrow,
                    isMedium: isMedium,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
