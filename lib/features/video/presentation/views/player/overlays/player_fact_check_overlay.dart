import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/fact_check/fact_check_overlay_widgets.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/player_settings_panels.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'fact_check/fact_check_overlay_widgets.dart';

/// Full-screen fact-check overlay panel for TowerCustomPlayer.
/// Upgraded to declarative StatelessWidget powered by FactCheckOverlayController.
class FactCheckOverlay extends StatelessWidget {
  const FactCheckOverlay({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    final overlayCtrl = Get.put(FactCheckOverlayController());
    final vc = ctrl.videoController;
    final video = vc?.video;

    // Proactively load fact-check data if URL present and data not loaded
    if (video != null &&
        video.factCheckUrl.isNotEmpty &&
        vc != null &&
        vc.factCheckData.isEmpty &&
        !vc.isLoadingFactCheck.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        vc.loadFactCheckData(video.factCheckUrl);
      });
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {}, // Absorb taps
      child: Container(
        decoration: BoxDecoration(
          color: PT.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PT.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            Obx(
              () => PanelHeader(
                title: 'Fact-Check & Credibility',
                onBack: null,
                onClose: () {
                  ctrl.showFactCheckPopup.value = false;
                  ctrl.startHideTimer();
                },
                onContinue: () {
                  ctrl.toggleFactCheckAutoPlay();
                  ctrl.startHideTimer();
                },
                continueLabel: ctrl.isFactCheckAutoPlay.value
                    ? 'Pause'
                    : 'Play',
              ),
            ),
            Expanded(
              child: Obx(() {
                ctrl.showFactCheckPopup.value;
                ctrl.isFactCheckAutoPlay.value;
                ctrl.activeClaim.value;
                ctrl.showFactOverlay.value;

                if (vc != null && vc.isLoadingFactCheck.value) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.brand,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Loading fact-check data...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final reportData = vc?.factCheckData ?? <String, dynamic>{};
                final report = video?.uiReport;

                final analysisState = (reportData['analysisState'] ??
                        reportData['state'] ??
                        report?.summary.analysisState ??
                        (video?.isFactChecked == true
                            ? 'VERIFIED'
                            : 'ANALYZED'))
                    .toString();

                final rawTrustScore = reportData['trustScore'] ??
                    reportData['trustIndex'] ??
                    reportData['score'] ??
                    reportData['videoRating'] ??
                    report?.summary.rating ??
                    (video != null && video.trustScore > 0
                        ? video.trustScore
                        : null);
                final trustScore = (rawTrustScore is num)
                    ? rawTrustScore.toDouble()
                    : null;

                final trustLabel = (reportData['trustLabel'] ??
                        reportData['label'] ??
                        (trustScore != null
                            ? getRatingLabel(trustScore)
                            : (report?.summary.label.isNotEmpty == true
                                ? report!.summary.label
                                : analysisState)))
                    .toString();

                final confidenceRaw = reportData['confidence'] ??
                    report?.summary.confidence;
                final confidenceTier = (reportData['confidenceTier'] ??
                        (confidenceRaw is String ? confidenceRaw : ''))
                    .toString();
                final confidenceVal = (confidenceRaw is num)
                    ? (confidenceRaw > 1.0
                        ? (confidenceRaw / 100.0)
                        : confidenceRaw.toDouble())
                    : (confidenceTier.toLowerCase() == 'high'
                        ? 0.9
                        : (confidenceTier.toLowerCase() == 'medium'
                            ? 0.6
                            : 0.4));

                final viewerNote = (reportData['viewerNote'] ??
                        reportData['narrative'] ??
                        reportData['summary'] ??
                        reportData['explanation'] ??
                        reportData['uiReport']?['narrative'] ??
                        report?.narrative ??
                        report?.conclusion ??
                        '')
                    .toString();

                final factors = (reportData['scoringFactors'] ??
                        reportData['factors']) as Map? ??
                    (video?.scoringFactors != null
                        ? video!.scoringFactors!.toMap()
                        : {});

                final chapters = (reportData['chapters'] as List?) ?? [];

                final rawClaimsList = (reportData['claims'] as List?) ??
                    (reportData['uiReport']?['keyClaims'] as List?) ??
                    report?.keyClaims.map((c) => c.toMap()).toList() ??
                    [];
                final claims = rawClaimsList.map(normalizeClaim).toList();

                final rawSourcesList = (reportData['sources'] ??
                        reportData['richSources'] as List?) as List? ??
                    (reportData['uiReport']?['sources'] as List?) ??
                    report?.sources.map((s) => s.toMap()).toList() ??
                    [];
                final sources = rawSourcesList.map(normalizeSource).toList();

                final hasData = reportData.isNotEmpty ||
                    report != null ||
                    claims.isNotEmpty ||
                    trustScore != null ||
                    viewerNote.isNotEmpty;

                if (!hasData) {
                  return NoFactCheckFallback(video: video, vc: vc);
                }

                final posSec = ctrl.vv.position.inMilliseconds / 1000.0;

                // Compute empirical claim statistics using normalized verdict resolution
                var verifiedCount = 0;
                var cautionCount = 0;
                var falseCount = 0;
                for (final c in claims) {
                  final verdict = ClaimVerdictHelper.resolveVerdict(c);
                  if (verdict.isVerified) {
                    verifiedCount++;
                  } else if (verdict.isFalse) {
                    falseCount++;
                  } else {
                    cautionCount++;
                  }
                }

                return ListView(
                  controller: overlayCtrl.scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // 1. Hero Status & Credibility Card
                    FactCheckHeroCard(
                      analysisState: analysisState,
                      trustScore: trustScore,
                      trustLabel: trustLabel,
                      confidenceVal: confidenceVal,
                      confidenceTier: confidenceTier,
                      isFactChecked: video?.isFactChecked ?? false,
                      totalClaims: claims.length,
                      verifiedCount: verifiedCount,
                      cautionCount: cautionCount,
                      falseCount: falseCount,
                    ),
                    const SizedBox(height: 12),

                    // 2. AI Viewer Advisory & Summary Card
                    if (viewerNote.isNotEmpty) ...[
                      ViewerNoteCard(note: viewerNote),
                      const SizedBox(height: 14),
                    ],

                    // 3. Credibility Factors Card
                    if (factors.isNotEmpty) ...[
                      FactorsCard(factors: factors),
                      const SizedBox(height: 14),
                    ],

                    // 4. Chapter Credibility & Key Topics
                    if (chapters.isNotEmpty) ...[
                      FactCheckChaptersSection(chapters: chapters, ctrl: ctrl),
                      const SizedBox(height: 14),
                    ],

                    // 5. Fact-Checked Claims
                    if (claims.isNotEmpty) ...[
                      FactCheckClaimsSection(
                        claims: claims,
                        allSources: sources,
                        posSec: posSec,
                        video: video,
                        ctrl: ctrl,
                        overlayCtrl: overlayCtrl,
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 6. Verified Sources & Citations
                    if (sources.isNotEmpty) ...[
                      FactCheckSourcesSection(sources: sources),
                      const SizedBox(height: 14),
                    ],

                    // 7. Community & Dispute Actions Footer
                    FactCheckCommunityActions(video: video, claims: claims),
                    const SizedBox(height: 24),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
