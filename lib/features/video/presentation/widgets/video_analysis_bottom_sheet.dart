import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    super.key,
  }) {
    final tag = video.id;
    if (Get.isRegistered<VideoController>(tag: tag)) {
      videoCtrl = Get.find<VideoController>(tag: tag);
    } else if (Get.isRegistered<VideoController>()) {
      videoCtrl = Get.find<VideoController>();
    } else {
      videoCtrl = Get.put(VideoController());
    }

    if (Get.isRegistered<VideoAnalysisController>(tag: tag)) {
      analysisCtrl = Get.find<VideoAnalysisController>(tag: tag);
    } else {
      analysisCtrl = Get.put(VideoAnalysisController(), tag: tag);
    }

    if (video.factCheckUrl.isNotEmpty && videoCtrl.factCheckData.isEmpty) {
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
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
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
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
    if (video.factCheckUrl.isEmpty) {
      return VideoAnalysisEmptyFallback(video: video);
    }

    return Obx(() {
      final reportData = videoCtrl.factCheckData;
      if (videoCtrl.isLoadingFactCheck.value) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.brand),
        );
      }

      if (reportData.isEmpty) {
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
}
