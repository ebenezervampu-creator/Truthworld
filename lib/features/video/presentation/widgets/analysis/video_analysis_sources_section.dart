import 'package:flutter/material.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_source_card.dart';
import 'package:truthworld/theme/app_theme.dart';

class VideoAnalysisSourcesSection extends StatelessWidget {
  final List<dynamic> sources;

  const VideoAnalysisSourcesSection({required this.sources, super.key});

  @override
  Widget build(BuildContext context) {
    final validSources =
        sources.where(SourceUrlSanitizer.isValidSource).toList();
    if (validSources.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.auto_stories_rounded,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              'VERIFIED SOURCES & CITATIONS (${validSources.length})',
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
          itemCount: validSources.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final source = validSources[index];
            final sourceMap = source is UISource
                ? source.toMap()
                : (source is Map ? source : null);
            if (sourceMap == null) return const SizedBox.shrink();
            return VideoAnalysisSourceCard(source: sourceMap);
          },
        ),
      ],
    );
  }
}
