import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Semantic verification states for timeline claim indicators.
enum TimelineClaimState {
  verified,
  partiallyVerified,
  contextRequired,
  insufficientEvidence,
  disputed,
}

/// Helper to map verdict strings to semantic verification states, shapes, and colors.
class TimelineClaimHelper {
  TimelineClaimHelper._();

  static TimelineClaimState resolve(String verdict) {
    final lower = verdict.toLowerCase().trim();
    if (lower.contains('verified') || lower.contains('true') || lower.contains('accurate')) {
      return TimelineClaimState.verified;
    } else if (lower.contains('partial') || lower.contains('mostly_true') || lower.contains('half')) {
      return TimelineClaimState.partiallyVerified;
    } else if (lower.contains('context') || lower.contains('caution') || lower.contains('missing')) {
      return TimelineClaimState.contextRequired;
    } else if (lower.contains('false') || lower.contains('disputed') || lower.contains('debunked')) {
      return TimelineClaimState.disputed;
    }
    return TimelineClaimState.insufficientEvidence;
  }

  static Color getColor(TimelineClaimState state) {
    switch (state) {
      case TimelineClaimState.verified:
        return AppColors.success;
      case TimelineClaimState.partiallyVerified:
        return AppColors.warning;
      case TimelineClaimState.contextRequired:
        return AppColors.info;
      case TimelineClaimState.disputed:
        return AppColors.error;
      case TimelineClaimState.insufficientEvidence:
        return AppColors.textSecondary;
    }
  }

  static String getGlyph(TimelineClaimState state) {
    switch (state) {
      case TimelineClaimState.verified:
        return '◆';
      case TimelineClaimState.partiallyVerified:
        return '◇';
      case TimelineClaimState.contextRequired:
        return '●';
      case TimelineClaimState.disputed:
        return '✕';
      case TimelineClaimState.insufficientEvidence:
        return '◯';
    }
  }

  static String getLabel(TimelineClaimState state) {
    switch (state) {
      case TimelineClaimState.verified:
        return 'Claim Verified';
      case TimelineClaimState.partiallyVerified:
        return 'Partially Verified';
      case TimelineClaimState.contextRequired:
        return 'Context Required';
      case TimelineClaimState.disputed:
        return 'Disputed Claim';
      case TimelineClaimState.insufficientEvidence:
        return 'Unverified';
    }
  }
}

