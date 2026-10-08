import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/widgets/truth_lottie_animation.dart';
import 'package:truthworld/features/video/data/models/fact_check_data_parser.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

// Re-exports for 100% backward compatibility
export 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_widgets.dart';

class VideoAnalysisBottomSheet extends StatelessWidget {
  VideoAnalysisBottomSheet({
    required this.video,
    this.initialTabIndex = 0,
    VideoController? controller,
    super.key,
  }) {
    if (controller != null) {
      videoCtrl = controller;
    } else {
      final tag = video.id;
      if (Get.isRegistered<VideoController>(tag: tag)) {
        videoCtrl = Get.find<VideoController>(tag: tag);
      } else if (Get.isRegistered<VideoController>()) {
        videoCtrl = Get.find<VideoController>();
      } else {
        videoCtrl = Get.put(VideoController());
      }
    }

    final tag = video.id;
    if (Get.isRegistered<VideoAnalysisController>(tag: tag)) {
      analysisCtrl = Get.find<VideoAnalysisController>(tag: tag);
    } else {
      analysisCtrl = Get.put(VideoAnalysisController(), tag: tag);
    }
    analysisCtrl.setSelectedTab(initialTabIndex);

    if (videoCtrl.factCheckData.isEmpty &&
        !videoCtrl.hasAttemptedFactCheck.value) {
      videoCtrl.loadFactCheckData(video.factCheckUrl);
    }
  }

