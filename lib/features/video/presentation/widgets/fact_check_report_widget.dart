import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:truthworld/features/video/data/models/fact_check_data_parser.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_methodology_section.dart';
import 'package:truthworld/features/video/presentation/widgets/fact_check/fact_check_barrel.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/video/presentation/widgets/fact_check/fact_check_barrel.dart';

/// Modal bottom sheet displaying multi-dimensional AI fact check analysis,
/// cryptographic verification, claim breakdowns, verified sources, and diagnostics.
class FactCheckReportWidget extends StatelessWidget {
  const FactCheckReportWidget({
    required this.data,
    required this.video,
    super.key,
  });

  final Map<String, dynamic> data;
  final Video video;

  @override
  Widget build(BuildContext context) {
    final parsed = FactCheckDataParser.parse(
      data,
      fallbackReport: video.uiReport,
      fallbackTrustScore: video.trustScore > 0 ? video.trustScore : null,
      isVideoFactChecked: video.isFactChecked,
    );

    // 🧠 Extract multi-dimensional credibility data
    final trustScore = parsed.trustScore ?? 0.0;
    final truthScore = ((data['truthScore'] ?? trustScore) as num).toDouble();
    final honestyScore = ((data['honestyScore'] ?? 0.0) as num).toDouble();
    final rationalityScore =
        ((data['rationalityScore'] ?? 0.0) as num).toDouble();

    final stats = data['factCheckStats'] as Map? ?? {};
    final claims = parsed.claims.isNotEmpty ? parsed.claims : (data['claims'] as List? ?? []);
    final diagnostics = data['diagnostics'] as List? ?? [];

    final narrative = parsed.viewerNote;
    final sources = parsed.sources;
    final uiReport = data['uiReport'] as Map? ?? {};
    final conclusion = uiReport['conclusion'] as String? ?? '';
    final confidence = parsed.confidenceVal;

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
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Column(
            children: [
              const FactCheckReportHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    const SizedBox(height: 24),
                    FactCheckMetricsRow(
                      truth: truthScore,
                      honesty: honestyScore,
                      rationality: rationalityScore,
                    ),
                    const SizedBox(height: 24),
                    FactCheckConfidenceBar(confidence: confidence),
                    const SizedBox(height: 32),
                    FactCheckStatsRow(stats: stats),
                    const SizedBox(height: 32),
                    if (narrative.isNotEmpty) ...[
                      FactCheckNarrativeSection(narrative: narrative),
                      const SizedBox(height: 32),
                    ],
                    FactCheckClaimsSection(claims: claims, video: video),
                    const SizedBox(height: 32),
                    if (sources.isNotEmpty) ...[
                      FactCheckSourcesSection(sources: sources),
                      const SizedBox(height: 32),
                    ],
                    if (conclusion.isNotEmpty) ...[
                      FactCheckConclusionSection(conclusion: conclusion),
                      const SizedBox(height: 32),
                    ],
                    FactCheckDiagnosticsSection(diagnostics: diagnostics),
                    const SizedBox(height: 32),
                    const VideoAnalysisMethodologySection(),
                    const SizedBox(height: 48),
                    FactCheckReportFooter(video: video),
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
}
