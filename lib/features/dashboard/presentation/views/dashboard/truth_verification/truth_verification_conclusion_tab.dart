import 'package:flutter/material.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Tab dedicated to Conclusion, Epistemic Health, and Algorithmic Discovery Advantage.
///
/// Directly inspired by the Consumer App's "Ai Check" conclusion card and recommendations:
/// - Overall Channel Epistemic Verdict & Authenticity Grade
/// - Algorithmic Distribution Advantage breakdown (+15% to 20% Discovery Rank Boost)
/// - Concrete actionable AI recommendations for channel creators
class TruthVerificationConclusionTab extends StatelessWidget {
  const TruthVerificationConclusionTab({
    required this.videos,
    required this.allClaims,
    required this.isDarkMode,
    required this.onSwitchToTab,
    super.key,
  });

  final List<VideoFactCheckItem> videos;
  final List<RealExtractedClaim> allClaims;
  final bool isDarkMode;
  final ValueChanged<int> onSwitchToTab;

  @override
  Widget build(BuildContext context) {
    final verifiedCount = allClaims.where((c) => c.isVerified).length;
    final cautionCount = allClaims.where((c) => c.isNeedsSource).length;
    final falseCount = allClaims.where((c) => c.isHighConcern).length;
    final totalClaims = allClaims.length;

    final authenticityIndex = totalClaims > 0 ? (verifiedCount / totalClaims) : 1.0;
    final authenticityPct = (authenticityIndex * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Channel Epistemic Verdict Hero Card
        _buildEpistemicVerdictHero(authenticityPct, totalClaims, verifiedCount, falseCount),
        const SizedBox(height: 16),

        // 2. Algorithmic Advantage & Discovery Rank Boost Card
        _buildAlgorithmicAdvantageCard(),
        const SizedBox(height: 16),

        // 3. Actionable AI Recommendations for Creators
        _buildActionableRecommendations(cautionCount, falseCount),
        const SizedBox(height: 16),

        // 4. Platform Epistemic Standards & Appeal Assurance
        _buildStandardsAssuranceCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEpistemicVerdictHero(
    int authenticityPct,
    int totalClaims,
    int verifiedCount,
    int falseCount,
  ) {
    const cardBg = AppColors.appBarSurface;
    const borderColor = AppColors.bgSurface;
    const textCol = Colors.white;

    String verdictTitle = 'Consensus Grounded (Grade A)';
    String verdictDescription =
        'Your channel demonstrates exceptional factual grounding. Evaluated empirical claims are substantiated by primary registries with zero critical inaccuracies.';
    Color verdictColor = AppColors.success;
    IconData verdictIcon = Icons.verified_rounded;

    if (falseCount > 0 || authenticityPct < 75) {
      verdictTitle = 'Attention Recommended (Grade C)';
      verdictDescription =
          'Certain assertions have been flagged for missing primary evidence or potential discrepancies. Resolve flagged items to maintain maximum recommendation priority.';
      verdictColor = AppColors.error;
      verdictIcon = Icons.warning_rounded;
    } else if (authenticityPct < 90) {
      verdictTitle = 'Solid Verification Record (Grade B)';
      verdictDescription =
          'Good overall credibility with high viewer trust. Adding primary source citations to flagged claims will elevate your channel to top-tier status.';
      verdictColor = AppColors.warning;
      verdictIcon = Icons.thumb_up_alt_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.bgSurface,
                  ),
                ),
                child: Center(
                  child: Icon(verdictIcon, color: verdictColor, size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verdictTitle,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: textCol,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'TruthScore Metric: $authenticityPct% ($verifiedCount of $totalClaims claims corroborated)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            verdictDescription,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlgorithmicAdvantageCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.bgSurface),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '15% to 20% Algorithmic Discovery Advantage',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'TruthWorld prioritizes authentic, empirical journalism and verified educational content. Channels that maintain verified status receive a programmatic distribution multiplier across:',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _buildBenefitRow('Home Feed Unexplored Tab: Priority placement ahead of unverified uploads.'),
          _buildBenefitRow('Epistemic Search Ranking: Boosted relevance scores for factual queries.'),
          _buildBenefitRow('Player Truth Badge: Green verified badge displayed prominently on viewer screens.'),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 14,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionableRecommendations(int cautionCount, int falseCount) {
    const cardBg = AppColors.appBarSurface;
    const borderColor = AppColors.bgSurface;

    final recommendations = [
      {
        'title': 'Cite Primary Databases for Numerical Claims',
        'desc': 'When mentioning statistics, economic figures, or scientific metrics, cite official agencies or peer-reviewed papers.',
        'action': 'Explore Citations',
        'tab': 4,
      },
      if (cautionCount > 0)
        {
          'title': 'Resolve $cautionCount "Needs Evidence" Assertions',
          'desc': 'Attach external URLs to unverified claims to boost them from caution to verified status.',
          'action': 'Review Flagged Claims',
          'tab': 0,
        },
      {
        'title': 'Use Clear Disclosures for Personal Hypotheses',
        'desc': 'Frame speculative thoughts with "In my opinion" or "I predict" to automatically route them into the subjective ledger.',
        'action': 'View Opinions Tab',
        'tab': 3,
      },
      {
        'title': 'Engage the AI Truth Coach Before Uploading',
        'desc': 'Test scripts or claim propositions with the integrated Truth Coach to preview verification feasibility.',
        'action': 'Talk to AI Coach',
        'tab': 7,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actionable AI Recommendations for Your Channel',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Targeted steps generated by TruthWorld\'s Credibility Engine to maximize your TruthScore.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          ...recommendations.map((rec) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.bgSurface,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rec['title'] as String,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          rec['desc'] as String,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => onSwitchToTab(rec['tab'] as int),
                    child: Text(
                      rec['action'] as String,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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

  Widget _buildStandardsAssuranceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icons.gavel_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Epistemic Dispute & Re-evaluation Guarantee',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'If you believe a claim verdict contradicts newly published empirical evidence, you can dispute any claim anytime from the Fact Claims tab. TruthWorld re-evaluates disputed claims with updated source grounding within 24 hours.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
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
}