  final Video video;
  final int initialTabIndex;
  late final VideoController videoCtrl;
  late final VideoAnalysisController analysisCtrl;
  BuildContext get context => Get.context!;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        width: isDesktop ? 760 : double.infinity,
        decoration: BoxDecoration(
          color: AppColors.bgPage.withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppColors.bgDivider),
          boxShadow: [
            BoxShadow(
              color: AppColors.bgPage.withValues(alpha: 0.5),
              blurRadius: 32,
              spreadRadius: 8,
            ),
          ],
        ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            children: [
              _buildDragHandle(),
              _buildHeader(context),
              const Divider(height: 1, color: AppColors.bgDivider),
              Expanded(
                child: _buildFactCheckContent(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textTertiary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TruthLottieAnimation.verifiedShield(size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'AI CREDIBILITY & ANALYSIS',
                      style: context.twTypography.overline.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brand,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  video.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.twTypography.title.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
            ),
            onPressed: Get.back,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.bgSurface,
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactCheckContent() {
    return Obx(() {
      final reportData = videoCtrl.factCheckData;
      if (videoCtrl.isLoadingFactCheck.value) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TruthLottieAnimation.aiScanning(size: 56),
                const SizedBox(height: 16),
                Text(
                  'SCANNING VIDEO FOR EMPIRICAL CLAIMS',
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Cross-referencing verified knowledge bases…',
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (reportData.isEmpty && video.factCheckUrl.isEmpty && video.uiReport == null) {
        return VideoAnalysisEmptyFallback(video: video);
      }

      return _buildFormattedDashboard(reportData);
    });
  }

  Widget _buildFormattedDashboard(Map<String, dynamic> data) {
    final parsed = FactCheckDataParser.parse(
      data,
      fallbackReport: video.uiReport,
      fallbackTrustScore: video.trustScore > 0 ? video.trustScore : null,
      isVideoFactChecked: video.isFactChecked,
    );

    return Column(
      children: [
        _buildTabBar(parsed.claims.length),
        const Divider(height: 1, color: AppColors.bgDivider),
        Expanded(
          child: Obx(() {
            final isOverview = analysisCtrl.selectedTab.value == 1;
            if (isOverview) {
              return _buildOverviewTabContent(parsed);
            }
            return _buildClaimsTabContent(parsed);
          }),
        ),
      ],
    );
  }

  Widget _buildTabBar(int totalClaims) {
    return Obx(() {
      final currentTab = analysisCtrl.selectedTab.value;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.bgDivider),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildTabPill(
                  title: 'Fact-Claims',
                  count: totalClaims > 0 ? '$totalClaims' : null,
                  icon: Icons.fact_check_outlined,
                  isSelected: currentTab == 0,
                  onTap: () => analysisCtrl.setSelectedTab(0),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildTabPill(
                  title: 'Overview',
                  icon: Icons.insights_rounded,
                  isSelected: currentTab == 1,
                  onTap: () => analysisCtrl.setSelectedTab(1),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildTabPill({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    String? count,
  }) {
    return Material(
      color: isSelected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.black : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.black : AppColors.textSecondary,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.black.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count,
                    style: GoogleFonts.roboto(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClaimsTabContent(ParsedFactCheckData parsed) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      physics: const BouncingScrollPhysics(),
      children: [
        // Quick Overview Access Card
        Material(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => analysisCtrl.setSelectedTab(1),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.insights_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      parsed.trustScore != null && parsed.trustScore! > 0
                          ? 'Trust Score: ${parsed.trustScore!.toInt()}% • Tap to view Overview'
                          : 'Tap to view full analysis overview & factors',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Overview',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 5. Fact-Checked Claims
        if (parsed.claims.isNotEmpty) ...[
          VideoAnalysisClaimsSection(
            claims: parsed.claims,
            allSources: parsed.sources,
            verifiedCount: parsed.verifiedCount,
            cautionCount: parsed.cautionCount,
            falseCount: parsed.falseCount,
            videoCtrl: videoCtrl,
            analysisCtrl: analysisCtrl,
            video: video,
          ),
          const SizedBox(height: 16),
        ],

        // 6. Citations & Verified Sources
        if (parsed.sources.isNotEmpty) ...[
          VideoAnalysisSourcesSection(sources: parsed.sources),
          const SizedBox(height: 16),
        ],

        // 7. Transparent Scoring Methodology (IFCN / World-Class Standard)
        const VideoAnalysisMethodologySection(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOverviewTabContent(ParsedFactCheckData parsed) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Hero Status & Credibility Badge Card
        VideoAnalysisHeroCard(
          analysisState: parsed.analysisState,
          scoreAvailable: parsed.scoreAvailable,
          trustScore: parsed.trustScore,
          trustLabel: parsed.trustLabel,
          confidenceVal: parsed.confidenceVal,
          confidenceTier: parsed.confidenceTier,
          totalClaims: parsed.claims.length,
          verifiedCount: parsed.verifiedCount,
          cautionCount: parsed.cautionCount,
          falseCount: parsed.falseCount,
          tierBadgeLabel: parsed.tierBadgeLabel,
        ),
        const SizedBox(height: 16),

        // 2. AI Viewer Note / Advisory
        if (parsed.viewerNote.isNotEmpty) ...[
          VideoAnalysisViewerNoteCard(note: parsed.viewerNote),
          const SizedBox(height: 16),
        ],

        // 3. Scoring Factors / Multi-Dimensional Breakdown
        if (parsed.factors.isNotEmpty) ...[
          VideoAnalysisFactorsCard(factors: parsed.factors),
          const SizedBox(height: 16),
        ],

        // 4. Chapter Trust Breakdown & Topic Extraction
        if (parsed.chapters.isNotEmpty) ...[
          VideoAnalysisChaptersSection(
            chapters: parsed.chapters,
            videoCtrl: videoCtrl,
          ),
          const SizedBox(height: 16),
        ],

        // Button to switch back to Claims
        if (parsed.claims.isNotEmpty) ...[
          OutlinedButton.icon(
            onPressed: () => analysisCtrl.setSelectedTab(0),
            icon: const Icon(Icons.fact_check_outlined, size: 16),
            label: Text('View Fact-Checked Claims (${parsed.claims.length})'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppColors.bgDivider),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 6. Citations & Verified Sources
        if (parsed.sources.isNotEmpty) ...[
          VideoAnalysisSourcesSection(sources: parsed.sources),
          const SizedBox(height: 16),
        ],

        // 7. Transparent Scoring Methodology (IFCN / World-Class Standard)
        const VideoAnalysisMethodologySection(),
        const SizedBox(height: 24),
      ],
    );
  }
}
