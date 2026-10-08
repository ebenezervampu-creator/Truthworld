import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/storyboard_thumbnail_widget.dart';
import 'package:truthworld/theme/app_theme.dart';

class SeekPreviewTooltip extends StatelessWidget {
  const SeekPreviewTooltip({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Color _getVerdictColor(String verdict) {
    return ClaimVerdictHelper.resolveVerdictString(verdict).color;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final dur = ctrl.vv.duration;
      final pos = ctrl.seekPreviewPos.value;
      final xPct = dur.inMilliseconds > 0
          ? pos.inMilliseconds / dur.inMilliseconds
          : 0.0;

      // Check if we are hovering close to a claim
      ClaimResult? hoveredClaim;
      final vc = ctrl.videoController;
      if (vc != null) {
        final claims = vc.video.uiReport?.keyClaims;
        if (claims != null && claims.isNotEmpty && dur.inMilliseconds > 0) {
          final thresholdMs = dur.inMilliseconds * 0.015; // 1.5% hover snap
          for (final claim in claims) {
            if (claim.start != null) {
              final claimMs = claim.start! * 1000.0;
              if ((pos.inMilliseconds - claimMs).abs() <= thresholdMs) {
                hoveredClaim = claim;
                break;
              }
            }
          }
        }
      }

      return LayoutBuilder(
          builder: (_, c) {
            final xPx = (xPct * c.maxWidth).clamp(52.0, c.maxWidth - 52.0);
            final tooltipWidth = hoveredClaim != null
                ? (c.maxWidth - 32.0).clamp(160.0, 320.0)
                : 160.0;
            final leftPx = (xPx - (tooltipWidth / 2)).clamp(
              16.0,
              (c.maxWidth - tooltipWidth - 16.0).clamp(16.0, c.maxWidth),
            );

            return Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.only(left: leftPx),
                child: Container(
                  width: tooltipWidth,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PT.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PT.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.bgPage.withValues(alpha: 0.65),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Builder(
                    builder: (context) {
                      VideoChapter? activeChapter;
                      for (final ch in ctrl.chapters) {
                        if (pos >= ch.startTime) {
                          activeChapter = ch;
                        }
                      }
                      final remaining = dur > pos ? dur - pos : Duration.zero;

                      final thumbUrl = activeChapter?.thumbnailUrl?.isNotEmpty == true
                          ? activeChapter!.thumbnailUrl
                          : ctrl.videoController?.video.thumbnailUrl;
                      final thumbW = hoveredClaim != null ? 120.0 : 144.0;
                      final thumbH = hoveredClaim != null ? 68.0 : 81.0;

                      final Widget thumbWidget = Stack(
                        children: [
                          Container(
                            width: thumbW,
                            height: thumbH,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.20),
                              ),
                              color: Colors.black54,
                            ),
                            child: StoryboardThumbnailWidget(
                              position: pos,
                              storyboardTrack: ctrl.storyboardTrack.value,
                              fallbackThumbnailUrl: thumbUrl,
                              width: thumbW,
                              height: thumbH,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.80),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Text(
                                _fmt(pos),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );

                      if (hoveredClaim != null) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                thumbWidget,
                                const SizedBox(height: 6),
                                Text(
                                  '${_fmt(pos)} · -${_fmt(remaining)}',
                                  style: TS.time.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (activeChapter != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 3),
                                      child: Text(
                                        activeChapter.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.65),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    hoveredClaim.text,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getVerdictColor(
                                        hoveredClaim.verdict,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: _getVerdictColor(
                                          hoveredClaim.verdict,
                                        ).withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      hoveredClaim.verdict
                                          .toUpperCase()
                                          .replaceAll('_', ' '),
                                      style: TextStyle(
                                        color: _getVerdictColor(
                                          hoveredClaim.verdict,
                                        ),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      // Default (no claim hovered)
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          thumbWidget,
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _fmt(pos),
                                  style: TS.time.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  ' · -${_fmt(remaining)}',
                                  style: TS.time.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (activeChapter != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              activeChapter.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      });
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBTITLE OVERLAY
// ─────────────────────────────────────────────────────────────────────────────

