import 'package:flutter/material.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/fact_check/fact_check_models_helper.dart';
import 'package:truthworld/theme/app_theme.dart';

  class FactCheckChaptersSection extends StatelessWidget {
  const FactCheckChaptersSection({
    required this.chapters,
    required this.ctrl,
    super.key,
  });

  final List<dynamic> chapters;
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.bookmarks_outlined,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              'CHAPTER CREDIBILITY & TOPICS (${chapters.length})',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textTertiary,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...chapters.map((item) {
          if (item is! Map) return const SizedBox.shrink();          final title = (item['title'] ?? 'Chapter').toString();
          final rawStart = item['start'] ??
              item['startMs'] ??
              item['startTime'] ??
              item['startTimeMs'] ??
              0;
          final rawEnd = item['end'] ??
              item['endMs'] ??
              item['endTime'] ??
              item['endTimeMs'] ??
              0;

          final startVal = normalizeTimestampToMs(rawStart);
          final endVal = normalizeTimestampToMs(rawEnd);

          final startDuration = Duration(milliseconds: startVal);
          final endDuration = Duration(milliseconds: endVal);
          final trustIndex = item['trustIndex'] as num?;
          final topics =
              (item['primaryTopics'] ?? item['topics']) as List? ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        ctrl.seekTo(startDuration);
                        ctrl.videoPlayerController.play();
                        ctrl.showToast('Playing Chapter: $title');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: 0.12),
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
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (trustIndex != null) ...[
                      () {
                        final double score100;
                        final String label;
                        if (trustIndex <= 10.0) {
                          score100 = trustIndex * 10.0;
                          label = trustIndex.toStringAsFixed(1);
                        } else {
                          score100 = trustIndex.toDouble();
                          label = '${trustIndex.toInt()}%';
                        }
                        final color = getScoreColor(score100);

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: color.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        );
                      }(),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (topics.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: topics.map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.brand.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          t.toString(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}
