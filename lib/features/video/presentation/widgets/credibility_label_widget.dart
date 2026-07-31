import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class CredibilityLabelWidget extends StatelessWidget {
  const CredibilityLabelWidget({required this.video, super.key});
  final Video video;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppColors.bgPage.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  children: [
                    if (video.harmCapApplied) _buildHarmCapAlert(),
                    const SizedBox.shrink(),
                    const SizedBox(height: 16),
                    _buildPath1Metrics(),
                    _buildHardeningSection(),
                    const Divider(color: AppColors.bgDivider, height: 40),
                    const SizedBox.shrink(),
                    const Divider(color: AppColors.bgDivider, height: 40),
                    if (video.honestyBreakdown != null) _buildHonestySection(),
                    if (video.contextualFlags.isNotEmpty)
                      _buildContextualFlagsSection(),
                    _buildStatsSection(),
                    if (video.deductions.isNotEmpty) const SizedBox.shrink(),
                    const SizedBox(height: 40),
                    _buildFooter(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textDisabled,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Credibility Nutrition Label',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Category: ${video.videoCategory?.toUpperCase() ?? video.category.toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHarmCapAlert() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SAFETY VETO APPLIED',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  video.harmCapReason ??
                      'Dangerous misinformation detected. Score capped to protect viewers.',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().shake(duration: 500.ms);
  }

  Widget _buildHardeningSection() {
    final metadata = video.hardeningMetadata;
    if (metadata == null) return const SizedBox.shrink();

    final hasHardening =
        metadata.truthFloorApplied ||
        (metadata.domainOverride?.triggered ?? false) ||
        metadata.consensusGateTriggered;

    if (!hasHardening) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.security, color: AppColors.warning, size: 18),
              SizedBox(width: 8),
              Text(
                'TRUST SAFEGUARDS APPLIED',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (metadata.truthFloorApplied)
            _buildHardeningItem(
              Icons.fact_check,
              'Factual Accuracy Floor',
              metadata.truthFloorReason ?? 'Factual errors detected.',
            ),
          if (metadata.domainOverride?.triggered ?? false)
            _buildHardeningItem(
              Icons.category,
              'Domain Risk Adjustment',
              'Detected as ${metadata.domainOverride!.to}. Applied stricter safety profile.',
              penalty: '-${(metadata.domainOverride!.penalty * 100).toInt()}%',
            ),
          if (metadata.consensusGateTriggered)
            _buildHardeningItem(
              Icons.gavel,
              'Consensus Threshold Gate',
              'Claim lacks minimum consensus threshold for multi-perspective display.',
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildHardeningItem(
    IconData icon,
    String title,
    String description, {
    String? penalty,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (penalty != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          penalty,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  description,
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
    );
  }

  Widget _buildTrustIndexSection() {
    final score = video.trustScore;
    final color = _getScoreColor(score);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.trustLabel ?? 'Processing',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Composite Credibility Index',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 6,
                backgroundColor: AppColors.bgDivider,
                color: color,
                strokeCap: StrokeCap.round,
              ),
            ),
            Text(
              score.toInt().toString(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1);
  }

  Widget _buildPath1Metrics() {
    final report = video.uiReport;
    if (report == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EPISTEMIC DIMENSIONS (v8.5)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _buildPath1Row('TRUTH', report.truthScore, AppColors.success),
          _buildPath1Row('HONESTY', report.honestyScore, AppColors.info),
          _buildPath1Row(
            'RATIONALITY',
            report.rationalityScore,
            AppColors.brandHover,
          ),
        ],
      ),
    );
  }

  Widget _buildPath1Row(String label, double? score, Color color) {
    final s = (score ?? 0) * 10; // 0-10 to 0-100
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: LinearPercentIndicator(
              lineHeight: 6,
              percent: s / 100,
              backgroundColor: AppColors.bgDivider,
              progressColor: color,
              barRadius: const Radius.circular(3),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            score?.toStringAsFixed(1) ?? 'N/A',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionsGrid() {
    final factors = video.scoringFactors;
    if (factors == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '9-DIMENSIONAL TRUST ANALYSIS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        _buildDimensionRow(
          'FACTUAL ACCURACY',
          factors.accuracy,
          Icons.check_circle_outline,
        ),
        _buildDimensionRow(
          'SOURCE EVIDENCE',
          factors.evidence,
          Icons.menu_book_outlined,
        ),
        _buildDimensionRow(
          'EXPERT CONSENSUS',
          factors.consensus,
          Icons.people_outline,
        ),
        _buildDimensionRow(
          'LOGICAL CONSISTENCY',
          factors.consistency,
          Icons.account_tree_outlined,
        ),
        _buildDimensionRow(
          'FRAMING INTEGRITY',
          factors.integrity,
          Icons.balance_outlined,
        ),
        _buildDimensionRow(
          'CREATOR EXPERTISE',
          factors.expertise,
          Icons.workspace_premium_outlined,
        ),
        _buildDimensionRow(
          'INFO FRESHNESS',
          factors.freshness,
          Icons.update_outlined,
        ),
        _buildDimensionRow(
          'PUBLIC SAFETY',
          factors.safety,
          Icons.security_outlined,
        ),
        _buildDimensionRow(
          'EPISTEMIC HONESTY',
          factors.honesty,
          Icons.visibility_outlined,
          isSpecial: true,
        ),
      ],
    );
  }

  Widget _buildDimensionRow(
    String label,
    double score,
    IconData icon, {
    bool isSpecial = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSpecial ? AppColors.info : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSpecial ? FontWeight.bold : FontWeight.normal,
                  color: isSpecial ? AppColors.info : AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                score.toInt().toString(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearPercentIndicator(
            lineHeight: 4,
            percent: score / 100,
            backgroundColor: AppColors.bgDivider,
            progressColor: isSpecial
                ? AppColors.info
                : _getScoreColor(score).withValues(alpha: 0.8),
            barRadius: const Radius.circular(2),
            padding: EdgeInsets.zero,
            animation: true,
            animationDuration: 1000,
          ),
        ],
      ),
    );
  }

  Widget _buildHonestySection() {
    final hb = video.honestyBreakdown!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EPISTEMIC HONESTY BREAKDOWN',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.info.withValues(alpha: 0.7),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              _buildHonestyMetric(
                'Opinions Framed as Opinions',
                hb.opinionLabeledOpinion,
                Icons.comment_bank_outlined,
              ),
              _buildHonestyMetric(
                'Beliefs Framed as Beliefs',
                hb.beliefLabeledBelief,
                Icons.auto_awesome_outlined,
              ),
              _buildHonestyMetric(
                'Beliefs Presented as Fact',
                hb.beliefPresentedAsFact,
                Icons.warning_amber_rounded,
                isNegative: true,
              ),
              _buildHonestyMetric(
                'Opinions Presented as Fact',
                hb.opinionPresentedAsFact,
                Icons.report_problem_outlined,
                isNegative: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'How it works: We reward creators who use "I believe" or "In my opinion" for non-empirical claims, and penalize those who present subjective views as authoritative facts.',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildHonestyMetric(
    String label,
    int count,
    IconData icon, {
    bool isNegative = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: isNegative ? AppColors.warning : AppColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isNegative && count > 0
                  ? AppColors.warning
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextualFlagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppColors.bgDivider, height: 40),
        Text(
          'CONTEXTUAL FLAGS (DEBATED TOPICS)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.brandHover.withValues(alpha: 0.7),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ...video.contextualFlags.map(_buildFlagItem),
      ],
    );
  }

  Widget _buildFlagItem(ContextualFlag flag) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandHover.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandHover.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                flag.topic,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...flag.perspectives.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgDivider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      p.label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.explanation,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
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

  Widget _buildStatsSection() {
    final stats = video.factCheckStats;
    if (stats == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppColors.bgDivider, height: 40),
        const Text(
          'VERIFICATION DIAGNOSTICS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatBox('Claims', stats.totalClaims.toString()),
            _buildStatBox(
              'Correct',
              stats.correct.toString(),
              color: AppColors.success,
            ),
            _buildStatBox(
              'Incorrect',
              stats.incorrect.toString(),
              color: AppColors.error,
            ),
            _buildStatBox(
              'Unverified',
              stats.unverifiable.toString(),
              color: AppColors.warning,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBox(
    String label,
    String value, {
    Color color = AppColors.textPrimary,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _buildDeductionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppColors.bgDivider, height: 40),
        Text(
          'TRANSPARENCY LEDGER (DEDUCTIONS)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.warning.withValues(alpha: 0.7),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ...video.deductions.map(
          (d) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '-${d.points}',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.factor.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      Text(
                        d.reason,
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
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: AppColors.textTertiary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This automated report is based on cross-referencing transcripts against institutional databases. TruthWorld maintains doctrinal neutrality in all faith-based scoring.',
                  style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return AppColors.success;
    if (score >= 75) return const Color(0xFFA3E635);
    if (score >= 60) return AppColors.brandHover;
    if (score >= 45) return AppColors.warning;
    if (score >= 30) return AppColors.error;
    return const Color(0xFF991B1B);
  }
}
