import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/truth_lottie_animation.dart';
import 'package:truthworld/features/video/data/models/fact_check_data_parser.dart';
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
        !vc.isLoadingFactCheck.value &&
        !vc.hasAttemptedFactCheck.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (vc.factCheckData.isEmpty &&
            !vc.isLoadingFactCheck.value &&
            !vc.hasAttemptedFactCheck.value) {
          vc.loadFactCheckData(video.factCheckUrl);
        }
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
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TruthLottieAnimation.aiScanning(size: 48),
                        const SizedBox(height: 12),
                        const Text(
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

                final parsed = FactCheckDataParser.parse(
                  vc?.factCheckData,
                  fallbackReport: video?.uiReport,
                  fallbackTrustScore: video != null && video.trustScore > 0
                      ? video.trustScore
                      : null,
                  isVideoFactChecked: video?.isFactChecked == true,
                );

                if (parsed.isEmpty || (parsed.claims.isEmpty && parsed.viewerNote.isEmpty)) {
                  return NoFactCheckFallback(video: video, vc: vc);
                }

                final analysisState = parsed.analysisState;
                final trustScore = parsed.trustScore;
                final trustLabel = parsed.trustLabel;
                final confidenceVal = parsed.confidenceVal;
                final confidenceTier = parsed.confidenceTier;
                final viewerNote = parsed.viewerNote;
                final claims = parsed.claims.map(normalizeClaim).toList();
                final sources = parsed.sources.map(normalizeSource).toList();
                final factors = parsed.factors.isNotEmpty
                    ? parsed.factors
                    : (video?.scoringFactors != null
                        ? video!.scoringFactors!.toMap()
                        : const <String, dynamic>{});
                final chapters = parsed.chapters;
                final posSec = ctrl.vv.position.inMilliseconds / 1000.0;

                final verifiedCount = parsed.verifiedCount;
                final cautionCount = parsed.cautionCount;
                final falseCount = parsed.falseCount;

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
