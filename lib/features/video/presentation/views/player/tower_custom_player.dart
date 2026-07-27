import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/mobile_friendly_video_player.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/fullscreen_actions_bar.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/player_controls.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/ad_overlay.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/end_screen_overlay.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/player_comments_overlay.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/player_state_overlays.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/player_transcript_overlay.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/real_time_fact_overlay.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/stats_for_nerds_overlay.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/subtitle_overlay.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/player_settings_panels.dart';
import 'package:truthworld/features/video/presentation/widgets/interaction_gate.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:video_player/video_player.dart';

class TowerCustomPlayer extends StatelessWidget {
  const TowerCustomPlayer({
    required this.videoPlayerController, super.key,
    this.tag,
  });
  final VideoPlayerController videoPlayerController;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.isRegistered<TowerPlayerController>(tag: tag)
        ? Get.find<TowerPlayerController>(tag: tag)
        : Get.put(
            TowerPlayerController(
              videoPlayerController: videoPlayerController,
              tag: tag,
            ),
            tag: tag,
          );

    // Register mobile settings bottom sheet callback to display settings at bottom
    TowerPlayerController.showMobileSettingsCallback = MobileSettingsBottomSheet.show;

    return GetBuilder<TowerPlayerController>(
      init: ctrl,
      tag: tag,
      builder: (c) {
        if (!c.isClosed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!c.isClosed) c.sync(videoPlayerController);
          });
        }

        return LayoutBuilder(
          builder: (ctx, constraints) {
            final playerWidth = constraints.maxWidth;
            final playerHeight = constraints.maxHeight;

            return MouseRegion(
              onHover: (_) => c.onInteraction(),
              child: KeyboardListener(
                focusNode: c.focusNode,
                autofocus: true,
                onKeyEvent: c.handleKey,
                child: Obx(() => AbsorbPointer(
                  absorbing: c.isPiP.value,
                  child: InteractionGate(
                    lockController: c.lockController,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                  // YouTube-standard: single tap = controls toggle (mobile), play/pause (desktop)
                  onTap: () => c.onTap(playerWidth > 1050),
                  // Proper Flutter double-tap disambiguation:
                  // onDoubleTapDown gives position, onDoubleTap executes — onTap will NOT fire
                  onDoubleTapDown: (d) => c.isShowingAd.value
                      ? null
                      : c.onDoubleTapDown(d.localPosition.dx),
                  onDoubleTap: () =>
                      c.isShowingAd.value ? null : c.onDoubleTap(playerWidth),
                  onLongPressStart: (_) =>
                      c.isShowingAd.value ? null : c.startLongPressSpeedUp(),
                  onLongPressEnd: (_) =>
                      c.isShowingAd.value ? null : c.endLongPressSpeedUp(),
                  onVerticalDragStart: (d) => c.isShowingAd.value
                      ? null
                      : c.onVerticalDragStart(
                          d,
                          Size(playerWidth, playerHeight),
                        ),
                  onVerticalDragUpdate: (d) => c.isShowingAd.value
                      ? null
                      : c.onVerticalDragUpdate(
                          d,
                          Size(playerWidth, playerHeight),
                        ),
                  onVerticalDragEnd: (d) =>
                      c.isShowingAd.value ? null : c.onVerticalDragEnd(d),
                  child: Stack(
                    children: [
                      // ── Layer 0: Video ─────────────────────────────────────
                      Obx(() {
                        final showAd = c.isShowingAd.value;
                        final apc = c.adPlayerController;

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // Main video player - always kept in the widget tree to prevent DOM unmounting on Web
                            Offstage(
                              offstage:
                                  showAd ||
                                  c.isAudioOnly.value ||
                                  !c.isInitialized.value,
                              child: Center(
                                child:
                                    c.isInitialized.value &&
                                        c.chewieController != null
                                    ? InteractiveViewer(
                                        minScale: 1,
                                        maxScale: 6,
                                        child: AspectRatio(
                                          aspectRatio: c.aspectRatio.value,
                                          child: Chewie(
                                            controller: c.chewieController!,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),

                            // Ad video player
                            if (showAd)
                              Center(
                                child: apc != null && apc.value.isInitialized
                                    ? AspectRatio(
                                        aspectRatio: apc.value.aspectRatio,
                                        child: MobileFriendlyVideoPlayer(
                                          controller: apc,
                                        ),
                                      )
                                    : const CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.warning,
                                            ),
                                      ),
                              ),
                          ],
                        );
                      }),

                      // ── Layer 0.5: Audio-only UI with 250ms Crossfade ───────────────
                      Obx(
                        () => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: c.isAudioOnly.value
                              ? RepaintBoundary(
                                  key: const ValueKey('audio_overlay'),
                                  child: AudioOnlyOverlay(ctrl: c),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('video_viewport'),
                                ),
                        ),
                      ),

                      // ── Layer 0.7: Brightness overlay ──────────────────────
                      Obx(() {
                        final opacity = (1.0 - c.brightness.value).clamp(
                          0.0,
                          0.85,
                        );
                        if (opacity <= 0.0) return const SizedBox.shrink();
                        return Positioned.fill(
                          child: IgnorePointer(
                            child: ColoredBox(
                              color: AppColors.bgPage.withValues(alpha: opacity),
                            ),
                          ),
                        );
                      }),

                      // ── Layer 1: Subtitles ─────────────────────────────────
                      Obx(() {
                        if (c.isShowingAd.value ||
                            c.isPiP.value ||
                            !c.subtitlesEnabled.value ||
                            c.currentSubtitle.value.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Positioned(
                          bottom: c.controlsVisible.value ? 120 : 60,
                          left: 40,
                          right: 40,
                          child: SubtitleOverlay(ctrl: c),
                        );
                      }),

                      // ── Layer 2: Double-tap ripples ────────────────────────
                      Obx(
                        () => c.showDoubleTapLeft.value && !c.isPiP.value
                            ? const DoubleTapRipple(isLeft: true)
                            : const SizedBox.shrink(),
                      ),
                      Obx(
                        () => c.showDoubleTapRight.value && !c.isPiP.value
                            ? const DoubleTapRipple(isLeft: false)
                            : const SizedBox.shrink(),
                      ),

                      // ── Layer 3: State (buffering / error / stall) ─────────
                      Obx(
                        () => c.isShowingAd.value || c.isPiP.value
                            ? const SizedBox.shrink()
                            : StateOverlay(ctrl: c),
                      ),

                      // ── Layer 4: Seek preview tooltip ──────────────────────
                      Obx(
                        () => c.seekPreviewVis.value && !c.isPiP.value
                            ? SeekPreviewTooltip(ctrl: c)
                            : const SizedBox.shrink(),
                      ),

                      // ── Layer 5: Toast ─────────────────────────────────────
                      Obx(
                        () => c.toastMessage.value.isNotEmpty && !c.isPiP.value
                            ? PlayerToast(message: c.toastMessage.value)
                            : const SizedBox.shrink(),
                      ),

                      // ── Layer 5.5: Long-press 2× HUD ──────────────────────
                      Obx(() {
                        if (!c.isLongPressSpeedUp.value || c.isPiP.value) {
                          return const SizedBox.shrink();
                        }
                        return Positioned(
                          top: 24,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.bgPage.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.textDisabled),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.fast_forward_rounded,
                                    color: AppColors.brand,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '2.0× Speed',
                                    style: TS.bold.copyWith(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      // ── Layer 5.6: Swipe HUD ───────────────────────────────
                      Obx(() {
                        final vol = c.showSwipeVolumeHUD.value;
                        final bri = c.showSwipeBrightnessHUD.value;
                        if ((!vol && !bri) || c.isPiP.value) return const SizedBox.shrink();
                        return Align(
                          alignment: bri
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: SwipeHUD(
                              isBrightness: bri,
                              value: bri
                                  ? c.swipeBrightnessLevel.value
                                  : c.swipeVolumeLevel.value,
                            ),
                          ),
                        );
                      }),

                      // ── Layer 5.7: Real-time Fact Overlay ─────────────────
                      Obx(() {
                        if (c.isShowingAd.value || c.isPiP.value) return const SizedBox.shrink();
                        final activeClaim = c.activeClaim.value;
                        if (activeClaim == null) return const SizedBox.shrink();

                        return AnimatedPositioned(
                          duration: const Duration(milliseconds: 250),
                          top: c.controlsVisible.value ? 76.0 : 24.0,
                          left: 24,
                          right: 24,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: RealTimeFactOverlayWidget(
                              claim: activeClaim,
                            ),
                          ),
                        );
                      }),

                      // ── Layer 6: Main controls ─────────────────────────────
                      Obx(() {
                        c.isShowingAd.value;
                        c.isPiP.value;
                        c.controlsVisible.value;
                        if (c.isShowingAd.value || c.isPiP.value) return const SizedBox.shrink();
                        return Positioned.fill(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: c.controlsVisible.value ? 1.0 : 0.0,
                            child: AbsorbPointer(
                              absorbing: !c.controlsVisible.value,
                              child: MainControls(
                                  ctrl: c,
                                  playerWidth: playerWidth,
                              ),
                            ),
                          ),
                        );
                      }),
                      // ── Layer 6.5: Popups ──────────────────────────────────
                      Obx(() {
                        c.isShowingAd.value;
                        c.isPiP.value;
                        c.controlsVisible.value;
                        c.isFullScreen.value;
                        c.showCommentsPopup.value;
                        c.showTranscriptPopup.value;
                        if (c.isShowingAd.value || c.isPiP.value) return const SizedBox.shrink();
                        return Positioned.fill(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: c.controlsVisible.value ? 1.0 : 0.0,
                            child: AbsorbPointer(
                              absorbing: !c.controlsVisible.value,
                              child: Stack(
                                children: [
                                  if (c.isFullScreen.value) ...[
                                    // Comments Overlay positioned directly in Stack
                                    Positioned(
                                      top: 80,
                                      bottom: 80,
                                      right: 20,
                                      width: 350,
                                      child: Obx(() {
                                        c.showCommentsPopup.value;
                                        if (!c.showCommentsPopup.value) {
                                          return const SizedBox.shrink();
                                        }
                                        return CommentsOverlay(ctrl: c);
                                      }),
                                    ),

                                    // Transcript Overlay positioned directly in Stack
                                    Positioned(
                                      top: 80,
                                      bottom: 80,
                                      right: 20,
                                      width: 350,
                                      child: Obx(() {
                                        c.showTranscriptPopup.value;
                                        if (!c.showTranscriptPopup.value) {
                                          return const SizedBox.shrink();
                                        }
                                        return TranscriptOverlay(ctrl: c);
                                      }),
                                    ),

                                    // Floating Vertical Actions Dock positioned directly in Stack
                                    AnimatedPositioned(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.fastOutSlowIn,
                                      right:
                                          (c.showCommentsPopup.value ||
                                              c.showTranscriptPopup.value)
                                          ? 390.0
                                          : (c.isInitialized.value &&
                                                c.aspectRatio.value < 1.0)
                                          ? (((playerWidth -
                                                            (playerHeight *
                                                                    c.aspectRatio.value)
                                                                .clamp(
                                                                  0.0,
                                                                  playerWidth,
                                                                )) /
                                                        2) +
                                                    20.0)
                                                .clamp(20.0, playerWidth - 60.0)
                                          : 20.0,
                                      bottom: 150,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {}, // Absorb taps
                                        child: FullscreenVerticalActionsBar(
                                          ctrl: c,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      // ── Layer 7: Settings panel + dismiss scrim ─────────────
                      Obx(() {
                        c.isShowingAd.value;
                        c.isPiP.value;
                        c.settingsOpen.value;
                        if (c.isShowingAd.value || c.isPiP.value) return const SizedBox.shrink();
                        return c.settingsOpen.value
                            ? Positioned.fill(
                                child: Stack(
                                  children: [
                                    // Scrim: tap anywhere outside to dismiss
                                    Positioned.fill(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: c.closeSettings,
                                        child: const ColoredBox(
                                          color: Colors.transparent,
                                        ),
                                      ),
                                    ),
                                    SettingsPanel(ctrl: c),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink();
                      }),

                      // ── Layer 8: Resolution switching overlay ──────────────
                      Obx(() {
                        if (c.isShowingAd.value || c.isPiP.value) return const SizedBox.shrink();
                        // touch an observable
                        c.isAudioOnly.value;
                        var isSwitching = false;
                        var isManual = false;
                        try {
                          final vc = c.videoController;
                          if (vc != null) {
                            isSwitching = vc.isSwitchingResolution.value;
                            isManual = !vc.isAutoSwitching.value;
                          }
                        } catch (_) {}
                        final show = isSwitching && isManual;
                        return show
                            ? const Positioned.fill(
                                child: SwitchingResolutionOverlay(),
                              )
                            : const SizedBox.shrink();
                      }),

                      // ── Layer 8.5: Ad Overlay ──────────────────────────────
                      Obx(() {
                        c.isShowingAd.value;
                        c.isPiP.value;
                        if (c.isShowingAd.value && !c.isPiP.value) {
                          return Positioned.fill(
                            child: AdOverlay(ctrl: c),
                          );
                        }
                        return const SizedBox.shrink();
                      }),

                      // ── Layer 8.6: End Screen Overlay ───────────────────────
                      Obx(() {
                        c.showEndScreen.value;
                        c.isPiP.value;
                        if (c.showEndScreen.value && !c.isPiP.value) {
                          return Positioned.fill(
                            child: EndScreenOverlay(ctrl: c),
                          );
                        }
                        return const SizedBox.shrink();
                      }),

                      // ── Layer 9: Stats for Nerds ───────────────────────────
                      Obx(() {
                        c.showStatsForNerds.value;
                        c.isPiP.value;
                        if (!c.showStatsForNerds.value || c.isPiP.value) return const SizedBox.shrink();
                        return Positioned(
                          top: 16,
                          left: 16,
                          child: RepaintBoundary(
                            child: StatsForNerdsOverlay(ctrl: c),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          )),
        );
      },
    );
  },
);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS FOR NERDS
// ─────────────────────────────────────────────────────────────────────────────
