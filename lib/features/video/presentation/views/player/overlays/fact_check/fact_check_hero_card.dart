import 'package:flutter/material.dart';
import 'package:truthworld/core/widgets/truth_lottie_animation.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/fact_check/fact_check_models_helper.dart';
import 'package:truthworld/theme/app_theme.dart';

  class FactCheckHeroCard extends StatelessWidget {
  const FactCheckHeroCard({
    required this.analysisState,
    required this.trustScore,
    required this.trustLabel,
    required this.confidenceVal,
    required this.confidenceTier,
    required this.isFactChecked,
    required this.totalClaims,
    required this.verifiedCount,
    required this.cautionCount,
    required this.falseCount,
    super.key,
  });

  final String analysisState;
  final double? trustScore;
  final String trustLabel;
  final double confidenceVal;
  final String confidenceTier;
  final bool isFactChecked;
  final int totalClaims;
  final int verifiedCount;
  final int cautionCount;
  final int falseCount;

  @override
  Widget build(BuildContext context) {
    final score = trustScore;
    final hasScore = score != null && score > 0;
    final isNotScored = !hasScore || trustLabel.toLowerCase().contains('not scored');

    final displayScore = score != null
        ? (score > 5.0 ? score.toInt() : (score * 20).toInt())
        : null;

    const stateColor = Colors.white;
    String badgeText;
    if (!isNotScored && displayScore != null) {
      badgeText = analysisState.toUpperCase();
    } else if (falseCount > 0 && falseCount >= verifiedCount) {
      badgeText = 'DISPUTED CONTENT';
    } else if (cautionCount > 0 && cautionCount > verifiedCount) {
      badgeText = 'CAUTION ADVISED';
    } else {
      badgeText = totalClaims > 0 ? 'FACT-CHECK COMPLETE' : 'VERIFIED';
    }

    final headlineTitle = isNotScored
        ? (totalClaims > 0 ? '$totalClaims Claims Evaluated' : 'Qualitative Fact-Check')
        : trustLabel;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: stateColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: stateColor.withValues(alpha: 0.06),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Circular score badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: stateColor, width: 2),
                ),
                alignment: Alignment.center,
                child: displayScore != null
                    ? Text(
                        '$displayScore%',
                        style: const TextStyle(
                          color: stateColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : TruthLottieAnimation.verifiedShield(size: 26),
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
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: stateColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: stateColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        if (!isNotScored && confidenceTier.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${confidenceTier.toUpperCase()} CONFIDENCE',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textTertiary,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      headlineTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      isFactChecked
                          ? 'Epistemic Trust Engine Verified'
                          : 'Community & AI Corroborated',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!isNotScored && confidenceVal > 0)
            _buildConfidenceBar(confidenceVal)
          else if (totalClaims > 0)
            _buildEmpiricalClaimBar(totalClaims, verifiedCount, cautionCount, falseCount),
        ],
      ),
    );
  }

  Widget _buildEmpiricalClaimBar(
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
            const Text(
              'EMPIRICAL CLAIM DISTRIBUTION',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.textTertiary,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              '$verified / $total Verified',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Container(
            height: 5,
            width: double.infinity,
            color: Colors.white.withValues(alpha: 0.08),
            child: Row(
              children: [
                if (verifiedFactor > 0)
                  Expanded(
                    flex: (verifiedFactor * 1000).toInt().clamp(1, 1000),
                    child: Container(color: Colors.white),
                  ),
                if (cautionFactor > 0)
                  Expanded(
                    flex: (cautionFactor * 1000).toInt().clamp(1, 1000),
                    child: Container(color: Colors.white.withValues(alpha: 0.55)),
                  ),
                if (falseFactor > 0)
                  Expanded(
                    flex: (falseFactor * 1000).toInt().clamp(1, 1000),
                    child: Container(color: Colors.white.withValues(alpha: 0.20)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _claimLegendDot(Colors.white, '$verified True'),
            const SizedBox(width: 10),
            _claimLegendDot(Colors.white.withValues(alpha: 0.55), '$caution Unconfirmed'),
            if (falseCount > 0) ...[
              const SizedBox(width: 10),
              _claimLegendDot(Colors.white.withValues(alpha: 0.25), '$falseCount False'),
            ],
          ],
        ),
      ],
    );
  }

  Widget _claimLegendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceBar(double value) {
    final clamped = value.clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'SYSTEM CONFIDENCE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.textTertiary,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              '${(clamped * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: clamped),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, animVal, _) {
            return Stack(
              children: [
                Container(
                  height: 5,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: animVal,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  }

class ViewerNoteCard extends StatelessWidget {
  const ViewerNoteCard({
    required this.note,
    super.key,
  });

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 14,
                color: Colors.white,
              ),
              SizedBox(width: 6),
              Text(
                'AI VIEWER ADVISORY & SUMMARY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brand,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  }

class FactorsCard extends StatelessWidget {
  const FactorsCard({
    required this.factors,
    super.key,
  });

  final Map<dynamic, dynamic> factors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 14,
                color: Colors.white,
              ),
              SizedBox(width: 6),
              Text(
                'CREDIBILITY FACTORS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textTertiary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...factors.entries.map((e) {
            final key = e.key.toString();
            final val = e.value;
            final label = formatFactorKey(key);
            final numVal = (val is num) ? val.toDouble() : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Text(
                    numVal <= 5.0 && numVal > 0
                        ? '${numVal.toStringAsFixed(1)} / 5.0'
                        : (numVal > 5 ? '${numVal.toInt()}%' : val.toString()),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }


}
