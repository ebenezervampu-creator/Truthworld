import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/format_utils.dart';
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
            final item = chapters[index] as Map?;
            if (item == null) return const SizedBox.shrink();

            final title = (item['title'] ?? 'Chapter ${index + 1}').toString();
            final rawStart = item['start'] ?? item['startMs'] ?? item['startTime'] ?? item['startTimeMs'] ?? 0;
            final rawEnd = item['end'] ?? item['endMs'] ?? item['endTime'] ?? item['endTimeMs'] ?? 0;

            final startVal = VideoAnalysisHelpers.normalizeTimestampToMs(rawStart);
            final endVal = VideoAnalysisHelpers.normalizeTimestampToMs(rawEnd);

            final startDuration = Duration(milliseconds: startVal);
            final endDuration = Duration(milliseconds: endVal);
            final trustIndex = item['trustIndex'] as num?;
            final topics = (item['primaryTopics'] ?? item['topics']) as List? ?? [];

            return InkWell(
              onTap: () {
                if (videoCtrl.videoPlayerController != null &&
                    videoCtrl.videoPlayerController!.value.isInitialized) {
                  videoCtrl.videoPlayerController!.seekTo(startDuration);
                  videoCtrl.videoPlayerController!.play();
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
                                '${FormatUtils.formatDuration(startDuration)} - ${FormatUtils.formatDuration(endDuration)}',
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
