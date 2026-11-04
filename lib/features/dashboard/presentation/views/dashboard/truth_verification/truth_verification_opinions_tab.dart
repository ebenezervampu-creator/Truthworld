import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Tab dedicated to Subjective Opinions, Beliefs, and Non-Falsifiable Expressions.
///
/// Directly inspired by the Consumer App's "Ai Check" opinions and beliefs tab:
/// - Distinguishes between verifiable empirical propositions and subjective viewpoints
/// - Educational framing demonstrating that opinions are not penalized by TruthWorld
/// - Clear categorization badges (OPINION, PHILOSOPHY, SATIRE, PREDICTION)
class TruthVerificationOpinionsTab extends StatelessWidget {
  const TruthVerificationOpinionsTab({
    required this.opinionClaims,
    required this.isDarkMode,
    super.key,
  });

  final List<RealExtractedClaim> opinionClaims;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Epistemic Demarcation Banner
        _buildDemarcationBanner(),
        const SizedBox(height: 16),

        // 2. Opinion Claims List or Empty State
        if (opinionClaims.isEmpty)
          _buildEmptyOpinionsState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: opinionClaims.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final claim = opinionClaims[index];
              return _buildOpinionCard(claim);
            },
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDemarcationBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.bgSurface,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.bgSurface),
            ),
            child: const Icon(
              Icons.psychology_outlined,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Epistemic Fairness: Opinions & Creative Expression',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'TruthWorld\'s Credibility Engine does not penalize subjective viewpoints, personal commentary, hyperbole, satire, or artistic expression. Only empirical factual propositions are subjected to verification. Non-falsifiable assertions are cataloged below to ensure platform transparency.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpinionCard(RealExtractedClaim claim) {
    final natureLabel = claim.nature.toUpperCase();
    final effectiveLabel = (natureLabel == 'FACT' || natureLabel.isEmpty)
        ? 'SUBJECTIVE VIEWPOINT'
        : natureLabel;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.bgSurface,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.bgSurface,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.format_quote_rounded,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      effectiveLabel,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.bgSurface),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 11,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      claim.timestamp,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'Excluded from Penalty',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"${claim.text}"',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.movie_outlined,
                size: 13,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Video: ${claim.videoTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOpinionsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.bgSurface,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bgSurface),
            ),
            child: const Icon(
              Icons.psychology_outlined,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Zero Subjective Assertions Flagged',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'All evaluated dialogue in this channel currently consists of either verified empirical statements or general dialogue. When subjective viewpoints, predictions, or philosophical statements are detected, they appear here without negatively impacting your TruthScore.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
