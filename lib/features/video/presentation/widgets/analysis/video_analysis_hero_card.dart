import 'package:flutter/material.dart';
import 'package:truthworld/core/widgets/truth_credibility_badge.dart';
import 'package:truthworld/core/widgets/truth_lottie_animation.dart';
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
  final String? tierBadgeLabel;

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
    this.tierBadgeLabel,
    super.key,
  });

  bool get isNotScored => totalClaims == 0 || !scoreAvailable || trustScore == null;

  @override
  Widget build(BuildContext context) {
    final String badgeText;
    if (totalClaims == 0) {
      badgeText = 'UNASSESSED';
    } else if (falseCount > 0 && falseCount >= verifiedCount) {
      badgeText = 'DISPUTED CONTENT';
    } else if (cautionCount > 0 && cautionCount > verifiedCount) {
      badgeText = 'CAUTION ADVISED';
    } else {
      badgeText = 'CLAIM LEDGER VERIFIED';
    }

    final headlineTitle = totalClaims == 0
        ? 'No Claims Assessed'
        : '$totalClaims Claims Evaluated';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bgDivider.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) => Transform.scale(
                  scale: scale,
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: TruthLottieAnimation.verifiedShield(
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        TruthCredibilityBadge(
                          label: badgeText,
                          color: Colors.white,
                          isVerified: !isNotScored || falseCount == 0,
                          isDisputed: falseCount > 0 || cautionCount > 0,
                          isFalse: falseCount > 0 && falseCount >= verifiedCount,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                        ),
                        if (tierBadgeLabel != null && tierBadgeLabel!.isNotEmpty && totalClaims > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              tierBadgeLabel!.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        if (!isNotScored && confidenceTier.isNotEmpty)
                          Text(
                            '${confidenceTier.toUpperCase()} CONFIDENCE',
                            style: context.twTypography.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textTertiary,
                              letterSpacing: 0.8,
                              fontFamily: TWTypography.uiFamily,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      headlineTitle,
                      style: context.twTypography.title.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontFamily: TWTypography.uiFamily,
                      ),
                    ),
                  ],
                ),
              ),

              // Claim Ledger count badge (Zero Video Trust Score Policy)
              if (totalClaims > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$totalClaims',
                        style: context.twTypography.title.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: TWTypography.uiFamily,
                        ),
                      ),
                      Text(
                        'CLAIMS',
                        style: context.twTypography.caption.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textTertiary,
                          letterSpacing: 0.5,
                          fontFamily: TWTypography.uiFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Empirical Claim Breakdown Bar
          const SizedBox(height: 14),
          if (totalClaims > 0)
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
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, animFactor, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 6,
                width: double.infinity,
                color: Colors.white.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    if (verifiedFactor > 0)
                      Expanded(
                        flex: (verifiedFactor * 1000 * animFactor).toInt().clamp(1, 1000),
                        child: Container(color: Colors.white),
                      ),
                    if (cautionFactor > 0)
                      Expanded(
                        flex: (cautionFactor * 1000 * animFactor).toInt().clamp(1, 1000),
                        child: Container(color: Colors.white.withValues(alpha: 0.55)),
                      ),
                    if (falseFactor > 0)
                      Expanded(
                        flex: (falseFactor * 1000 * animFactor).toInt().clamp(1, 1000),
                        child: Container(color: Colors.white.withValues(alpha: 0.20)),
                      ),
                    if (animFactor < 1.0)
                      Expanded(
                        flex: ((1.0 - animFactor) * 1000).toInt().clamp(1, 1000),
                        child: const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildClaimLegendDot(context, Colors.white, '$verified True'),
            const SizedBox(width: 12),
            _buildClaimLegendDot(context, Colors.white.withValues(alpha: 0.55), '$caution Unconfirmed'),
            if (falseCount > 0) ...[
              const SizedBox(width: 12),
              _buildClaimLegendDot(context, Colors.white.withValues(alpha: 0.25), '$falseCount False'),
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
