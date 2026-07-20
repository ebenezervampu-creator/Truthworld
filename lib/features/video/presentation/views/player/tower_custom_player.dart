import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:truthworld/core/widgets/mobile_friendly_video_player.dart';

import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';

import 'overlays/stats_for_nerds_overlay.dart';
import 'overlays/player_state_overlays.dart';
import 'overlays/subtitle_overlay.dart';
import 'overlays/player_comments_overlay.dart';
import 'overlays/player_transcript_overlay.dart';
import 'controls/player_controls.dart';
import 'controls/fullscreen_actions_bar.dart';
import 'panels/player_settings_panels.dart';
import 'overlays/ad_overlay.dart';
import 'overlays/real_time_fact_overlay.dart';
import 'overlays/end_screen_overlay.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';

class TowerCustomPlayer extends StatelessWidget {
  final VideoPlayerController videoPlayerController;
  final String? tag;
  const TowerCustomPlayer({
    super.key,
    required this.videoPlayerController,
    this.tag,
  });

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
    TowerPlayerController.showMobileSettingsCallback = (ctx, controller) {
      MobileSettingsBottomSheet.show(ctx, controller);
    };

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
                                  !c.vv.isInitialized,
                              child: Center(
                                child:
                                    c.vv.isInitialized &&
                                        c.chewieController != null
                                    ? InteractiveViewer(
                                        clipBehavior: Clip.hardEdge,
                                        minScale: 1.0,
                                        maxScale: 6.0,
                                        child: AspectRatio(
                                          aspectRatio: c.vv.aspectRatio,
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
                                          looping: false,
                                        ),
                                      )
                                    : const CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.amber,
                                            ),
                                      ),
                              ),
                          ],
                        );
                      }),

                      // ── Layer 0.5: Audio-only UI ───────────────────────────
                      Obx(
                        () => c.isAudioOnly.value
                            ? RepaintBoundary(child: AudioOnlyOverlay(ctrl: c))
                            : const SizedBox.shrink(),
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
                              color: Colors.black.withValues(alpha: opacity),
                            ),
                          ),
                        );
                      }),

                      // ── Layer 1: Subtitles ─────────────────────────────────
                      Obx(() {
                        if (c.isShowingAd.value ||
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
                        () => c.showDoubleTapLeft.value
                            ? const DoubleTapRipple(isLeft: true)
                            : const SizedBox.shrink(),
                      ),
                      Obx(
                        () => c.showDoubleTapRight.value
                            ? const DoubleTapRipple(isLeft: false)
                            : const SizedBox.shrink(),
                      ),

                      // ── Layer 3: State (buffering / error / stall) ─────────
                      Obx(
                        () => c.isShowingAd.value
                            ? const SizedBox.shrink()
                            : StateOverlay(ctrl: c),
                      ),

                      // ── Layer 4: Seek preview tooltip ──────────────────────
                      Obx(
                        () => c.seekPreviewVis.value
                            ? SeekPreviewTooltip(ctrl: c)
                            : const SizedBox.shrink(),
                      ),

                      // ── Layer 5: Toast ─────────────────────────────────────
                      Obx(
                        () => c.toastMessage.value.isNotEmpty
                            ? PlayerToast(message: c.toastMessage.value)
                            : const SizedBox.shrink(),
                      ),

                      // ── Layer 5.5: Long-press 2× HUD ──────────────────────
                      Obx(() {
                        if (!c.isLongPressSpeedUp.value) {
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
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
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
                        if (!vol && !bri) return const SizedBox.shrink();
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
                        if (c.isShowingAd.value) return const SizedBox.shrink();
                        final vc = c.videoController;
                        if (vc == null) return const SizedBox.shrink();
                        final uiReport = vc.video.uiReport;
                        if (uiReport == null || uiReport.keyClaims.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final posSec = c.vv.position.inMilliseconds / 1000.0;
                        ClaimResult? activeClaim;
                        for (final claim in uiReport.keyClaims) {
                          if (claim.start != null && claim.end != null) {
                            if (posSec >= claim.start! &&
                                posSec <= claim.end!) {
                              activeClaim = claim;
                              break;
                            }
                          }
                        }

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
                        if (c.isShowingAd.value) return const SizedBox.shrink();
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
                        if (c.isShowingAd.value) return const SizedBox.shrink();
                        return AnimatedOpacity(
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
                                        : (c.vv.isInitialized &&
                                              c.vv.aspectRatio < 1.0)
                                        ? (((playerWidth -
                                                          (playerHeight *
                                                                  c.vv.aspectRatio)
                                                              .clamp(
                                                                0.0,
                                                                playerWidth,
                                                              )) /
                                                      2) +
                                                  20.0)
                                              .clamp(20.0, playerWidth - 60.0)
                                        : 20.0,
                                    bottom: 150.0,
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
                        );
                      }),

                      // ── Layer 7: Settings panel + dismiss scrim ─────────────
                      Obx(() {
                        if (c.isShowingAd.value) return const SizedBox.shrink();
                        return c.settingsOpen.value
                            ? Stack(
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
                              )
                            : const SizedBox.shrink();
                      }),

                      // ── Layer 8: Resolution switching overlay ──────────────
                      Obx(() {
                        if (c.isShowingAd.value) return const SizedBox.shrink();
                        // touch an observable
                        c.isAudioOnly.value;
                        bool isSwitching = false, isManual = false;
                        try {
                          if (Get.isRegistered<VideoController>(tag: c.tag)) {
                            final vc = Get.find<VideoController>(tag: c.tag);
                            isSwitching = vc.isSwitchingResolution.value;
                            isManual = !vc.isAutoSwitching.value;
                          }
                        } catch (_) {}
                        final show = isSwitching && isManual;
                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: show ? 1.0 : 0.0,
                          child: show
                              ? const SwitchingResolutionOverlay()
                              : const SizedBox.shrink(),
                        );
                      }),

                      // ── Layer 8.5: Ad Overlay ──────────────────────────────
                      AdOverlay(ctrl: c),

                      // ── Layer 8.6: End Screen Overlay ───────────────────────
                      EndScreenOverlay(ctrl: c),

                      // ── Layer 9: Stats for Nerds ───────────────────────────
                      RepaintBoundary(child: StatsForNerdsOverlay(ctrl: c)),
                    ],
                  ),
                ),
              ),
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
