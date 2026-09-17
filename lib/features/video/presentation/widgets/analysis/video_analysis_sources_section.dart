import 'package:flutter/material.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_source_card.dart';
import 'package:truthworld/theme/app_theme.dart';

  class VideoAnalysisSourcesSection extends StatelessWidget {
  final List<dynamic> sources;

  const VideoAnalysisSourcesSection({required this.sources, super.key});

  @override
  Widget build(BuildContext context) {
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
              'VERIFIED SOURCES & CITATIONS (${sources.length})',
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
          itemCount: sources.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final source = sources[index];
            if (source is! Map) return const SizedBox.shrink();
            return VideoAnalysisSourceCard(source: source);
          },
        ),
      ],
    );
  }

}
