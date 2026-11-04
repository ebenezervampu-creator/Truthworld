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

    // 🧠 Extract verification data
    final stats = data['factCheckStats'] as Map? ?? {};
    final claims = parsed.claims.isNotEmpty ? parsed.claims : (data['claims'] as List? ?? []);
    final diagnostics = data['diagnostics'] as List? ?? [];
    final hasClaims = claims.isNotEmpty;

    final narrative = parsed.viewerNote;
    final sources = parsed.sources;
    final uiReport = data['uiReport'] as Map? ?? {};
    final rawUiConclusion = uiReport['conclusion'];
    final uiConclusionStr = rawUiConclusion is Map
        ? (rawUiConclusion['text'] ?? rawUiConclusion['summary'] ?? '').toString()
        : (rawUiConclusion is String ? rawUiConclusion : (rawUiConclusion ?? '').toString());
    final conclusion = parsed.conclusion.isNotEmpty
        ? parsed.conclusion
        : (uiConclusionStr.isNotEmpty
            ? uiConclusionStr
            : (video.uiReport?.conclusion ?? ''));
    final conclusionSources = parsed.conclusionSources.isNotEmpty
        ? parsed.conclusionSources.map((s) => s.toMap()).toList()
        : (uiReport['conclusionSources'] as List? ??
            (rawUiConclusion is Map ? (rawUiConclusion['sources'] as List?) : null) ??
            (video.uiReport?.conclusionSources.isNotEmpty == true
                ? video.uiReport!.conclusionSources.map((s) => s.toMap()).toList()
                : const []));
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
              FactCheckReportHeader(tierBadgeLabel: parsed.tierBadgeLabel),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    const SizedBox(height: 24),
                    if (hasClaims) ...[
                      FactCheckConfidenceBar(confidence: confidence),
                      const SizedBox(height: 32),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.bgDivider),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.info.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.psychology_alt_outlined,
                                color: AppColors.info,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Subjective Discourse & Inquiry',
                                    style: AppTextStyles.titleMedium.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'No empirical factual assertions were extracted from this content. Fact verification applies exclusively to verifiable propositions.',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    FactCheckStatsRow(stats: stats),
                    const SizedBox(height: 32),
                    if (narrative.isNotEmpty) ...[
                      FactCheckNarrativeSection(narrative: narrative),
                      const SizedBox(height: 32),
                    ],
                    const FactCheckEpistemicBanner(),
                    const SizedBox(height: 24),
                    FactCheckClaimsSection(claims: claims, video: video),
                    const SizedBox(height: 32),
                    if (sources.isNotEmpty) ...[
                      FactCheckSourcesSection(sources: sources),
                      const SizedBox(height: 32),
                    ],
                    if (conclusion.isNotEmpty) ...[
                      FactCheckConclusionSection(
                        conclusion: conclusion,
                        sources: conclusionSources,
                      ),
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
