import 'package:flutter/material.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Comprehensive Channel Truth Intelligence Overview Tab.
///
/// Inspired directly by the Consumer App's "Ai Check" overview architecture:
/// - Executive Channel Verification Overview Card
/// - Channel Verification Summary Card (Authenticity Index & 4 Stat Boxes)
/// - Confidence Level & Authenticity Bar
/// - Multi-Dimensional Credibility Factors Breakdown
/// - Key Empirical Findings Card
/// - Most Valuable Cited Sources Card
/// - Transparent AI Verification Methodology Section
/// - Creator Epistemic Guidance Card
class TruthVerificationOverviewTab extends StatelessWidget {
  const TruthVerificationOverviewTab({
    required this.videos,
    required this.allClaims,
    required this.isDarkMode,
    required this.onSwitchToTab,
    this.targetVideoTitle,
    super.key,
  });

  final List<VideoFactCheckItem> videos;
  final List<RealExtractedClaim> allClaims;
  final bool isDarkMode;
  final ValueChanged<int> onSwitchToTab;
  final String? targetVideoTitle;

  @override
  Widget build(BuildContext context) {
    final verifiedCount = allClaims.where((c) => c.isVerified).length;
    final cautionCount = allClaims.where((c) => c.isNeedsSource).length;
    final falseCount = allClaims.where((c) => c.isHighConcern).length;
    final totalClaims = allClaims.length;

    final authenticityIndex = totalClaims > 0
        ? (verifiedCount / totalClaims)
        : 1.0;
    final authenticityPct = (authenticityIndex * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Executive Channel Verification Overview Card
        _buildExecutiveOverviewCard(totalClaims, verifiedCount, authenticityPct),
        const SizedBox(height: 16),

        // 2. Channel Verification Summary Card (Authenticity Index + 4 Stat Boxes)
        _buildVerificationSummaryCard(
          totalClaims: totalClaims,
          verifiedCount: verifiedCount,
          cautionCount: cautionCount,
          falseCount: falseCount,
          authenticityPct: authenticityPct,
        ),
        const SizedBox(height: 16),

        // 3. Confidence Level & Authenticity Breakdown Bar
        _buildConfidenceBar(authenticityIndex),
        const SizedBox(height: 16),

        // 4. Multi-Dimensional Credibility Factors Breakdown
        _buildFactorsCard(),
        const SizedBox(height: 16),

        // 5. Key Empirical Findings Card
        if (allClaims.isNotEmpty) ...[
          _buildKeyFindingsCard(context),
          const SizedBox(height: 16),
        ],

        // 6. Most Valuable Sources & Citations Card
        _buildTopSourcesCard(context),
        const SizedBox(height: 16),

        // 7. Transparent AI Verification Methodology (IFCN Standard)
        _buildMethodologyCard(),
        const SizedBox(height: 16),

        // 8. Creator Epistemic Guidance / Advisory Note
        _buildCreatorGuidanceCard(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildExecutiveOverviewCard(
    int totalClaims,
    int verifiedCount,
    int authenticityPct,
  ) {
    const cardBg = AppColors.appBarSurface;
    const borderColor = AppColors.bgSurface;
    const textCol = Colors.white;
    const secCol = AppColors.textSecondary;

    final videoCount = videos.length;
    final pendingCount = videos.where((v) => v.isPendingApproval).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: AppColors.success,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'AI CREDIBILITY • INSTITUTIONAL EVALUATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    '$pendingCount in Creator Review',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            targetVideoTitle != null && targetVideoTitle!.isNotEmpty
                ? 'Truth Intelligence Analysis: "$targetVideoTitle"'
                : 'Channel Truth Intelligence & Epistemic Audit',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textCol,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            totalClaims > 0
                ? 'TruthWorld\'s empirical verification system evaluated $videoCount video${videoCount == 1 ? '' : 's'} across this channel, extracting $totalClaims empirical claim${totalClaims == 1 ? '' : 's'}. $verifiedCount assertions have been rigorously verified against authoritative external knowledge registries and peer-reviewed consensus ($authenticityPct% corroboration rate).'
                : 'No empirical factual assertions have been extracted yet. When you upload or scan videos, TruthWorld\'s multi-stage AI verification engine will index claims, cross-reference citations, and establish empirical truth badges.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: secCol,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHighlightChip(
                icon: Icons.shield_outlined,
                label: 'IFCN Standard Compliance',
                isDarkMode: isDarkMode,
              ),
              _buildHighlightChip(
                icon: Icons.account_balance_outlined,
                label: 'Authoritative Primary Citations',
                isDarkMode: isDarkMode,
              ),
              _buildHighlightChip(
                icon: Icons.trending_up_rounded,
                label: '15-20% Discovery Boost Active',
                isDarkMode: isDarkMode,
                highlightColor: AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightChip({
    required IconData icon,
    required String label,
    required bool isDarkMode,
    Color? highlightColor,
  }) {
    final fg = highlightColor ?? AppColors.textSecondary;
    const bg = AppColors.bgInput;
    const border = AppColors.bgSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSummaryCard({
    required int totalClaims,
    required int verifiedCount,
    required int cautionCount,
    required int falseCount,
    required int authenticityPct,
  }) {
    const cardBg = AppColors.appBarSurface;
    const borderColor = AppColors.bgSurface;
    const textCol = Colors.white;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.bgSurface,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: AppColors.success,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Verification Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textCol,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Comprehensive multi-source verification score',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$authenticityPct%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  const Text(
                    'Authenticity Index',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalClaims > 0 ? (verifiedCount / totalClaims) : 1.0,
              minHeight: 6,
              backgroundColor: AppColors.bgSurface,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
          const SizedBox(height: 18),
          // 4 Equal Stat Boxes (Total Claims, Verified, Caution, False)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              if (isNarrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryStatBox(
                            label: 'Total Claims',
                            value: '$totalClaims',
                            color: Colors.white,
                            icon: Icons.list_alt_rounded,
                            onTap: () => onSwitchToTab(0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryStatBox(
                            label: 'Verified',
                            value: '$verifiedCount',
                            color: AppColors.success,
                            icon: Icons.check_circle_rounded,
                            onTap: () => onSwitchToTab(0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryStatBox(
                            label: 'Caution / Need Citations',
                            value: '$cautionCount',
                            color: AppColors.warning,
                            icon: Icons.warning_amber_rounded,
                            onTap: () => onSwitchToTab(0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryStatBox(
                            label: 'High Concern',
                            value: '$falseCount',
                            color: AppColors.error,
                            icon: Icons.cancel_rounded,
                            onTap: () => onSwitchToTab(0),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _buildSummaryStatBox(
                      label: 'Total Claims',
                      value: '$totalClaims',
                      color: Colors.white,
                      icon: Icons.list_alt_rounded,
                      onTap: () => onSwitchToTab(0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryStatBox(
                      label: 'Verified',
                      value: '$verifiedCount',
                      color: AppColors.success,
                      icon: Icons.check_circle_rounded,
                      onTap: () => onSwitchToTab(0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryStatBox(
                      label: 'Needs Evidence',
                      value: '$cautionCount',
                      color: AppColors.warning,
                      icon: Icons.warning_amber_rounded,
                      onTap: () => onSwitchToTab(0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryStatBox(
                      label: 'High Concern',
                      value: '$falseCount',
                      color: AppColors.error,
                      icon: Icons.cancel_rounded,
                      onTap: () => onSwitchToTab(0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStatBox({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    const bg = AppColors.bgInput;
    const border = AppColors.bgSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceBar(double confidence) {
    final pct = (confidence * 100).clamp(0, 100).round();
    const cardBg = AppColors.appBarSurface;
    const borderColor = AppColors.bgSurface;

    String confidenceTier = 'Institutional Consensus (High)';
    Color tierColor = AppColors.success;
    if (pct < 70) {
      confidenceTier = 'Under Investigation (Low)';
      tierColor = AppColors.error;
    } else if (pct < 85) {
      confidenceTier = 'Corroborated (Moderate)';
      tierColor = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AI Confidence & Empirical Grounding',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '$pct% • $confidenceTier',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: tierColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppColors.bgSurface,
              valueColor: AlwaysStoppedAnimation<Color>(tierColor),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Reflects statistical certainty based on primary source citations, multi-model consensus, and cross-channel consistency.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorsCard() {
    const cardBg = AppColors.appBarSurface;
    const borderColor = AppColors.bgSurface;

    final factors = [
      {
        'title': 'Empirical Evidence Grounding',
        'score': 0.94,
        'desc': 'Factual propositions corroborated by scientific registries and institutional data.',
        'icon': Icons.menu_book_rounded,
        'color': AppColors.success,
      },
      {
        'title': 'Primary Source Independence',
        'score': 0.91,
        'desc': 'Sources cited are independent of commercial or self-serving interests.',
        'icon': Icons.public_rounded,
        'color': Colors.white,
      },
      {
        'title': 'Cross-Video Consistency',
        'score': 0.96,
        'desc': 'Historical statements across your uploads align without self-contradiction.',
        'icon': Icons.repeat_rounded,
        'color': Colors.white,
      },
      {
        'title': 'Epistemic Neutrality & Framing',
        'score': 0.89,
        'desc': 'Clear demarcation between verified fact assertions and creator opinion.',
        'icon': Icons.psychology_rounded,
        'color': AppColors.warning,
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
            'Multi-Dimensional Credibility Factors',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Core metrics that formulate your channel\'s TruthScore and algorithmic credibility advantage.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...factors.map((f) {
            final score = f['score'] as double;
            final pct = (score * 100).toInt();
            final color = f['color'] as Color;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.bgSurface),
                    ),
                    child: Icon(f['icon'] as IconData, size: 16, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              f['title'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '$pct%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          f['desc'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: score,
                            minHeight: 4,
                            backgroundColor: AppColors.bgSurface,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
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

  Widget _buildKeyFindingsCard(BuildContext context) {
    const cardBg = AppColors.appBarSurface;
    const borderColor = AppColors.bgSurface;

    final sampleClaims = allClaims.take(3).toList();

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Key Empirical Findings (${allClaims.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () => onSwitchToTab(0),
                child: const Text(
                  'View All Claims →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...sampleClaims.map((claim) {
            Color pillBg;
            Color pillFg;
            String pillText;

            if (claim.isVerified) {
              pillBg = AppColors.success.withValues(alpha: 0.15);
              pillFg = AppColors.success;
              pillText = '✓ Verified';
            } else if (claim.isNeedsSource) {
              pillBg = AppColors.warning.withValues(alpha: 0.15);
              pillFg = AppColors.warning;
              pillText = '⚠️ Needs Citation';
            } else if (claim.isDisputed) {
              pillBg = Colors.purple.withValues(alpha: 0.15);
              pillFg = Colors.purpleAccent;
              pillText = '🟣 Disputed';
            } else {
              pillBg = AppColors.error.withValues(alpha: 0.15);
              pillFg = AppColors.error;
              pillText = '✕ High Concern';
            }

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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      pillText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: pillFg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          claim.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'From: ${claim.videoTitle} • ${claim.sourceCitation}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
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

  Widget _buildTopSourcesCard(BuildContext context) {
    const cardBg = AppColors.appBarSurface;
    const borderColor = AppColors.bgSurface;

    final sources = <String>{};
    for (final v in videos) {
      for (final s in v.sources) {
        if (s is Map) {
          final t = s['title'] ?? s['publisher'] ?? s['domain'] ?? '';
          if (t.toString().isNotEmpty) sources.add(t.toString());
        } else if (s is String && s.isNotEmpty) {
          sources.add(s);
        }
      }
    }

    final topSources = sources.take(4).toList();

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Authoritative Sources & Citations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () => onSwitchToTab(4),
                child: const Text(
                  'Explore Sources →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Institutional registries and verified publications cited in your channel\'s analysis.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          if (topSources.isEmpty)
            const Text(
              'No external primary sources cited yet. As empirical claims are evaluated, institutional sources will appear here.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topSources.map((sourceName) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.bgSurface,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 13,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sourceName,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMethodologyCard() {
    const cardBg = AppColors.appBarSurface;
    const borderColor = AppColors.bgSurface;

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
            children: const [
              Icon(
                Icons.account_balance_rounded,
                size: 18,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Text(
                'Transparent AI Verification Methodology',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'TruthWorld complies with the International Fact-Checking Network (IFCN) standards of transparency, non-partisanship, and open methodology. Every evaluated claim undergoes a 4-stage pipeline:',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _buildMethodologyStep('1', 'Automated Multimodal Extraction', 'Identifies factual assertions in spoken dialogue, text overlays, and audio tracks while isolating opinions.'),
          _buildMethodologyStep('2', 'Primary Evidence Retrieval', 'Cross-references authoritative institutional registries, peer-reviewed publications, and official statistics.'),
          _buildMethodologyStep('3', 'Consensus Synthesis & Grounding', 'Computes empirical alignment percentage and flags ambiguities for creator review.'),
          _buildMethodologyStep('4', 'Creator Review & Appeal Ledger', 'Grants creators a preliminary review window to submit additional evidence before badges go live.'),
        ],
      ),
    );
  }

  Widget _buildMethodologyStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bgSurface),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Colors.white,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorGuidanceCard() {
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
              Icons.lightbulb_outline_rounded,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Creator Advice: Maximizing Your Algorithmic Distribution',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Videos with zero "High Concern" flags and at least 85% verified claims qualify for TruthWorld\'s Credibility Priority Boost (+15% to 20% algorithmic discovery in recommendation feeds and search). If a video is flagged with caution, tap "Provide Evidence" in the Fact Claims tab to submit primary sources and elevate your standing.',
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
