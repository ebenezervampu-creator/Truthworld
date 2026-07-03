import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

class ProgressBar extends StatelessWidget {
  final TowerPlayerController ctrl;
  const ProgressBar({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final val = ctrl.vv;
      if (!val.isInitialized) return const SizedBox(height: 20);

      final dur = val.duration;
      final pos = ctrl.isDragging.value ? ctrl.dragPos.value : val.position;
      final buf = val.buffered.isNotEmpty
          ? val.buffered.last.end
          : Duration.zero;
      final played = dur.inMs > 0 ? (pos.inMs / dur.inMs).clamp(0.0, 1.0) : 0.0;
      final buffered = dur.inMs > 0
          ? (buf.inMs / dur.inMs).clamp(0.0, 1.0)
          : 0.0;
      final hovered = ctrl.progressBarHovered.value;

      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          ctrl.progressBarHovered.value = true;
          ctrl.onInteraction();
        },
        onExit: (_) => ctrl.progressBarHovered.value = false,
        child: LayoutBuilder(
          builder: (_, constraints) {
            final barWidth = constraints.maxWidth;

            // Use Listener for tap-to-seek (raw pointer events bypass
            // the gesture arena so the outer player GestureDetector
            // cannot steal them). Keep GestureDetector only for drag.
            bool pointerWasDrag = false;
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) {
                pointerWasDrag = false;
                ctrl.onInteraction();
                final frac = (e.localPosition.dx / barWidth).clamp(0.0, 1.0);
                ctrl.dragPos.value = Duration(
                  milliseconds: (dur.inMilliseconds * frac).toInt(),
                );
                ctrl.isDragging.value = true;
              },
              onPointerUp: (e) {
                if (!pointerWasDrag) {
                  final frac = (e.localPosition.dx / barWidth).clamp(0.0, 1.0);
                  final targetMs = dur.inMilliseconds * frac;

                  double? snapSeconds;
                  final claims =
                      ctrl.videoController?.video.uiReport?.keyClaims;
                  if (claims != null &&
                      claims.isNotEmpty &&
                      dur.inMilliseconds > 0) {
                    final double thresholdMs = dur.inMilliseconds * 0.015;
                    for (final claim in claims) {
                      if (claim.start != null) {
                        final claimMs = claim.start! * 1000.0;
                        if ((targetMs - claimMs).abs() <= thresholdMs) {
                          snapSeconds = claim.start;
                          break;
                        }
                      }
                    }
                  }

                  final seekTarget = snapSeconds != null
                      ? Duration(milliseconds: (snapSeconds * 1000).toInt())
                      : Duration(milliseconds: targetMs.toInt());

                  ctrl.seekTo(seekTarget);
                  Future.delayed(const Duration(milliseconds: 200), () {
                    ctrl.isDragging.value = false;
                  });
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) {
                  pointerWasDrag = true;
                  ctrl.onInteraction();
                  ctrl.isDragging.value = true;
                },
                onHorizontalDragUpdate: (d) {
                  ctrl.onInteraction();
                  final frac = (d.localPosition.dx / barWidth).clamp(0.0, 1.0);
                  ctrl.dragPos.value = Duration(
                    milliseconds: (dur.inMs * frac).toInt(),
                  );
                  ctrl.updateSeekPreview(frac, d.localPosition.dx, dur);
                },
                onHorizontalDragEnd: (_) {
                  final targetMs = ctrl.dragPos.value.inMilliseconds;

                  double? snapSeconds;
                  final claims =
                      ctrl.videoController?.video.uiReport?.keyClaims;
                  if (claims != null &&
                      claims.isNotEmpty &&
                      dur.inMilliseconds > 0) {
                    final double thresholdMs = dur.inMilliseconds * 0.015;
                    for (final claim in claims) {
                      if (claim.start != null) {
                        final claimMs = claim.start! * 1000.0;
                        if ((targetMs - claimMs).abs() <= thresholdMs) {
                          snapSeconds = claim.start;
                          break;
                        }
                      }
                    }
                  }

                  final seekTarget = snapSeconds != null
                      ? Duration(milliseconds: (snapSeconds * 1000).toInt())
                      : ctrl.dragPos.value;

                  ctrl.seekTo(seekTarget);
                  ctrl.isDragging.value = false;
                  ctrl.hideSeekPreview();
                },
                onHorizontalDragCancel: () {
                  ctrl.isDragging.value = false;
                  ctrl.hideSeekPreview();
                },
                // Tall tap zone (44 dp) for accessibility
                child: SizedBox(
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Track
                      SizedBox(
                        width: double.infinity,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: hovered || ctrl.isDragging.value
                              ? PT.kProgressBarHover
                              : PT.kProgressBarH,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),

                      // Chapter markers
                      if (ctrl.chapters.isNotEmpty && dur.inMilliseconds > 0)
                        ...ctrl.chapters.skip(1).map((ch) {
                          final frac =
                              (ch.startTime.inMilliseconds / dur.inMilliseconds)
                                  .clamp(0.0, 1.0);
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: frac,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  width: 2,
                                  height: 8,
                                  color: Colors.black.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          );
                        }),

                      // Claims markers
                      if (ctrl
                                  .videoController
                                  ?.video
                                  .uiReport
                                  ?.keyClaims
                                  .isNotEmpty ==
                              true &&
                          dur.inMilliseconds > 0)
                        ...ctrl.videoController!.video.uiReport!.keyClaims
                            .where((c) => c.start != null)
                            .map((claim) {
                              final frac =
                                  (claim.start! / (dur.inMilliseconds / 1000.0))
                                      .clamp(0.0, 1.0);
                              final verdictColor = _getVerdictColor(
                                claim.verdict,
                              );
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: frac,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: verdictColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          width: 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: verdictColor.withValues(
                                              alpha: 0.4,
                                            ),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),

                      // Buffered
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: buffered,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: hovered || ctrl.isDragging.value
                                ? PT.kProgressBarHover
                                : PT.kProgressBarH,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),

                      // Played — NO animation on width for instant seek accuracy
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: played,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: hovered || ctrl.isDragging.value
                                ? PT.kProgressBarHover
                                : PT.kProgressBarH,
                            decoration: BoxDecoration(
                              color: PT.primary,
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: PT.primary.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Thumb — scales on drag/hover
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: played,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: AnimatedScale(
                              scale: ctrl.isDragging.value
                                  ? 1.5
                                  : (hovered ? 1.2 : 1.0),
                              duration: const Duration(milliseconds: 120),
                              child: Container(
                                width: PT.kThumbRadius * 2,
                                height: PT.kThumbRadius * 2,
                                decoration: BoxDecoration(
                                  color: PT.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: PT.primary.withValues(alpha: 0.7),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Color _getVerdictColor(String verdict) {
    switch (verdict.toLowerCase()) {
      case 'verified_true':
      case 'mostly_true':
        return Colors.greenAccent;
      case 'false_claim':
      case 'misleading':
      case 'disputed':
        return Colors.redAccent;
      case 'unproven':
      case 'inconclusive':
      case 'limited_support':
      case 'verification_timeout':
        return Colors.amberAccent;
      default:
        return Colors.blueAccent;
    }
  }
}

extension _DurEx on Duration {
  int get inMs => inMilliseconds;
}

// ─────────────────────────────────────────────────────────────────────────────
// VOLUME CONTROL
// ─────────────────────────────────────────────────────────────────────────────
