import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/theme/app_theme.dart';

class ProgressBar extends StatelessWidget {
  const ProgressBar({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

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
      final hasChapters = ctrl.chapters.length > 1 && dur.inMilliseconds > 0;

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
            var pointerWasDrag = false;
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
                    final thresholdMs = dur.inMilliseconds * 0.015;
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
                    final thresholdMs = dur.inMilliseconds * 0.015;
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Chapter name tooltip on hover/drag
                      if (hasChapters && (hovered || ctrl.isDragging.value))
                        _ChapterTooltip(ctrl: ctrl, barWidth: barWidth),
                      // Progress bar
                      SizedBox(
                        height:
                            hasChapters && (hovered || ctrl.isDragging.value)
                            ? 16
                            : 36,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // ── Segmented chapters OR flat track ──
                            if (hasChapters)
                              _ChapterSegmentedBar(
                                ctrl: ctrl,
                                barWidth: barWidth,
                                played: played,
                                buffered: buffered,
                                hovered: hovered,
                              )
                            else ...[
                              // Flat track (no chapters)
                              SizedBox(
                                width: double.infinity,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  height: hovered || ctrl.isDragging.value
                                      ? PT.kProgressBarHover
                                      : PT.kProgressBarH,
                                  decoration: BoxDecoration(
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.18,
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
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
                                      color: AppColors.textPrimary.withValues(
                                        alpha: 0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                              // Played
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
                                      color: AppColors.error,
                                      borderRadius: BorderRadius.circular(3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.error.withValues(
                                            alpha: 0.6,
                                          ),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            // Claims markers (always shown on top)
                            if ((ctrl
                                        .videoController
                                        ?.video
                                        .uiReport
                                        ?.keyClaims
                                        .isNotEmpty ??
                                    false) &&
                                dur.inMilliseconds > 0)
                              ...ctrl.videoController!.video.uiReport!.keyClaims
                                  .where((c) => c.start != null)
                                  .map((claim) {
                                    final frac =
                                        (claim.start! /
                                                (dur.inMilliseconds / 1000.0))
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
                                                color: AppColors.bgPage
                                                    .withValues(
                                                      alpha: 0.6,
                                                    ),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: verdictColor
                                                      .withValues(
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
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.error.withValues(
                                              alpha: 0.7,
                                            ),
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
    return ClaimVerdictHelper.resolveVerdictString(verdict).color;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHAPTER TOOLTIP — shows current chapter name above the progress bar
// ─────────────────────────────────────────────────────────────────────────────
class _ChapterTooltip extends StatelessWidget {
  const _ChapterTooltip({required this.ctrl, required this.barWidth});
  final TowerPlayerController ctrl;
  final double barWidth;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final chapter = ctrl.currentChapter.value;
      if (chapter == null) return const SizedBox(height: 16);
      return SizedBox(
        height: 16,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            chapter.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHAPTER SEGMENTED BAR — YouTube-style with gaps between chapters
// ─────────────────────────────────────────────────────────────────────────────
class _ChapterSegmentedBar extends StatelessWidget {
  const _ChapterSegmentedBar({
    required this.ctrl,
    required this.barWidth,
    required this.played,
    required this.buffered,
    required this.hovered,
  });
  final TowerPlayerController ctrl;
  final double barWidth;
  final double played;
  final double buffered;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final dur = ctrl.vv.duration;
    final chapters = ctrl.chapters;
    if (chapters.isEmpty || dur.inMilliseconds <= 0) {
      return const SizedBox.shrink();
    }

    final isExpanded = hovered || ctrl.isDragging.value;
    final barHeight = isExpanded ? PT.kProgressBarHover : PT.kProgressBarH;
    // Gap between chapter segments (YouTube uses ~2px)
    const double gapWidth = 2;
    final totalGapWidth = gapWidth * (chapters.length - 1);
    final availableWidth = barWidth - totalGapWidth;
    if (availableWidth <= 0) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: barHeight,
        child: Row(
          children: List.generate(chapters.length * 2 - 1, (i) {
            // Odd indices are gaps
            if (i.isOdd) {
              return const SizedBox(width: gapWidth);
            }

            final chapterIndex = i ~/ 2;
            final chapterStart =
                chapters[chapterIndex].startTime.inMilliseconds;
            final chapterEnd = chapterIndex < chapters.length - 1
                ? chapters[chapterIndex + 1].startTime.inMilliseconds
                : dur.inMilliseconds;
            final chapterDuration = chapterEnd - chapterStart;
            if (chapterDuration <= 0) return const SizedBox.shrink();

            // Width proportional to chapter duration
            final segmentWidth =
                (chapterDuration / dur.inMilliseconds) * availableWidth;

            // Calculate played/buffered fraction within this chapter
            final playedMs = (played * dur.inMilliseconds).clamp(
              0.0,
              dur.inMilliseconds.toDouble(),
            );
            final bufferedMs = (buffered * dur.inMilliseconds).clamp(
              0.0,
              dur.inMilliseconds.toDouble(),
            );

            final chapterPlayedFrac = chapterDuration > 0
                ? ((playedMs - chapterStart) / chapterDuration).clamp(0.0, 1.0)
                : 0.0;
            final chapterBufferedFrac = chapterDuration > 0
                ? ((bufferedMs - chapterStart) / chapterDuration).clamp(
                    0.0,
                    1.0,
                  )
                : 0.0;

            final isCurrent =
                ctrl.currentChapter.value == chapters[chapterIndex];

            return SizedBox(
              width: segmentWidth.clamp(1.0, double.infinity),
              child: Stack(
                children: [
                  // Track background
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Buffered
                  FractionallySizedBox(
                    widthFactor: chapterBufferedFrac,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Played
                  FractionallySizedBox(
                    widthFactor: chapterPlayedFrac,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: isCurrent && isExpanded
                            ? [
                                BoxShadow(
                                  color: AppColors.error.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  spreadRadius: 0.5,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

extension _DurEx on Duration {
  int get inMs => inMilliseconds;
}

// ─────────────────────────────────────────────────────────────────────────────
// VOLUME CONTROL
// ─────────────────────────────────────────────────────────────────────────────
