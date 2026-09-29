import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/app_theme.dart';

class VideoAnalysisMethodologySection extends StatelessWidget {
  const VideoAnalysisMethodologySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Text(
              'How We Score',
              style: GoogleFonts.roboto(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.info_outline,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
        backgroundColor: AppColors.bgSurface,
        collapsedBackgroundColor: AppColors.bgSurface,
        iconColor: AppColors.textPrimary,
        collapsedIconColor: AppColors.textPrimary,
        childrenPadding: const EdgeInsets.all(16.0),
        children: [
          _buildExplanationText(
            'The Trust Score is a weighted average of all 9 factors, adjusted for harm potential and intent to mislead.',
          ),
          const SizedBox(height: 12),
          _buildExplanationText(
            'Confidence reflects how much evidence was available to verify claims. High = strong evidence base. Low = limited data.',
          ),
          const SizedBox(height: 24),
          // TODO: Update weight values when backend provides actual weights
          _buildFactorCard('Accuracy', 'Are the factual claims in this video correct?'),
          _buildFactorCard('Evidence', 'Is the content backed by verifiable evidence and citations?'),
          _buildFactorCard('Consensus', 'Does this align with expert and scientific consensus?'),
          _buildFactorCard('Consistency', 'Is the narrative internally consistent and free of contradictions?'),
          _buildFactorCard('Integrity', 'Is the content presented honestly without deceptive framing?'),
          _buildFactorCard('Expertise', 'Does the creator demonstrate domain expertise on this topic?'),
          _buildFactorCard('Freshness', 'Is the information current and not outdated?'),
          _buildFactorCard('Safety', 'Is the content free from potentially harmful misinformation?'),
          _buildFactorCard('Honesty', 'Are opinions clearly labeled as opinions, not presented as facts?'),
        ],
      ),
    );
  }

  Widget _buildExplanationText(String text) {
    return Text(
      text,
      style: GoogleFonts.roboto(
        color: AppColors.textSecondary,
        fontSize: 14,
        height: 1.4,
      ),
    );
  }

  Widget _buildFactorCard(String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: AppColors.bgDivider.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.roboto(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHigh,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  '11.1%', // Note: This should be updated when backend provides actual weights
                  style: GoogleFonts.roboto(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.roboto(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