/// TruthWorldPlayerTimeline: Dedicated, intelligence-centric video player timeline.
///
/// Features:
///   - High-contrast white brand track (`AppColors.playerTimelinePlayed`) with soft glow.
///   - Dynamic height: 3.5px idle, expanding smoothly to 5.5px on hover or scrub.
///   - Clean chapter markers: YouTube-style 2px segment dividers flush with track.
///   - Intelligence-aware hover preview displaying thumbnail, time, chapter, and claim verdict.
///   - Continuous scrub-locking: prevents controls auto-hide while scrubbing is active.
class TruthWorldPlayerTimeline extends StatelessWidget {
  const TruthWorldPlayerTimeline({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final val = ctrl.vv;
      if (!val.isInitialized) return const SizedBox(height: 16);

      final dur = val.duration;
      final pos = ctrl.isScrubbing.value ? ctrl.scrubPosition.value : val.position;
      final buf = val.buffered.isNotEmpty ? val.buffered.last.end : Duration.zero;

      final played = dur.inMilliseconds > 0
          ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;
      final buffered = dur.inMilliseconds > 0
          ? (buf.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;

      final isExpanded = ctrl.isTimelineHovered.value || ctrl.isScrubbing.value;
      final barHeight = isExpanded ? 5.5 : 3.5;
      final thumbRadius = isExpanded ? 6.0 : 3.5;

      final claims = ctrl.availableClaims;
      final chapters = ctrl.chapters;
      final adBreaks = ctrl.adBreaks;

      return LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth;

          var dragStartY = 0.0;

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) {
              ctrl.onInteraction();
            },
            onHover: (e) {
              ctrl.onInteraction();
              if (dur.inMilliseconds > 0 && barWidth > 0) {
                final frac = (e.localPosition.dx / barWidth).clamp(0.0, 1.0);
                ctrl.updateTimelineHover(frac, e.localPosition.dx, dur, claims: claims);
                ctrl.updateSeekPreview(frac, e.localPosition.dx, dur);
              }
            },
            onExit: (_) {
              ctrl.hideTimelineHover();
              ctrl.hideSeekPreview();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) {
                dragStartY = d.localPosition.dy;
                ctrl.onInteraction();
                if (dur.inMilliseconds > 0 && barWidth > 0) {
                  final frac = (d.localPosition.dx / barWidth).clamp(0.0, 1.0);
                  ctrl.onScrubStart(frac, dur, startX: d.localPosition.dx);
                  ctrl.updateTimelineHover(frac, d.localPosition.dx, dur, claims: claims);
                  ctrl.updateSeekPreview(frac, d.localPosition.dx, dur);
                }
              },
              onPanUpdate: (d) {
                ctrl.onInteraction();
                if (dur.inMilliseconds > 0 && barWidth > 0) {
                  final frac = (d.localPosition.dx / barWidth).clamp(0.0, 1.0);
                  final upwardDisplacement = (dragStartY - d.localPosition.dy).clamp(0.0, 300.0);
                  ctrl.onScrubUpdate(
                    frac,
                    dur,
                    currentX: d.localPosition.dx,
                    upwardDisplacement: upwardDisplacement,
                    barWidth: barWidth,
                    claims: claims,
                    chapters: chapters,
                  );
                  ctrl.updateTimelineHover(frac, d.localPosition.dx, dur, claims: claims);
                  ctrl.updateSeekPreview(frac, d.localPosition.dx, dur);
                }
              },
              onPanEnd: (_) {
                ctrl.onScrubEnd();
                ctrl.hideTimelineHover();
                ctrl.hideSeekPreview();
              },
              onPanCancel: () {
                ctrl.onScrubCancel();
                ctrl.hideTimelineHover();
                ctrl.hideSeekPreview();
              },
              onTapDown: (d) {
                ctrl.onInteraction();
                if (dur.inMilliseconds > 0 && barWidth > 0) {
                  final frac = (d.localPosition.dx / barWidth).clamp(0.0, 1.0);
                  ctrl.seekTo(Duration(milliseconds: (dur.inMilliseconds * frac).toInt()));
                }
                ctrl.hideTimelineHover();
                ctrl.hideSeekPreview();
              },
              onTapUp: (_) {
                ctrl.hideTimelineHover();
                ctrl.hideSeekPreview();
              },
              onTapCancel: () {
                ctrl.hideTimelineHover();
                ctrl.hideSeekPreview();
              },
              child: Container(
                height: 24, // Generous hit-test zone
                alignment: Alignment.center,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    // 1. Background Track
                    Container(
                      width: double.infinity,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: AppColors.playerTimelineBackground,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),

                    // 2. Buffered Track
                    FractionallySizedBox(
                      widthFactor: buffered,
                      child: Container(
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: AppColors.playerTimelineBuffered,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),

                    // 3. Played Track (TruthWorld brand white with subtle glow)
                    FractionallySizedBox(
                      widthFactor: played,
                      child: Container(
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: AppColors.playerTimelinePlayed,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.35),
                              blurRadius: 4,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 4. Clean Chapter Segment Markers (Signature Chapter Accent)
                    if (dur.inMilliseconds > 0 && chapters.length > 1)
                      ...chapters.skip(1).map((chapter) {
                        final chapterFrac = (chapter.startTime.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
                        return Positioned(
                          left: chapterFrac * barWidth - 1,
                          child: Container(
                            width: 2,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: AppColors.playerChapterMarker,
                              borderRadius: BorderRadius.circular(1),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.playerChapterMarker.withValues(alpha: 0.45),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                    // 5. Ad Break Markers (Subtle Amber Ticks)
                    if (dur.inMilliseconds > 0 && adBreaks.isNotEmpty)
                      ...adBreaks.map((cueSec) {
                        final adFrac = ((cueSec * 1000) / dur.inMilliseconds).clamp(0.0, 1.0);
                        return Positioned(
                          left: adFrac * barWidth - 1,
                          child: Container(
                            width: 2,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: AppColors.playerAdMarker,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        );
                      }),

                    // 7. Scrubber Thumb (Smooth expansion on hover or scrub)
                    Positioned(
                      left: (played * barWidth) - thumbRadius,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: thumbRadius * 2,
                        height: thumbRadius * 2,
                        decoration: BoxDecoration(
                          color: AppColors.playerTimelineThumb,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.65),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 8. Floating Precision Scrubbing HUD (iOS / YouTube Style)
                    if (ctrl.isScrubbing.value && ctrl.isPrecisionScrubbing.value)
                      Positioned(
                        bottom: 28,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xE60A0A0E),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.60),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      ctrl.precisionScrubLabel.value,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Drag down to return to 1.0×',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
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
      );
    });
  }
}
