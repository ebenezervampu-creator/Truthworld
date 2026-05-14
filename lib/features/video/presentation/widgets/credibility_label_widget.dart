import 'package:truthworld/theme/app_theme.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';

class CredibilityLabelWidget extends StatelessWidget {
  final Video video;

  const CredibilityLabelWidget({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppColors.bgPage.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  children: [
                    if (video.harmCapApplied) _buildHarmCapAlert(),
                    _buildTrustIndexSection(),
                    const SizedBox(height: 16),
                    _buildPath1Metrics(),
                    _buildHardeningSection(),
                    const Divider(color: Colors.white12, height: 40),
                    _buildDimensionsGrid(),
                    const Divider(color: Colors.white12, height: 40),
                    if (video.honestyBreakdown != null) _buildHonestySection(),
                    if (video.contextualFlags.isNotEmpty) _buildContextualFlagsSection(),
                    _buildStatsSection(),
                    if (video.deductions.isNotEmpty) _buildDeductionsSection(),
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
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
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
                  Text(
                    'Credibility Nutrition Label',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Category: ${video.videoCategory?.toUpperCase() ?? video.category.toUpperCase()}',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: Colors.white54,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white70),
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
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SAFETY VETO APPLIED',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  video.harmCapReason ?? 'Dangerous misinformation detected. Score capped to protect viewers.',
                  style: GoogleFonts.roboto(color: Colors.white, fontSize: 13),
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

    final hasHardening = metadata.truthFloorApplied || 
                        metadata.domainOverride?.triggered == true || 
                        metadata.consensusGateTriggered;

    if (!hasHardening) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Text(
                'TRUST SAFEGUARDS APPLIED',
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
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
          if (metadata.domainOverride?.triggered == true)
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

  Widget _buildHardeningItem(IconData icon, String title, String description, {String? penalty}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    if (penalty != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          penalty,
                          style: GoogleFonts.roboto(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  description,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: Colors.white54,
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
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Composite Credibility Index',
                style: GoogleFonts.roboto(color: Colors.white54, fontSize: 12),
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
                backgroundColor: Colors.white10,
                color: color,
                strokeCap: StrokeCap.round,
              ),
            ),
            Text(
              score.toInt().toString(),
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EPISTEMIC DIMENSIONS (v8.5)',
            style: GoogleFonts.roboto(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white38,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _buildPath1Row('TRUTH', report.truthScore, Colors.greenAccent),
          _buildPath1Row('HONESTY', report.honestyScore, Colors.blueAccent),
          _buildPath1Row('RATIONALITY', report.rationalityScore, Colors.purpleAccent),
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
              style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
          ),
          Expanded(
            child: LinearPercentIndicator(
              lineHeight: 6,
              percent: s / 100,
              backgroundColor: Colors.white10,
              progressColor: color,
              barRadius: const Radius.circular(3),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            score?.toStringAsFixed(1) ?? 'N/A',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
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
        Text(
          '9-DIMENSIONAL TRUST ANALYSIS',
          style: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white38,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        _buildDimensionRow('FACTUAL ACCURACY', factors.accuracy, Icons.check_circle_outline),
        _buildDimensionRow('SOURCE EVIDENCE', factors.evidence, Icons.menu_book_outlined),
        _buildDimensionRow('EXPERT CONSENSUS', factors.consensus, Icons.people_outline),
        _buildDimensionRow('LOGICAL CONSISTENCY', factors.consistency, Icons.account_tree_outlined),
        _buildDimensionRow('FRAMING INTEGRITY', factors.integrity, Icons.balance_outlined),
        _buildDimensionRow('CREATOR EXPERTISE', factors.expertise, Icons.workspace_premium_outlined),
        _buildDimensionRow('INFO FRESHNESS', factors.freshness, Icons.update_outlined),
        _buildDimensionRow('PUBLIC SAFETY', factors.safety, Icons.security_outlined),
        _buildDimensionRow('EPISTEMIC HONESTY', factors.honesty, Icons.visibility_outlined, isSpecial: true),
      ],
    );
  }

  Widget _buildDimensionRow(String label, double score, IconData icon, {bool isSpecial = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: isSpecial ? Colors.blueAccent : Colors.white54),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  fontWeight: isSpecial ? FontWeight.bold : FontWeight.normal,
                  color: isSpecial ? Colors.blueAccent : Colors.white70,
                ),
              ),
              const Spacer(),
              Text(
                score.toInt().toString(),
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearPercentIndicator(
            lineHeight: 4,
            percent: score / 100,
            backgroundColor: Colors.white10,
            progressColor: isSpecial ? Colors.blueAccent : _getScoreColor(score).withValues(alpha: 0.8),
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
          style: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent.withValues(alpha: 0.7),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              _buildHonestyMetric('Opinions Framed as Opinions', hb.opinionLabeledOpinion, Icons.comment_bank_outlined),
              _buildHonestyMetric('Beliefs Framed as Beliefs', hb.beliefLabeledBelief, Icons.auto_awesome_outlined),
              _buildHonestyMetric('Beliefs Presented as Fact', hb.beliefPresentedAsFact, Icons.warning_amber_rounded, isNegative: true),
              _buildHonestyMetric('Opinions Presented as Fact', hb.opinionPresentedAsFact, Icons.report_problem_outlined, isNegative: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'How it works: We reward creators who use "I believe" or "In my opinion" for non-empirical claims, and penalize those who present subjective views as authoritative facts.',
          style: GoogleFonts.roboto(fontSize: 11, color: Colors.white38, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildHonestyMetric(String label, int count, IconData icon, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: isNegative ? Colors.orangeAccent : Colors.greenAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.roboto(fontSize: 12, color: Colors.white70),
            ),
          ),
          Text(
            count.toString(),
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: isNegative && count > 0 ? Colors.orangeAccent : Colors.white,
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
        const Divider(color: Colors.white12, height: 40),
        Text(
          'CONTEXTUAL FLAGS (DEBATED TOPICS)',
          style: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.purpleAccent.withValues(alpha: 0.7),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ...video.contextualFlags.map((flag) => _buildFlagItem(flag)),
      ],
    );
  }

  Widget _buildFlagItem(ContextualFlag flag) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: Colors.purpleAccent),
              const SizedBox(width: 8),
              Text(
                flag.topic,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...flag.perspectives.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    p.label,
                    style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.explanation,
                    style: GoogleFonts.roboto(fontSize: 11, color: Colors.white70),
                  ),
                ),
              ],
            ),
          )),
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
        const Divider(color: Colors.white12, height: 40),
        Text(
          'VERIFICATION DIAGNOSTICS',
          style: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white38,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatBox('Claims', stats.totalClaims.toString()),
            _buildStatBox('Correct', stats.correct.toString(), color: Colors.greenAccent),
            _buildStatBox('Incorrect', stats.incorrect.toString(), color: Colors.redAccent),
            _buildStatBox('Unverified', stats.unverifiable.toString(), color: Colors.orangeAccent),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBox(String label, String value, {Color color = Colors.white}) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: GoogleFonts.roboto(fontSize: 10, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildDeductionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white12, height: 40),
        Text(
          'TRANSPARENCY LEDGER (DEDUCTIONS)',
          style: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.orangeAccent.withValues(alpha: 0.7),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ...video.deductions.map((d) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '-${d.points}',
                style: GoogleFonts.outfit(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.factor.toUpperCase(),
                      style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38),
                    ),
                    Text(
                      d.reason,
                      style: GoogleFonts.roboto(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: Colors.white38),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This automated report is based on cross-referencing transcripts against institutional databases. TruthWorld maintains doctrinal neutrality in all faith-based scoring.',
                  style: GoogleFonts.roboto(fontSize: 10, color: Colors.white38),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.greenAccent;
    if (score >= 75) return const Color(0xFFA3E635);
    if (score >= 60) return Colors.yellowAccent;
    if (score >= 45) return Colors.orangeAccent;
    if (score >= 30) return Colors.redAccent;
    return const Color(0xFF991B1B);
  }
}






