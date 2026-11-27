import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_helpers.dart';
import 'package:truthworld/theme/app_theme.dart';

class VideoAnalysisChaptersSection extends StatelessWidget {
  final List<dynamic> chapters;
  final VideoController videoCtrl;

  const VideoAnalysisChaptersSection({
    required this.chapters,
    required this.videoCtrl,
    super.key,
  });

  Duration _resolveNextStart(int index, Duration startDuration) {
    if (index + 1 < chapters.length) {
      final next = chapters[index + 1];
      if (next is VideoChapter) {
        if (next.startTime > startDuration) {
          return next.startTime;
        }
      } else if (next is Map) {
        final nextMs = VideoAnalysisHelpers.resolveClaimTimestampMs(next);
        final nextDuration = Duration(milliseconds: nextMs);
        if (nextDuration > startDuration) {
          return nextDuration;
        }
      }
    }
    if (index == chapters.length - 1 &&
        videoCtrl.video.durationValue > startDuration) {
      return videoCtrl.video.durationValue;
    }
    return Duration.zero;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.bookmarks_outlined,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'CHAPTER CREDIBILITY & KEY TOPICS (${chapters.length})',
              style: context.twTypography.overline.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textTertiary,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: chapters.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final rawItem = chapters[index];
            if (rawItem == null) return const SizedBox.shrink();

            final String title;
            final Duration startDuration;
            Duration endDuration;
            final num? trustIndex;
            final List<dynamic> topics;

            if (rawItem is VideoChapter) {
              final locTitle = rawItem.localizedTitle().trim();
              title = locTitle.isNotEmpty
                  ? locTitle
                  : (rawItem.title.trim().isNotEmpty
                      ? rawItem.title.trim()
                      : 'Chapter ${index + 1}');
              startDuration = rawItem.startTime;
              endDuration = _resolveNextStart(index, startDuration);
              trustIndex = null;
              topics = const [];
            } else if (rawItem is Map) {
              var extractedTitle = (rawItem['title'] ?? rawItem['name'] ?? '').toString().trim();
              if (rawItem['localizedTitles'] is Map) {
                final loc = VideoChapter.fromMap(
                  Map<String, dynamic>.from(rawItem),
                ).localizedTitle();
                if (loc.trim().isNotEmpty) extractedTitle = loc;
              }
              title = extractedTitle.isNotEmpty ? extractedTitle : 'Chapter ${index + 1}';

              final startVal = VideoAnalysisHelpers.resolveClaimTimestampMs(rawItem);
              startDuration = Duration(milliseconds: startVal);

              final endVal = VideoAnalysisHelpers.resolveClaimTimestampMs(rawItem, isEnd: true);
              final parsedEnd = Duration(milliseconds: endVal);

              if (parsedEnd > startDuration) {
                endDuration = parsedEnd;
              } else {
                endDuration = _resolveNextStart(index, startDuration);
              }

              trustIndex = (rawItem['trustIndex'] ??
                  rawItem['trustScore'] ??
                  rawItem['credibilityScore']) as num?;
              topics = (rawItem['primaryTopics'] ?? rawItem['topics'] ?? rawItem['keywords'])
                      as List? ??
                  [];
            } else {
              return const SizedBox.shrink();
            }

            final durationLabel = endDuration > startDuration
                ? '${FormatUtils.formatDuration(startDuration)} - ${FormatUtils.formatDuration(endDuration)}'
                : FormatUtils.formatDuration(startDuration);

            return InkWell(
              onTap: () {
                final playerCtrl = TowerPlayerController.getForTagOrActive(videoCtrl.video.id);
                if (playerCtrl != null) {
                  unawaited(playerCtrl.seekTo(startDuration));
                } else if (videoCtrl.videoPlayerController != null &&
                    videoCtrl.videoPlayerController!.value.isInitialized) {
                  videoCtrl.videoPlayerController!.seekTo(startDuration);
                  videoCtrl.videoPlayerController!.play();
                }
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Get.back();
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bgDivider.withValues(alpha: 0.7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_arrow_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                durationLabel,
                                style: context.twTypography.caption.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                  fontFamily: TWTypography.uiFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (trustIndex != null) ...[
                          _buildChapterTrustBadge(context, trustIndex),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: context.twTypography.title.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontFamily: TWTypography.uiFamily,
                      ),
                    ),
                    if (topics.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: topics.map((t) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              t.toString(),
                              style: context.twTypography.caption.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                                fontFamily: TWTypography.uiFamily,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildChapterTrustBadge(BuildContext context, num trustIndex) {
    final String label;
    if (trustIndex <= 10.0) {
      label = trustIndex.toStringAsFixed(1);
    } else {
      label = '${trustIndex.toInt()}%';
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star_rounded,
              size: 12,
              color: Colors.white,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: context.twTypography.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: TWTypography.uiFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
