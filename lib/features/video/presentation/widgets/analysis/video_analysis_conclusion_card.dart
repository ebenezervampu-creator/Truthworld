import 'package:flutter/material.dart';
import 'package:truthworld/core/utils/source_url_sanitizer.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_source_card.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Card rendering the synthesized credibility conclusion along with its supporting sources.
class VideoAnalysisConclusionCard extends StatelessWidget {
  const VideoAnalysisConclusionCard({
    required this.conclusion,
    this.sources = const [],
    this.showSources = false,
    super.key,
  });

  final String conclusion;
  final List<dynamic> sources;
  final bool showSources;

  @override
  Widget build(BuildContext context) {
    final cleanConclusion = ClaimVerdictHelper.humanizeConclusionText(
      UserFeedbackSanitizer.sanitizeViewerNote(conclusion),
    ).replaceAll(RegExp(r'\s*\n+\s*'), ' ').trim();
    if (cleanConclusion.isEmpty) return const SizedBox.shrink();

    final validSources = sources.where(SourceUrlSanitizer.isValidSource).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                'VERIFIED CONCLUSION',
                style: context.twTypography.overline.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brand,
                  letterSpacing: 1.0,
                  fontFamily: TWTypography.uiFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            cleanConclusion,
            style: context.twTypography.body.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              height: 1.5,
              fontFamily: TWTypography.uiFamily,
            ),
          ),
          if (showSources && validSources.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: AppColors.bgDivider.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.auto_stories_outlined,
                  size: 14,
                  color: Colors.white70,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'SUPPORTING SOURCES & CITATIONS (${validSources.length})',
                    style: context.twTypography.overline.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                      fontFamily: TWTypography.uiFamily,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              children: validSources
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: VideoAnalysisSourceCard(
                        source: (s is UISource)
                            ? s.toMap()
                            : (s is Map
                                ? Map<dynamic, dynamic>.from(s)
                                : {'title': s.toString()}),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
