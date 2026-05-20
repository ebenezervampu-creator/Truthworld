import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';

class FactCheckReportSheet extends StatelessWidget {
  final Video video;

  const FactCheckReportSheet({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    final uiReport = video.uiReport;
    if (uiReport == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppColors.bgPage.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildSummaryCard(uiReport),
                    const SizedBox(height: 32),
                    Text(
                      'CLAIM BREAKDOWN',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textTertiary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...uiReport.keyClaims.map(
                      (claim) => _buildClaimCard(context, claim),
                    ),
                    const SizedBox(height: 32),
                    _buildFooter(),
                    const SizedBox(height: 48),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'FULL DISCLOSURE',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(UIReport uiReport) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (uiReport.summary.analysisState == 'ANALYSIS_INCOMPLETE')
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.amber, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Analysis Incomplete: Some claims timed out during verification. Results may evolve.',
                      style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: Colors.amber,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              _buildRatingBadge(uiReport.summary.rating ?? 0),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uiReport.label,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'TRUST VERDICT',
                    style: GoogleFonts.roboto(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('TOTAL CLAIMS', (uiReport.summary.evidenceCoverage?.total ?? 0).toString()),
              _buildStatItem('VERIFIED', (uiReport.summary.evidenceCoverage?.checked ?? 0).toString()),
              _buildStatItem('COVERAGE', '${((uiReport.summary.factCheckStats?.verificationCoverageRatio ?? 0) * 100).toInt()}%'),
            ],
          ),
          const Divider(color: Colors.white10, height: 48),
          Text(
            uiReport.narrative,
            style: GoogleFonts.roboto(
              fontSize: 15,
              color: AppColors.textPrimary.withValues(alpha: 0.9),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBadge(double rating) {
    final color = _getScoreColor(rating);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Text(
        rating.toStringAsFixed(1),
        style: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.roboto(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textTertiary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildMethodBadge(String method) {
    String label = method.toUpperCase().replaceAll('_', ' ');
    Color color = AppColors.textTertiary;
    IconData icon = Icons.info_outline;

    if (method == 'deterministic') {
      label = 'DETERMINISTIC';
      color = const Color(0xFF10B981); // Emerald
      icon = Icons.bolt;
    } else if (method == 'grounded') {
      label = 'INSTITUTIONAL GROUNDED';
      color = const Color(0xFF3B82F6); // Blue
      icon = Icons.public;
    } else if (method == 'cache_hit') {
      label = 'CACHED';
      color = const Color(0xFF8B5CF6); // Violet
      icon = Icons.history;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimCard(BuildContext context, ClaimResult claim) {
    final verdict = claim.verdict.toLowerCase();

    // UI Treatment Logic
    Color cardColor;
    IconData icon;
    String label;
    bool showSources = false;
    bool showFramingWarning = false;
    bool isTimeout = verdict == 'verification_timeout';

    if (verdict == 'verified_true' ||
        verdict == 'mostly_true' ||
        verdict == 'correct') {
      cardColor = AppColors.success;
      icon = Icons.check_circle_rounded;
      label = claim.displayLabel?.toUpperCase() ?? 'VERIFIED TRUE';
      showSources = true;
    } else if (verdict == 'false_claim' ||
        verdict == 'incorrect' ||
        verdict == 'misleading') {
      cardColor = AppColors.error;
      icon = Icons.cancel_rounded;
      label = claim.displayLabel?.toUpperCase() ?? 'CONTRADICTED';
      showSources = true;
    } else if (verdict == 'religious_belief' || claim.bucket == 'BELIEF') {
      cardColor = const Color(0xFF818CF8); // Purple/Indigo
      icon = Icons.auto_awesome;
      label = claim.displayLabel?.toUpperCase() ?? 'RELIGIOUS BELIEF';
    } else if (verdict == 'unproven' || verdict == 'unsupported' || verdict == 'inconclusive' || verdict == 'limited_support') {
      cardColor = AppColors.warning;
      icon = Icons.help_outline_rounded;
      label = claim.displayLabel?.toUpperCase() ?? 'INCONCLUSIVE';
      showSources = true;
    } else if (isTimeout) {
      cardColor = AppColors.textTertiary;
      icon = Icons.timer_outlined;
      label = claim.displayLabel?.toUpperCase() ?? 'INCOMPLETE (TIMEOUT)';
    } else {
      cardColor = AppColors.textTertiary;
      icon = Icons.info_outline_rounded;
      label = claim.displayLabel?.toUpperCase() ?? claim.verdict.toUpperCase();
    }

    // Check for framing violations (Special Red treatment)
    if (claim.reasoning?.contains('Framing Violation') == true) {
      showFramingWarning = true;
      cardColor = AppColors.error;
      icon = Icons.flag_rounded;
      label = 'FRAMING VIOLATION';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: cardColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            label,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: cardColor,
                              letterSpacing: 1,
                            ),
                          ),
                          if (claim.verificationMethod != null) ...[
                            const SizedBox(width: 8),
                            _buildMethodBadge(claim.verificationMethod!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        claim.text,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Framing Violation Banner
          if (showFramingWarning)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.error.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Opinion presented as proven fact. Correction suggested.',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Reasoning/Analysis
          if (claim.reasoning != null && claim.reasoning!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                claim.reasoning!,
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          // Sources
          if (showSources && claim.sources.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INSTITUTIONAL SOURCES',
                    style: GoogleFonts.roboto(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...claim.sources.map(
                    (url) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link,
                            size: 12,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                color: Colors.blueAccent,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Retry Button for Timeout
          if (isTimeout)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final vc = Get.find<VideoController>(tag: video.id);
                    vc.reVerifyVideo();
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('RETRY VERIFICATION'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cardColor.withValues(alpha: 0.1),
                    foregroundColor: cardColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: cardColor.withValues(alpha: 0.3)),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),

          // Faith Shield Note
          if (verdict == 'religious_belief' || claim.bucket == 'BELIEF')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF818CF8),
                    size: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Faith-based content is respected as subjective truth and does not impact the Truth Index.',
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        color: const Color(0xFF818CF8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(color: Colors.white10),
        const SizedBox(height: 24),
        Text(
          'Truthworld employs the Path 1 Epistemic Framework to distinguish between empirical reality and personal belief. Analysis is performed using institutional-grade data grounding.',
          textAlign: TextAlign.center,
          style: GoogleFonts.roboto(
            fontSize: 11,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 9.0) return AppColors.success;
    if (score >= 7.0) return const Color(0xFFA3E635);
    if (score >= 5.0) return Colors.yellowAccent;
    if (score >= 3.0) return Colors.orangeAccent;
    return AppColors.error;
  }
}
