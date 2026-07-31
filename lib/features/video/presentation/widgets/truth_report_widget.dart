import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:truthworld/features/video/data/models/credibility_report.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/widgets/credibility_label_widget.dart';
import 'package:truthworld/theme/app_theme.dart';

class TruthReportWidget extends StatelessWidget {
  const TruthReportWidget({required this.video, super.key});
  final Video video;

  @override
  Widget build(BuildContext context) {
    final report = video.uiReport;

    // If report doesn't exist, fallback to a loading or "Not Evaluated" state
    if (report == null) {
      return _buildEmptyState(context);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppColors.bgPage.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(alpha: 0.5),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
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
                    vertical: 16,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildTopScoreSection(context, report),
                    const SizedBox(height: 16),
                    _buildConfidenceSection(context, report),
                    const SizedBox(height: 24),
                    if (report.riskNote.isNotEmpty &&
                        !report.riskNote.contains('No harmful'))
                      _buildRiskBanner(report.riskNote),
                    const SizedBox(height: 24),
                    _buildNarrativeSection(report),
                    _buildWhyThisMattersSection(context, report),
                    const SizedBox(height: 16),
                    _buildRecommendationSection(context, report),
                    const SizedBox(height: 32),
                    _buildDriversSection(report),
                    const SizedBox(height: 32),
                    if (report.counterSignals.isNotEmpty) ...[
                      _buildCounterSignalsSection(report),
                      const SizedBox(height: 32),
                    ],
                    _buildSourcesSection(report),
                    const SizedBox(height: 32),
                    _buildConclusionSection(report),
                    const SizedBox(height: 32),
                    _buildAppealSection(report),
                    const SizedBox(height: 48),
                    _buildDisclaimerSection(report),
                    const SizedBox(height: 64),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
                Icons.analytics_outlined,
                color: AppColors.textTertiary,
                size: 48,
              )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(
                duration: 2.seconds,
                color: AppColors.brand.withValues(alpha: 0.3),
              ),
          const SizedBox(height: 16),
          const Text(
            'Analysis Pending',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'TruthWorld is currently evaluating this content.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
          const SizedBox(height: 16),
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRUTH REPORT',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                      letterSpacing: 2,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user,
                        size: 10,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'VERIFIED ANALYSIS',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => CredibilityLabelWidget(video: video),
                  );
                },
                icon: const Icon(
                  Icons.analytics_outlined,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
                label: const Text(
                  'ADVANCED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopScoreSection(BuildContext context, UIReport report) {
    final compositeRating = report.rating;
    final isDeveloping = report.analysisState == 'DEVELOPING';
    final themeColor = _getScoreColor(compositeRating ?? 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.textPrimary.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildConfidenceBadge(report.confidence, themeColor),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricRing(
                label: 'TRUTH',
                score: report.truthScore,
                color: AppColors.success,
                icon: Icons.fact_check_outlined,
              ),
              _buildMetricRing(
                label: 'HONESTY',
                score: report.honestyScore,
                color: AppColors.info,
                icon: Icons.face_outlined,
              ),
              _buildMetricRing(
                label: 'RATIONALITY',
                score: report.rationalityScore,
                color: AppColors.brandHover,
                icon: Icons.psychology_outlined,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Column(
            children: [
              if (isDeveloping)
                _buildDevelopingBadge()
              else ...[
                Text(
                  compositeRating?.toStringAsFixed(1) ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -1,
                  ),
                ),
                const Text(
                  'COMPOSITE RATING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 2,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                report.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildMetricRing({
    required String label,
    required double? score,
    required Color color,
    required IconData icon,
  }) {
    final displayScore = score ?? 0.0;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 74,
              height: 74,
              child:
                  CircularProgressIndicator(
                        value: displayScore / 10,
                        strokeWidth: 6,
                        backgroundColor: AppColors.bgDivider,
                        color: color,
                        strokeCap: StrokeCap.round,
                      )
                      .animate(autoPlay: score != null)
                      .custom(
                        duration: 2.seconds,
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) =>
                            CircularProgressIndicator(
                              value: value * (displayScore / 10),
                              strokeWidth: 6,
                              backgroundColor: AppColors.bgDivider,
                              color: color,
                              strokeCap: StrokeCap.round,
                            ),
                      ),
            ),
            Icon(icon, color: color.withValues(alpha: 0.5), size: 24),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          score?.toStringAsFixed(1) ?? 'N/A',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDevelopingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.auto_awesome,
            color: AppColors.warning,
            size: 20,
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
          const SizedBox(height: 4),
          const Text(
            'DEVELOPING STORY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.warning,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge(String level, Color themeColor) {
    final color = _getTierColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 10, color: color),
          const SizedBox(width: 6),
          Text(
            level.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceSection(BuildContext context, UIReport report) {
    final level = report.confidence.toLowerCase();
    var value = 0.3;
    if (level == 'high') value = 0.95;
    if (level == 'medium') value = 0.65;

    final color = _getTierColor(level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ANALYSIS CONFIDENCE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildConfidenceBar(context, value, color, level),
        const SizedBox(height: 8),
        Text(
          _getConfidenceInterpretation(value),
          style: TextStyle(
            fontSize: 11,
            color: color.withValues(alpha: 0.8),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildConfidenceBar(
    BuildContext context,
    double value,
    Color color,
    String level,
  ) {
    final barWidth = MediaQuery.of(context).size.width * 0.8;

    return Stack(
      children: [
        Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.bgDivider,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        if (level == 'low')
          CustomPaint(
            size: Size(barWidth * value, 6),
            painter: DashedBarPainter(color: color),
          )
        else
          AnimatedContainer(
                duration: 1.seconds,
                curve: Curves.easeOutCubic,
                height: 6,
                width: barWidth * value,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.5), color],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
              )
              .animate(autoPlay: level == 'high')
              .shimmer(delay: 1.seconds, duration: 2.seconds),
      ],
    );
  }

  String _getConfidenceInterpretation(double c) {
    if (c >= 0.85) {
      return 'High confidence — results are strongly supported by institutional data.';
    }
    if (c >= 0.6) {
      return 'Moderate confidence — some uncertainty remains in claim verification.';
    }
    return 'Low confidence — limited data available; treat results cautiously.';
  }

  Widget _buildWhyThisMattersSection(BuildContext context, UIReport report) {
    final category =
        video.videoCategory?.toLowerCase() ?? video.category.toLowerCase();
    var matterLine =
        'This affects how much you can rely on this video for real-world decisions.';

    if (category.contains('health')) {
      matterLine =
          'Critical: This information could impact personal medical decisions or health outcomes.';
    } else if (category.contains('news') || category.contains('politics')) {
      matterLine =
          'Insight: These claims may influence public understanding or democratic participation.';
    } else if (category.contains('finance')) {
      matterLine =
          'Caution: Financial claims detected. This may impact investment or economic security.';
    } else if (category.contains('religion')) {
      matterLine =
          'Note: This content pertains to cultural or faith-based beliefs; interpret through context.';
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline,
            color: AppColors.info,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Why this matters: $matterLine',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildRecommendationSection(BuildContext context, UIReport report) {
    final category =
        video.videoCategory?.toLowerCase() ?? video.category.toLowerCase();
    var recommendation = 'Use additional sources to confirm key claims.';
    var icon = Icons.info_outline;
    var color = AppColors.textTertiary;

    if (category.contains('health')) {
      recommendation =
          'Do not rely on this video for medical decisions without consulting a professional.';
      icon = Icons.medical_services_outlined;
      color = AppColors.warning;
    } else if (category.contains('news') || category.contains('politics')) {
      recommendation =
          'Cross-reference these claims with primary news sources for full context.';
      icon = Icons.newspaper_outlined;
      color = AppColors.info;
    } else if (category.contains('finance')) {
      recommendation =
          'Consult a licensed financial advisor before taking action on these claims.';
      icon = Icons.account_balance_outlined;
      color = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                'RECOMMENDATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            recommendation,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1);
  }

  Widget _buildRiskBanner(String note) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ).animate().shake(duration: 500.ms);
  }

  Widget _buildNarrativeSection(UIReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SUMMARY ANALYSIS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.textPrimary.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
            ),
          ),
          child: Text(
            report.narrative,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary.withValues(alpha: 0.9),
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDriversSection(UIReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KEY TRUST DRIVERS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ...report.positiveDrivers.asMap().entries.map(
          (entry) =>
              _buildDriverCard(entry.value, isPositive: true, index: entry.key),
        ),
        ...report.negativeDrivers.asMap().entries.map(
          (entry) => _buildDriverCard(
            entry.value,
            isPositive: false,
            index: entry.key + report.positiveDrivers.length,
          ),
        ),
      ],
    );
  }

  Widget _buildDriverCard(
    UIDriver driver, {
    required bool isPositive,
    required int index,
  }) {
    final color = isPositive
        ? AppColors.success
        : (driver.impact == 'high' ? AppColors.error : AppColors.warning);

    final icon = isPositive ? Icons.check_circle_outline : Icons.error_outline;

    return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  driver.text,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (driver.impact == 'high')
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'HIGH',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (400 + (index * 100)).ms)
        .slideX(begin: 0.1, curve: Curves.easeOutCubic);
  }

  Widget _buildSourcesSection(UIReport report) {
    if (report.sources.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VERIFIED SOURCES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: report.sources.length,
            physics: const BouncingScrollPhysics(),
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final source = report.sources[index];
              return _buildSourceCard(source, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSourceCard(UISource source, int index) {
    final tierColor = _getTierColor(source.trustLevel);

    return Container(
          width: 180,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      source.trustLevel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: tierColor,
                      ),
                    ),
                  ),
                  Text(
                    source.type,
                    style: const TextStyle(
                      fontSize: 8,
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                source.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                source.domain ?? 'verified-link',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (600 + (index * 100)).ms)
        .scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildConclusionSection(UIReport report) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.gradientCrimsonSubtle,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: AppColors.brand,
            size: 32,
          ),
          const SizedBox(height: 16),
          const Text(
            'CONCLUSION',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.brand,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            report.conclusion,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterSignalsSection(UIReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DISPUTED CLAIMS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.warning,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ...report.counterSignals.map(
          (signal) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.warning,
                  size: 16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    signal,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppealSection(UIReport report) {
    if (!report.reviewRequestEnabled) return const SizedBox.shrink();

    return Center(
      child: TextButton(
        onPressed: () {
          // Future: Implement review request logic
        },
        child: const Text(
          'Think this is incorrect? Request a review',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimerSection(UIReport report) {
    final showAlways =
        report.rating != null && report.rating! < 0.5; // Always for low scores
    final isSensitive =
        (video.videoCategory?.toLowerCase().contains('health') ?? false) ||
        (video.videoCategory?.toLowerCase().contains('finance') ?? false);

    if (!showAlways &&
        !isSensitive &&
        report.confidence.toLowerCase() == 'high') {
      return const SizedBox.shrink();
    }

    return const Opacity(
      opacity: 0.5,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'DISCLAIMER: This analysis is AI-generated based on available public data. It is intended as a guidance tool and should not be considered a definitive judgment or professional advice.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textTertiary,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(double rating) {
    if (rating >= 8.5) return AppColors.success;
    if (rating >= 7.0) return const Color(0xFFA3E635);
    if (rating >= 5.5) return AppColors.warning;
    if (rating >= 4.0) return AppColors.warning;
    return AppColors.error;
  }

  Color _getTierColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return AppColors.success;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }
}

class DashedBarPainter extends CustomPainter {
  DashedBarPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashWidth = 8.0;
    const dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(
          startX + dashWidth > size.width ? size.width : startX + dashWidth,
          size.height / 2,
        ),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
