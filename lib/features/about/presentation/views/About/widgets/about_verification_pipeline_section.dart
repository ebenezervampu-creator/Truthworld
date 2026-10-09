import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Section detailing TruthWorld's 4-step content verification pipeline.
class AboutVerificationPipelineSection extends StatelessWidget {
  const AboutVerificationPipelineSection({
    required this.isDesktop,
    required this.isTablet,
    required this.isMobile,
    super.key,
  });

  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isDesktop ? 80.0 : (isTablet ? 32.0 : 20.0);
    final verticalPadding = isDesktop ? 72.0 : (isTablet ? 48.0 : 36.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      color: AppColors.bgPage,
      child: Column(
        children: [
          Text(
            'How Content Verification Works',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 34 : (isTablet ? 26 : 22),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'A structured four-step pipeline guaranteeing factual integrity and public transparency.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 44),
          Container(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                _buildStepRow(
                  1,
                  'Upload & Automated Claim Extraction',
                  'Upon video upload, the system automatically transcribes audio, identifies factual assertions, and extracts key claims for structured evaluation.',
                ),
                _buildStepRow(
                  2,
                  'Creator Source & Citation Attribution',
                  'Creators attach verifiable source links, academic citations, historical documents, and evidence directly to highlighted claims.',
                ),
                _buildStepRow(
                  3,
                  'Cross-Verification & Consistency Check',
                  'Our verification engine cross-evaluates claims against reputable academic, scientific, and news databases to detect inaccuracies.',
                ),
                _buildStepRow(
                  4,
                  'Public Credibility Scorecard',
                  'Claim-level source grounding replaces opaque binary stamps. Viewers inspect timestamped claims cross-referenced with primary sources, with subjective faith protected and creator dispute rights preserved.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(int step, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.bgSurfaceHover,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.15),
              ),
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
