import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/guest_playback_limit_service.dart';
import 'package:truthworld/core/widgets/mobile_friendly_video_player.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/controls/player_controls.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/ad_overlay.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/end_screen_overlay.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/fullscreen_more_videos_overlay.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/live_chat_overlay.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/player_comments_overlay.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/player_fact_check_overlay.dart';
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
    required this.videoPlayerController,
    super.key,
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
    TowerPlayerController.showMobileSettingsCallback =
        MobileSettingsBottomSheet.show;

    return GetBuilder<TowerPlayerController>(
      init: ctrl,
      tag: tag,
      builder: (c) {
        if (c.videoPlayerController != videoPlayerController) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!c.isClosed &&
                c.videoPlayerController != videoPlayerController) {
              c.sync(videoPlayerController);
            }
          });
        }

        var baseScale = 1.0;
        var basePan = Offset.zero;
        var initialFocalPoint = Offset.zero;
        var isPinching = false;
        var isMovingZoom = false;

        return LayoutBuilder(
          builder: (ctx, constraints) {
            final playerWidth = constraints.maxWidth;
            final playerHeight = constraints.maxHeight;

            return MouseRegion(
              onHover: (_) {
                if (kIsWeb && c.isHoverSuppressed) return;
                c.onInteraction();
              },
              child: KeyboardListener(
                focusNode: c.focusNode,
                autofocus: true,
                onKeyEvent: c.handleKey,
                child: Obx(
                  () => AbsorbPointer(
                    absorbing: c.isPiP.value,
                    child: InteractionGate(
                      lockController: c.lockController,
                      child: Stack(
                        children: [
                          // ── Layer 0: Video ─────────────────────────────────────
                          Obx(() {
                            final showAd = c.isShowingAd.value;
                            final apc = c.adPlayerController;
                            final isInit = c.isInitialized.value;
                            final isAudioOnly = c.isAudioOnly.value;

                            final isZoom = c.isZoomToFill.value;
                            final scale = c.zoomScale.value;
                            final ar = c.aspectRatio.value > 0
                                ? c.aspectRatio.value
                                : 16 / 9;

                            final viewportSize = Size(playerWidth, playerHeight);
                            final fillScale = c.calculateFillScale(viewportSize);
                            final effectiveScale =
                                isZoom && scale <= 1.05 ? fillScale : scale;
                            final panOffset = c.clampPanOffset(
                              c.zoomPanOffset.value,
                              effectiveScale,
                              viewportSize,
                            );

                            final activeVpc = c.rxVideoPlayerController.value;

                            Widget basePlayer = isInit
                                ? Center(
                                    child: AspectRatio(
                                      aspectRatio: ar,
                                      child: MobileFriendlyVideoPlayer(
                                        key: ValueKey(activeVpc),
                                        controller: activeVpc,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink();

                            if (effectiveScale > 1.001 && isInit) {
                              basePlayer = ClipRect(
                                child: Transform.translate(
                                  offset: panOffset,
                                  child: Transform.scale(
                                    scale: effectiveScale,
                                    child: basePlayer,
                                  ),
                                ),
                              );
                            }

                            // ── Resolution Downsampling / Blur Effect ──────────────────
                            // When playing at lower resolutions (e.g. 144p, 240p, 360p, 480p),
                            // if the decoded stream is high resolution (e.g. 1080p source or synthetic ladder),
                            // apply authentic visual resolution blur so 144p actually displays with low-res blur.
                            final blurSigma = c.resolutionBlurSigma;
                            if (blurSigma > 0.1 && isInit) {
                              basePlayer = ClipRect(
                                child: ImageFiltered(
                                  imageFilter: ui.ImageFilter.blur(
                                    sigmaX: blurSigma,
                                    sigmaY: blurSigma,
                                    tileMode: TileMode.clamp,
                                  ),
                                  child: basePlayer,
                                ),
                              );
                            }

                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                // Main video player - always kept in the widget tree to prevent DOM unmounting on Web
                                Offstage(
                                  offstage: showAd || isAudioOnly || !isInit,
                                  child: basePlayer,
                                ),

                                // Ad video player
                                if (showAd)
                                  Center(
                                    child: apc != null && apc.value.isInitialized
                                        ? AspectRatio(
                                            aspectRatio: apc.value.aspectRatio > 0
                                                ? apc.value.aspectRatio
                                                : 16 / 9,
                                            child: MobileFriendlyVideoPlayer(
                                              key: ValueKey(apc),
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

                            // ── Layer 0.05: Video Bottom Seam Guard ────────────────
                            // Eliminates any 1px sub-pixel rounding gap, video encoding border,
                            // or edge texture bleeding at the bottom boundary seamlessly in black.
                            const Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 1.5,
                              child: IgnorePointer(
                                child: ColoredBox(color: Colors.black),
                              ),
                            ),

                            // ── Layer 0.1: Video Viewport Gestures (Background tap/seek/drag) ──
                            Positioned.fill(
                              child: MouseRegion(
                                onHover: (_) {
                                  if (!c.isShowingAd.value) {
                                    if (kIsWeb && c.isHoverSuppressed) return;
                                    c.onInteraction();
                                    if (!c.controlsVisible.value) {
                                      c.controlsVisible.value = true;
                                    }
                                    c.startHideTimer();
                                  }
                                },
                                child: Listener(
                                  onPointerSignal: (pointerSignal) {
                                    if (pointerSignal is PointerScrollEvent &&
                                        c.isFullScreen.value &&
                                        !c.isShowingAd.value) {
                                      // Upward mouse wheel/trackpad scroll in fullscreen opens More Videos
                                      if (pointerSignal.scrollDelta.dy < -15) {
                                        c.openMoreVideos();
                                      }
                                    }
                                  },
                                  child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                onTapDown: (d) => c.isShowingAd.value
                                    ? null
                                    : c.handlePlayerTap(
                                        d.localPosition.dx,
                                        playerWidth,
                                        playerWidth > 1050,
                                      ),
                                onLongPressStart: (_) {
                                  if (c.isShowingAd.value) return;
                                  c.cancelPendingTap();
                                  c.startLongPressSpeedUp();
                                },
                                onLongPressEnd: (_) => c.isShowingAd.value
                                    ? null
                                    : c.endLongPressSpeedUp(),
                                  onScaleStart: (details) {
                                  if (c.isShowingAd.value) return;
                                  c.cancelZoomAnimation();
                                  final viewportSize =
                                      Size(playerWidth, playerHeight);
                                  final fillScale =
                                      c.calculateFillScale(viewportSize);
                                  final currentScale = c.isZoomToFill.value &&
                                          c.zoomScale.value <= 1.05
                                      ? fillScale
                                      : c.zoomScale.value;
                                  final isCurrentlyZoomed =
                                      currentScale > 1.02;

                                  if (details.pointerCount >= 2) {
                                    c.cancelPendingTap();
                                    isPinching = true;
                                    isMovingZoom = false;
                                    baseScale = currentScale;
                                    basePan = c.zoomPanOffset.value;
                                    initialFocalPoint = details.localFocalPoint;
                                  } else if (isCurrentlyZoomed) {
                                    c.cancelPendingTap();
                                    isPinching = false;
                                    isMovingZoom = true;
                                    basePan = c.zoomPanOffset.value;
                                    initialFocalPoint = details.localFocalPoint;
                                  } else {
                                    isPinching = false;
                                    isMovingZoom = false;
                                    c.onVerticalDragStart(
                                      DragStartDetails(
                                        globalPosition: details.focalPoint,
                                        localPosition: details.localFocalPoint,
                                      ),
                                      viewportSize,
                                    );
                                  }
                                },
                                onScaleUpdate: (details) {
                                  if (c.isShowingAd.value) return;
                                  final viewportSize =
                                      Size(playerWidth, playerHeight);
                                  final fillScale =
                                      c.calculateFillScale(viewportSize);

                                  if (details.pointerCount >= 2 || isPinching) {
                                    isPinching = true;
                                    isMovingZoom = false;
                                    final newScale =
                                        (baseScale * details.scale)
                                            .clamp(1.0, 8.0);
                                    final focalDelta =
                                        details.localFocalPoint -
                                            initialFocalPoint;
                                    final candidatePan = basePan + focalDelta;
                                    final clampedPan = c.clampPanOffset(
                                      candidatePan,
                                      newScale,
                                      viewportSize,
                                    );

                                    c.zoomScale.value = newScale;
                                    c.zoomPanOffset.value = clampedPan;

                                    if ((newScale - fillScale).abs() < 0.08) {
                                      c.isZoomToFill.value = true;
                                      c.showToast('Zoomed to fill');
                                    } else if (newScale <= 1.05) {
                                      c.isZoomToFill.value = false;
                                      c.showToast('Original');
                                    } else {
                                      c.isZoomToFill.value = false;
                                      final valStr = newScale % 1 == 0
                                          ? newScale.toInt().toString()
                                          : newScale.toStringAsFixed(1);
                                      c.showToast('${valStr}x');
                                    }
                                  } else if (isMovingZoom) {
                                    final focalDelta =
                                        details.localFocalPoint -
                                            initialFocalPoint;
                                    final candidatePan = basePan + focalDelta;
                                    final currentScale = c.isZoomToFill.value &&
                                            c.zoomScale.value <= 1.05
                                        ? fillScale
                                        : c.zoomScale.value;
                                    final clampedPan = c.clampPanOffset(
                                      candidatePan,
                                      currentScale,
                                      viewportSize,
                                    );
                                    c.zoomPanOffset.value = clampedPan;
                                  } else {
                                    c.onVerticalDragUpdate(
                                      DragUpdateDetails(
                                        globalPosition: details.focalPoint,
                                        localPosition: details.localFocalPoint,
                                        delta: details.focalPointDelta,
                                      ),
                                      viewportSize,
                                    );
                                  }
                                },
                                onScaleEnd: (details) {
                                  if (c.isShowingAd.value) return;
                                  final viewportSize =
                                      Size(playerWidth, playerHeight);
                                  final fillScale =
                                      c.calculateFillScale(viewportSize);

                                  if (isPinching) {
                                    isPinching = false;
                                    if (c.zoomScale.value < 1.08) {
                                      c.animateZoomTo(
                                        targetScale: 1.0,
                                        targetPan: Offset.zero,
                                        fill: false,
                                      );
                                      c.showToast('Original');
                                    } else if ((c.zoomScale.value - fillScale)
                                            .abs() <
                                        0.12) {
                                      final targetPan = c.clampPanOffset(
                                        c.zoomPanOffset.value,
                                        fillScale,
                                        viewportSize,
                                      );
                                      c.animateZoomTo(
                                        targetScale: fillScale,
                                        targetPan: targetPan,
                                        fill: true,
                                      );
                                      c.showToast('Zoomed to fill');
                                    } else {
                                      c.isZoomToFill.value = false;
                                      final targetPan = c.clampPanOffset(
                                        c.zoomPanOffset.value,
                                        c.zoomScale.value,
                                        viewportSize,
                                      );
                                      c.animateZoomTo(
                                        targetScale: c.zoomScale.value,
                                        targetPan: targetPan,
                                        fill: false,
                                        duration:
                                            const Duration(milliseconds: 140),
                                      );
                                      final scale = c.zoomScale.value;
                                      final valStr = scale % 1 == 0
                                          ? scale.toInt().toString()
                                          : scale.toStringAsFixed(1);
                                      c.showToast('${valStr}x');
                                    }
                                  } else if (isMovingZoom) {
                                    isMovingZoom = false;
                                    final currentScale = c.isZoomToFill.value &&
                                            c.zoomScale.value <= 1.05
                                        ? fillScale
                                        : c.zoomScale.value;
                                    final targetPan = c.clampPanOffset(
                                      c.zoomPanOffset.value,
                                      currentScale,
                                      viewportSize,
                                    );
                                    c.animateZoomTo(
                                      targetScale: currentScale,
                                      targetPan: targetPan,
                                      fill: c.isZoomToFill.value,
                                      duration:
                                          const Duration(milliseconds: 120),
                                    );
                                  } else {
                                    c.onVerticalDragEnd(
                                      DragEndDetails(
                                        velocity: Velocity(
                                          pixelsPerSecond:
                                              details.velocity.pixelsPerSecond,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ),

                            // ── Layer 0.5: Audio-only UI with 250ms Crossfade ───────────────
                            Obx(
                              () => AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
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
                              if (opacity <= 0.0) {
                                return const SizedBox.shrink();
                              }
                              return Positioned.fill(
                                child: IgnorePointer(
                                  child: ColoredBox(
                                    color: AppColors.bgPage.withValues(
                                      alpha: opacity,
                                    ),
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
                              return AnimatedPositioned(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                bottom: c.controlsVisible.value ? 75 : 20,
                                left: 16,
                                right: 16,
                                child: IgnorePointer(
                                  child: SubtitleOverlay(ctrl: c),
                                ),
                              );
                            }),

                            // ── Layer 2: Double-tap ripples ────────────────────────
                            Obx(
                              () => c.showDoubleTapLeft.value && !c.isPiP.value
                                  ? Positioned(
                                      top: 0,
                                      left: 0,
                                      bottom: 0,
                                      width: playerWidth * 0.45,
                                      child: IgnorePointer(
                                        child: DoubleTapRipple(
                                          isLeft: true,
                                          seconds: c.doubleTapSeconds.value > 0
                                              ? c.doubleTapSeconds.value
                                              : 10,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            Obx(
                              () => c.showDoubleTapRight.value && !c.isPiP.value
                                  ? Positioned(
                                      top: 0,
                                      right: 0,
                                      bottom: 0,
                                      width: playerWidth * 0.45,
                                      child: IgnorePointer(
                                        child: DoubleTapRipple(
                                          isLeft: false,
                                          seconds: c.doubleTapSeconds.value > 0
                                              ? c.doubleTapSeconds.value
                                              : 10,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            // ── Layer 3: State (buffering / error / stall) ─────────
                            Obx(
                              () => c.isShowingAd.value || c.isPiP.value
                                  ? const SizedBox.shrink()
                                  : StateOverlay(ctrl: c),
                            ),

                            // ── Layer 4: Seek preview tooltip ──────────────────────
                            Obx(() {
                              final isInteractingWithProgress =
                                  c.isScrubbing.value ||
                                  c.isDragging.value ||
                                  c.isTimelineHovered.value ||
                                  c.progressBarHovered.value;
                              final shouldShow = c.seekPreviewVis.value &&
                                  !c.isPiP.value &&
                                  c.controlsVisible.value &&
                                  isInteractingWithProgress;

                              return shouldShow
                                  ? Positioned(
                                      bottom: 100,
                                      left: 0,
                                      right: 0,
                                      child: IgnorePointer(
                                        child: SeekPreviewTooltip(ctrl: c),
                                      ),
                                    )
                                  : const SizedBox.shrink();
                            }),

                            // ── Layer 5: Toast ─────────────────────────────────────
                            Obx(
                              () =>
                                  c.toastMessage.value.isNotEmpty &&
                                      !c.isPiP.value
                                  ? Positioned.fill(
                                      child: IgnorePointer(
                                        child: PlayerToast(
                                          message: c.toastMessage.value,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            // ── Layer 5.5: Long-press 2× HUD ──────────────────────
                            Obx(() {
                              if (!c.isLongPressSpeedUp.value ||
                                  c.isPiP.value) {
                                return const SizedBox.shrink();
                              }
                              return Positioned(
                                top: 24,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.bgPage.withValues(
                                          alpha: 0.7,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.textDisabled,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.fast_forward_rounded,
                                            color: AppColors.textPrimary,
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
                                ),
                              );
                            }),

                            // ── Layer 5.6: Swipe HUD ───────────────────────────────
                            Obx(() {
                              final vol = c.showSwipeVolumeHUD.value;
                              final bri = c.showSwipeBrightnessHUD.value;
                              if ((!vol && !bri) || c.isPiP.value) {
                                return const SizedBox.shrink();
                              }
                              return Align(
                                alignment: bri
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                child: IgnorePointer(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: SwipeHUD(
                                      isBrightness: bri,
                                      value: bri
                                          ? c.swipeBrightnessLevel.value
                                          : c.swipeVolumeLevel.value,
                                    ),
                                  ),
                                ),
                              );
                            }),

                            // ── Layer 5.7: Real-time Fact Overlay ─────────────────
                            // Show active claim ONLY in fullscreen mode on the right side as a popup menu/card
                            Obx(() {
                              if (c.isShowingAd.value ||
                                  c.isPiP.value ||
                                  !c.isFullScreen.value ||
                                  !c.showFactOverlay.value) {
                                return const SizedBox.shrink();
                              }
                              // Do not obstruct if full fact-check, comments, transcript, or live chat panel is open
                              if (c.showFactCheckPopup.value ||
                                  c.showCommentsPopup.value ||
                                  c.showTranscriptPopup.value ||
                                  c.showLiveChat.value) {
                                return const SizedBox.shrink();
                              }
                              final activeClaim = c.activeClaim.value;
                              if (activeClaim == null) {
                                return const SizedBox.shrink();
                              }

                              return AnimatedPositioned(
                                duration: const Duration(milliseconds: 250),
                                top: playerHeight < 500
                                    ? 16.0
                                    : (c.controlsVisible.value ? 76.0 : 24.0),
                                right: 20,
                                width: (playerWidth < 460)
                                    ? (playerWidth - 40).clamp(280.0, 390.0)
                                    : 380.0,
                                child: RealTimeFactOverlayWidget(
                                  claim: activeClaim,
                                  onClose: () {
                                    c.showFactOverlay.value = false;
                                  },
                                  onTap: () {
                                    c.overlayManager.toggle(TowerPlayerOverlay.factCheck);
                                    c.showFactCheckPopup.value =
                                        c.overlayManager.isFactCheckOpen;
                                    c.showCommentsPopup.value = false;
                                    c.showTranscriptPopup.value = false;
                                    c.showLiveChat.value = false;
                                  },
                                ),
                              );
                            }),

                            // ── Layer 6: Main controls ─────────────────────────────
                            Obx(() {
                              c.isShowingAd.value;
                              c.isPiP.value;
                              c.controlsVisible.value;
                              if (c.isShowingAd.value || c.isPiP.value) {
                                return const SizedBox.shrink();
                              }
                              return Positioned.fill(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: c.controlsVisible.value ? 1.0 : 0.0,
                                  child: IgnorePointer(
                                    ignoring: !c.controlsVisible.value,
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
                              c.showFactCheckPopup.value;
                              if (c.isShowingAd.value || c.isPiP.value) {
                                return const SizedBox.shrink();
                              }

                              final hasOverlayOpen =
                                  c.showCommentsPopup.value ||
                                  c.showTranscriptPopup.value ||
                                  c.showFactCheckPopup.value;
                              final isLayerVisible =
                                  c.controlsVisible.value || hasOverlayOpen;

                              return Positioned.fill(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: isLayerVisible ? 1.0 : 0.0,
                                  child: IgnorePointer(
                                    ignoring: !isLayerVisible,
                                    child: Stack(
                                      children: [
                                        FloatingAutoPlayCommentOverlay(ctrl: c),
                                        if (c.isFullScreen.value) ...[
                                          // Comments Overlay positioned directly in Stack
                                          Positioned(
                                            top: playerHeight < 500 ? 16.0 : 80.0,
                                            bottom: playerHeight < 500 ? 16.0 : 80.0,
                                            right: 20,
                                            width: (playerWidth < 460)
                                                ? (playerWidth - 40).clamp(260.0, 390.0)
                                                : 350.0,
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
                                            top: playerHeight < 500 ? 16.0 : 80.0,
                                            bottom: playerHeight < 500 ? 16.0 : 80.0,
                                            right: 20,
                                            width: (playerWidth < 460)
                                                ? (playerWidth - 40).clamp(260.0, 390.0)
                                                : 350.0,
                                            child: Obx(() {
                                              c.showTranscriptPopup.value;
                                              if (!c
                                                  .showTranscriptPopup
                                                  .value) {
                                                return const SizedBox.shrink();
                                              }
                                              return TranscriptOverlay(ctrl: c);
                                            }),
                                          ),

                                          // Fact-Check & Credibility Overlay positioned directly in Stack
                                          Positioned(
                                            top: playerHeight < 500 ? 16.0 : 80.0,
                                            bottom: playerHeight < 500 ? 16.0 : 80.0,
                                            right: 20,
                                            width: (playerWidth < 460)
                                                ? (playerWidth - 40)
                                                    .clamp(280.0, 390.0)
                                                : 390,
                                            child: Obx(() {
                                              c.showFactCheckPopup.value;
                                              if (!c
                                                  .showFactCheckPopup
                                                  .value) {
                                                return const SizedBox.shrink();
                                              }
                                              return FactCheckOverlay(ctrl: c);
                                            }),
                                          ),

                                          // Real-Time Live Chat & Superchats Overlay
                                          Positioned(
                                            top: playerHeight < 500 ? 16.0 : 80.0,
                                            bottom: playerHeight < 500 ? 16.0 : 80.0,
                                            right: 20,
                                            width: (playerWidth < 460)
                                                ? (playerWidth - 40)
                                                    .clamp(280.0, 390.0)
                                                : 390,
                                            child: Obx(() {
                                              if (!c.showLiveChat.value) {
                                                return const SizedBox.shrink();
                                              }
                                              final vidId = c.videoController?.video.id ?? c.tag ?? '';
                                              return LiveChatOverlay(
                                                videoId: vidId,
                                                video: c.videoController?.video,
                                                onClose: () => c.showLiveChat.value = false,
                                              );
                                            }),
                                          ),

                                          // Floating action dock is now cleanly elevated into PlayerTopBar
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
                              if (c.isShowingAd.value || c.isPiP.value) {
                                return const SizedBox.shrink();
                              }
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

                            // ── Layer 8: Resolution switching overlay (YouTube-grade seamless background handoff) ──────────────
                            const SizedBox.shrink(),

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

                            // ── Layer 8.7: Fullscreen More Videos Overlay ─────────────
                            Obx(() {
                              c.showMoreVideos.value;
                              c.isFullScreen.value;
                              c.isPiP.value;
                              if (c.showMoreVideos.value &&
                                  c.isFullScreen.value &&
                                  !c.isPiP.value) {
                                return Positioned.fill(
                                  child: FullscreenMoreVideosOverlay(ctrl: c),
                                );
                              }
                              return const SizedBox.shrink();
                            }),

                            // ── Layer 8.8: Guest 10-Minute Playback Limit Barrier ──
                            const GuestPlaybackBarrierOverlay(),

                            // ── Layer 9: Stats for Nerds ───────────────────────────
                            Obx(() {
                              c.showStatsForNerds.value;
                              c.isPiP.value;
                              if (!c.showStatsForNerds.value || c.isPiP.value) {
                                return const SizedBox.shrink();
                              }
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
