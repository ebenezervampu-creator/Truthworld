import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
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

      final currentUid = AuthService.to.uid;
      final userChannelId = AuthService.to.userChannel?.id;
      final isOwner = currentUid.isNotEmpty &&
          (video.ownerId == currentUid ||
              video.userId == currentUid ||
              (userChannelId != null &&
                  userChannelId.isNotEmpty &&
                  video.channelId == userChannelId));

      final isPendingApproval = video.isFactCheckPendingApproval &&
          !videoCtrl.rxVideo.value.isFactCheckApproved;

      if (isPendingApproval && !isOwner) {
        return _buildPendingReviewBlockerView();
      }

      if (reportData.isEmpty && video.factCheckUrl.isEmpty && video.uiReport == null) {
        return VideoAnalysisEmptyFallback(video: video);
      }

      return _buildFormattedDashboard(
        reportData,
        isOwner: isOwner,
        isPendingApproval: isPendingApproval,
      );
    });
  }

  Widget _buildOwnerApprovalBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_clock_rounded,
            color: Color(0xFFF59E0B),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Creator Review Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'This report is hidden from viewers until you approve it.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('videos')
                    .doc(video.id)
                    .update({
                  'isFactCheckApproved': true,
                  'aiFeatures.isFactCheckApproved': true,
                });
                videoCtrl.rxVideo.value = videoCtrl.rxVideo.value.copyWith(
                  isFactCheckApproved: true,
                );
                AppSnackbar.success(
                  'Fact-checking results approved & published for viewers!',
                );
              } catch (e) {
                AppSnackbar.error(
                  'Failed to approve fact-check. Please try again.',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Approve for Viewers',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingReviewBlockerView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                size: 40,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Verification Under Creator Review',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The channel has elected to review fact-check results before making them public. Results will appear once approved by the creator.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedDashboard(
    Map<String, dynamic> data, {
    required bool isOwner,
    required bool isPendingApproval,
  }) {
    final parsed = FactCheckDataParser.parse(
      data,
      fallbackReport: video.uiReport,
      fallbackTrustScore: video.trustScore > 0 ? video.trustScore : null,
      isVideoFactChecked: video.isFactChecked,
    );

    return Column(
      children: [
        if (isOwner && isPendingApproval) _buildOwnerApprovalBanner(context),
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
