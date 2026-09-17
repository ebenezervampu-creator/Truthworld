import 'package:flutter/material.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_confidence_bar.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_helpers.dart';
import 'package:truthworld/theme/app_theme.dart';

  class VideoAnalysisHeroCard extends StatelessWidget {
  final String analysisState;
  final bool scoreAvailable;
  final double? trustScore;
  final String trustLabel;
  final double confidenceVal;
  final String confidenceTier;
  final int totalClaims;
  final int verifiedCount;
  final int cautionCount;
  final int falseCount;

  const VideoAnalysisHeroCard({
    required this.analysisState,
    required this.scoreAvailable,
    required this.trustScore,
    required this.trustLabel,
    required this.confidenceVal,
    required this.confidenceTier,
    required this.totalClaims,
    required this.verifiedCount,
    required this.cautionCount,
    required this.falseCount,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final trustScore = this.trustScore;
    final hasScore = scoreAvailable && trustScore != null && trustScore > 0;
    final isNotScored = !hasScore || trustLabel.toLowerCase().contains('not scored');

    Color stateColor;
    String badgeText;
    if (!isNotScored) {
      final scoreVal = trustScore > 5 ? trustScore : trustScore * 20;
      stateColor = VideoAnalysisHelpers.getScoreColor(scoreVal);
      badgeText = analysisState.toUpperCase();
    } else if (falseCount > 0 && falseCount >= verifiedCount) {
      stateColor = AppColors.error;
      badgeText = 'DISPUTED CONTENT';
    } else if (cautionCount > 0 && cautionCount > verifiedCount) {
      stateColor = AppColors.warning;
      badgeText = 'CAUTION ADVISED';
    } else {
      stateColor = AppColors.success;
      badgeText = totalClaims > 0 ? 'FACT-CHECK COMPLETE' : 'VERIFIED';
    }

    final headlineTitle = isNotScored
        ? (totalClaims > 0 ? '$totalClaims Claims Evaluated' : 'Qualitative Fact-Check')
        : trustLabel;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: stateColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: stateColor.withValues(alpha: 0.05),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: stateColor.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: stateColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: context.twTypography.overline.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: stateColor,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        if (!isNotScored && confidenceTier.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${confidenceTier.toUpperCase()} CONFIDENCE',
                            style: context.twTypography.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textTertiary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      headlineTitle,
                      style: context.twTypography.title.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Trust Score gauge badge (if score is available)
              if (hasScore) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: VideoAnalysisHelpers.getScoreColor(trustScore > 5 ? trustScore : trustScore * 20).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: VideoAnalysisHelpers.getScoreColor(trustScore > 5 ? trustScore : trustScore * 20).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        trustScore <= 5.0
                            ? '${trustScore.toStringAsFixed(1)} / 5.0'
                            : '${trustScore.toInt()}%',
                        style: context.twTypography.title.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: VideoAnalysisHelpers.getScoreColor(trustScore > 5 ? trustScore : trustScore * 20),
                        ),
                      ),
                      Text(
                        'TRUST INDEX',
                        style: context.twTypography.caption.copyWith(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Confidence Progress Bar or Empirical Claim Breakdown Bar
          const SizedBox(height: 14),
          if (!isNotScored && confidenceVal > 0)
            VideoAnalysisConfidenceBar(value: confidenceVal)
          else if (totalClaims > 0)
            _buildEmpiricalClaimBar(context, totalClaims, verifiedCount, cautionCount, falseCount),
        ],
      ),
    );
  }

  Widget _buildEmpiricalClaimBar(
    BuildContext context,
    int total,
    int verified,
    int caution,
    int falseCount,
  ) {
    if (total == 0) return const SizedBox.shrink();
    final verifiedFactor = verified / total;
    final cautionFactor = caution / total;
    final falseFactor = falseCount / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'EMPIRICAL CLAIM DISTRIBUTION',
              style: context.twTypography.overline.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textTertiary,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              '$verified / $total Verified',
              style: context.twTypography.label.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 6,
            width: double.infinity,
            color: Colors.white.withValues(alpha: 0.08),
            child: Row(
              children: [
                if (verifiedFactor > 0)
                  Expanded(
                    flex: (verifiedFactor * 1000).toInt().clamp(1, 1000),
                    child: Container(color: AppColors.success),
                  ),
                if (cautionFactor > 0)
                  Expanded(
                    flex: (cautionFactor * 1000).toInt().clamp(1, 1000),
                    child: Container(color: AppColors.warning),
                  ),
                if (falseFactor > 0)
                  Expanded(
                    flex: (falseFactor * 1000).toInt().clamp(1, 1000),
                    child: Container(color: AppColors.error),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildClaimLegendDot(context, AppColors.success, '$verified True'),
            const SizedBox(width: 12),
            _buildClaimLegendDot(context, AppColors.warning, '$caution Unconfirmed'),
            if (falseCount > 0) ...[
              const SizedBox(width: 12),
              _buildClaimLegendDot(context, AppColors.error, '$falseCount False'),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildClaimLegendDot(BuildContext context, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: context.twTypography.caption.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

}
