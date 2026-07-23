import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class FactCheckReportWidget extends StatelessWidget {

  const FactCheckReportWidget({
    required this.data, required this.video, super.key,
  });
  final Map<String, dynamic> data;
  final Video video;

  @override
  Widget build(BuildContext context) {
    // 🧠 Extract multi-dimensional data
    final trustScore = ((data['trustScore'] ?? data['compositeRating'] ?? data['videoRating'] ?? 0.0) as num).toDouble();
    final truthScore = ((data['truthScore'] ?? trustScore) as num).toDouble();
    final honestyScore = ((data['honestyScore'] ?? 0.0) as num).toDouble();
    final rationalityScore = ((data['rationalityScore'] ?? 0.0) as num).toDouble();
    
    final stats = data['factCheckStats'] as Map? ?? {};
    final claims = data['claims'] as List? ?? [];
    final diagnostics = data['diagnostics'] as List? ?? [];
    final deductions = data['deductions'] as List? ?? [];
    final factors = data['factors'] as Map? ?? {};
    
    // 🏛 Extract UI Report fields if available
    final uiReport = data['uiReport'] as Map? ?? {};
    final narrative = uiReport['narrative'] as String? ?? data['viewerNote'] as String? ?? '';
    final sources = uiReport['sources'] as List? ?? data['richSources'] as List? ?? [];
    final conclusion = uiReport['conclusion'] as String? ?? '';
    final confidence = ((data['confidence'] ?? 0.5) as num).toDouble();
    
    final themeColor = _getScoreColor(trustScore);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppColors.bgPage.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppColors.bgDivider),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(alpha: 0.5),
            blurRadius: 40,
            spreadRadius: 10,
          )
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildMainRatingSection(trustScore, themeColor),
                    const SizedBox(height: 24),
                    
                    _buildMetricsRow(
                      truth: truthScore,
                      honesty: honestyScore,
                      rationality: rationalityScore,
                    ),
                    const SizedBox(height: 24),
                    _buildConfidenceBar(confidence),
                    const SizedBox(height: 32),
                    
                    _buildStatsRow(stats),
                    const SizedBox(height: 32),

                    if (narrative.isNotEmpty) ...[
                      _buildNarrativeSection(narrative),
                      const SizedBox(height: 32),
                    ],

                    if (factors.isNotEmpty) ...[
                      _buildFactorsSection(factors),
                      const SizedBox(height: 32),
                    ],

                    if (deductions.isNotEmpty) ...[
                      _buildDeductionsSection(deductions),
                      const SizedBox(height: 32),
                    ],
                    
                    _buildClaimsSection(claims),
                    const SizedBox(height: 32),

                    if (sources.isNotEmpty) ...[
                      _buildSourcesSection(sources),
                      const SizedBox(height: 32),
                    ],

                    if (conclusion.isNotEmpty) ...[
                      _buildConclusionSection(conclusion),
                      const SizedBox(height: 32),
                    ],

                    _buildDiagnosticsSection(diagnostics),
                    const SizedBox(height: 48),
                    
                    _buildFooter(),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.bgDivider)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI FULL DISCLOSURE',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                      letterSpacing: 2,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.verified_user, size: 10, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'CRYPTO-VERIFIED ANALYSIS',
                        style: AppTextStyles.labelSmall.copyWith(
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
              IconButton(
                onPressed: Get.back,
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainRatingSection(double rating, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.bgDivider),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: rating / 100,
                  strokeWidth: 12,
                  backgroundColor: AppColors.bgDivider,
                  color: color,
                  strokeCap: StrokeCap.round,
                ).animate().custom(
                  duration: 1500.ms,
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) => CircularProgressIndicator(
                    value: value * (rating / 100),
                    strokeWidth: 12,
                    backgroundColor: AppColors.bgDivider,
                    color: color,
                    strokeCap: StrokeCap.round,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${rating.toInt()}',
                    style: AppTextStyles.pageTitle.copyWith(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1,
                    ),
                  ),
                  Text(
                    '%',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _getRatingLabel(rating),
            style: AppTextStyles.titleLarge.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
          const SizedBox(height: 8),
          Text(
            'VIDEO INTEGRITY RATING',
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildMetricsRow({required double truth, required double honesty, required double rationality}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildMetricRing(label: 'TRUTH', score: truth, color: AppColors.success, icon: Icons.fact_check_outlined),
        _buildMetricRing(label: 'HONESTY', score: honesty, color: AppColors.info, icon: Icons.face_outlined),
        _buildMetricRing(label: 'LOGIC', score: rationality, color: AppColors.brandHover, icon: Icons.psychology_outlined),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildMetricRing({required String label, required double score, required Color color, required IconData icon}) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 4,
                backgroundColor: AppColors.bgDivider,
                color: color,
                strokeCap: StrokeCap.round,
              ),
            ),
            Icon(icon, color: color.withValues(alpha: 0.5), size: 20),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${score.toInt()}%',
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildConfidenceBar(double confidence) {
    // confidence is 0.0 to 1.0
    final value = confidence > 1.0 ? confidence / 100 : confidence;
    final color = value >= 0.8 ? AppColors.success : (value >= 0.5 ? AppColors.warning : AppColors.error);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ANALYSIS CONFIDENCE', style: AppTextStyles.labelSmall.copyWith(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1)),
            Text('${(value * 100).toInt()}%', style: AppTextStyles.bodyMedium.copyWith(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(color: AppColors.bgDivider, borderRadius: BorderRadius.circular(3)),
            ),
            AnimatedContainer(
              duration: 1000.ms,
              height: 6,
              width: (Get.width - 48) * value,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withValues(alpha: 0.5), color]),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)],
              ),
            ).animate().shimmer(delay: 500.ms, duration: 2000.ms),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(Map stats) {
    return Row(
      children: [
        _buildStatCard('Total Claims', '${stats['totalClaims'] ?? 0}', Icons.article_outlined, AppColors.info),
        const SizedBox(width: 12),
        _buildStatCard('Verified', '${stats['correct'] ?? stats['verifiedClaims'] ?? 0}', Icons.check_circle_outlined, AppColors.success),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.bgDivider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(value, style: AppTextStyles.titleLarge.copyWith(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text(label, style: AppTextStyles.labelSmall.copyWith(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildNarrativeSection(String narrative) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SUMMARY ANALYSIS', style: AppTextStyles.labelSmall.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.bgDivider),
          ),
          child: Text(narrative, style: AppTextStyles.bodyMedium.copyWith(fontSize: 15, color: AppColors.textPrimary, height: 1.6)),
        ),
      ],
    );
  }

  Widget _buildFactorsSection(Map factors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TRUST DRIVERS', style: AppTextStyles.labelSmall.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: factors.entries.map((e) => _buildFactorChip(e.key as String, e.value)).toList(),
        ),
      ],
    );
  }

  Widget _buildFactorChip(String key, dynamic value) {
    final score = ((value ?? 0) as num).toDouble();
    final color = _getScoreColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(key.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 6),
          Text('${score.toInt()}', style: AppTextStyles.bodyMedium.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildDeductionsSection(List deductions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('INSTITUTIONAL DEDUCTIONS', style: AppTextStyles.labelSmall.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.error, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        ...deductions.map((e) => _buildDeductionItem(e as Map)),
      ],
    );
  }

  Widget _buildDeductionItem(Map d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text((d['reason'] as String?) ?? '', style: AppTextStyles.bodyMedium.copyWith(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Text('-${d['points']}', style: AppTextStyles.bodyMedium.copyWith(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error)),
        ],
      ),
    );
  }

  Widget _buildClaimsSection(List claims) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CLAIM VERIFICATION', style: AppTextStyles.labelSmall.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        if (claims.isEmpty)
          _buildEmptyBox('No specific claims extracted for this analysis.')
        else
          ...claims.asMap().entries.map((entry) => _buildClaimItem(entry.value as Map, entry.key)),
      ],
    );
  }

  Widget _buildClaimItem(Map claim, int index) {
    final status = (claim['status'] ?? '').toString().toLowerCase();
    final isVerified = status == 'correct' || status == 'mostly_correct' || claim['isVerified'] == true;
    final color = isVerified ? AppColors.success : AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isVerified ? Icons.check_circle : Icons.cancel, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((claim['claim'] ?? claim['text'] ?? '').toString(), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500, height: 1.4)),
                if (claim['explanation'] != null || claim['reasoning'] != null) ...[
                  const SizedBox(height: 8),
                  Text((claim['explanation'] ?? claim['reasoning'])?.toString() ?? '', style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (600 + (index * 100)).ms).slideX(begin: 0.05);
  }

  Widget _buildSourcesSection(List sources) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('VERIFIED SOURCES', style: AppTextStyles.labelSmall.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sources.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _buildSourceCard(sources[index] as Map),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceCard(Map source) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text((source['title'] ?? 'Source').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyMedium.copyWith(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const Spacer(),
          Text((source['domain'] ?? 'Institutional Data').toString(), style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildConclusionSection(String conclusion) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.brand, size: 32),
          const SizedBox(height: 16),
          Text('CONCLUSION', style: AppTextStyles.labelSmall.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brand, letterSpacing: 2)),
          const SizedBox(height: 12),
          Text(conclusion, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(fontSize: 14, color: AppColors.textPrimary, height: 1.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsSection(List diagnostics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ANALYSIS DIAGNOSTICS', style: AppTextStyles.labelSmall.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        if (diagnostics.isEmpty)
          _buildEmptyBox('No additional diagnostic data recorded.')
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Column(
              children: diagnostics.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold)),
                    Expanded(child: Text(d.toString(), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 13, height: 1.5))),
                  ],
                ),
              )).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, fontSize: 13, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(color: AppColors.bgDivider),
        const SizedBox(height: 16),
        Text(
          'TruthWorld employs multi-stage AI verification using institutional-grade data sources. This report represents a point-in-time analysis of the audio-visual content provided.',
          style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, fontSize: 10, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return AppColors.success;
    if (score >= 75) return const Color(0xFFA3E635);
    if (score >= 60) return Colors.yellowAccent;
    if (score >= 45) return AppColors.warning;
    if (score >= 30) return AppColors.error;
    return const Color(0xFF991B1B);
  }

  String _getRatingLabel(double score) {
    if (score >= 90) return 'EXCEPTIONAL';
    if (score >= 75) return 'HIGH INTEGRITY';
    if (score >= 60) return 'TRUSTWORTHY';
    if (score >= 45) return 'CAUTION ADVISED';
    if (score >= 30) return 'LOW INTEGRITY';
    return 'UNRELIABLE';
  }
}





