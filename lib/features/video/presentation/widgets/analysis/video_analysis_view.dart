import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/core/widgets/truth_lottie_animation.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/fact_check_data_parser.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Comprehensive AI Credibility & Fact-Check Dashboard View.
///
/// Houses the multi-tab layout (Fact-Claims, Overview, Conclusion),
/// verification banners, creator approval workflows, and transparent methodology.
/// Used directly inside [VideoAnalysisScreen] as a full page or in [VideoAnalysisBottomSheet].
class VideoAnalysisView extends StatelessWidget {
  const VideoAnalysisView({
    required this.video,
    required this.videoCtrl,
    required this.analysisCtrl,
    super.key,
  });

  final Video video;
  final VideoController videoCtrl;
  final VideoAnalysisController analysisCtrl;

  @override
  Widget build(BuildContext context) {
    return _buildFactCheckContent(context);
  }

  Widget _buildFactCheckContent(BuildContext context) {
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

      final parsed = FactCheckDataParser.parse(
        reportData,
        fallbackReport: video.uiReport,
        fallbackTrustScore: video.trustScore > 0 ? video.trustScore : null,
        isVideoFactChecked: video.isFactChecked,
      );

      if (parsed.isEmpty || (parsed.claims.isEmpty && parsed.viewerNote.isEmpty)) {
        return VideoAnalysisEmptyFallback(video: video);
      }

      return _buildFormattedDashboard(
        context,
        reportData,
        parsed: parsed,
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

  bool _isOpinionOrBeliefClaim(Map claim) {
    final nature = (claim['nature'] ?? '').toString().toUpperCase();
    if (nature == 'OPINION' ||
        nature == 'BELIEF' ||
        nature == 'SATIRE' ||
        nature == 'PREDICTION') {
      return true;
    }
    final status = (claim['status'] ??
            claim['verificationStatus'] ??
            claim['verdict'] ??
            claim['label'] ??
            '')
        .toString()
        .toLowerCase();
    if (status.contains('opinion') ||
        status.contains('belief') ||
        status.contains('faith') ||
        status.contains('tradition') ||
        status.contains('satire') ||
        status.contains('hyperbole')) {
      return true;
    }
    final verdict = ClaimVerdictHelper.resolveVerdict(claim);
    return verdict.isContextual;
  }

  List<dynamic> _getFactClaims(List<dynamic> allClaims) {
    final filtered = allClaims.where((c) {
      if (c is! Map) return false;
      return !_isOpinionOrBeliefClaim(c);
    }).toList();
    return filtered.isNotEmpty ? filtered : allClaims;
  }

  List<dynamic> _getOpinionClaims(List<dynamic> allClaims) {
    return allClaims.where((c) {
      if (c is! Map) return false;
      return _isOpinionOrBeliefClaim(c);
    }).toList();
  }

  Widget _buildFormattedDashboard(
    BuildContext context,
    Map<String, dynamic> data, {
    required ParsedFactCheckData parsed,
    required bool isOwner,
    required bool isPendingApproval,
  }) {
    return Column(
      children: [
        if (isOwner && isPendingApproval) _buildOwnerApprovalBanner(context),
        _buildTabBar(parsed),
        Expanded(
          child: Obx(() {
            final currentTab = analysisCtrl.selectedTab.value;
            if (currentTab == 5) {
              return _buildChaptersTabContent(context, parsed);
            }
            if (currentTab == 4) {
              return _buildOpinionsTabContent(context, parsed);
            }
            if (currentTab == 3) {
              return _buildConclusionTabContent(context, parsed);
            }
            if (currentTab == 2) {
              return _buildSourcesTabContent(parsed);
            }
            if (currentTab == 1) {
              return _buildOverviewTabContent(context, parsed);
            }
            return _buildClaimsTabContent(context, parsed);
          }),
        ),
      ],
    );
  }

  Widget _buildTabBar(ParsedFactCheckData parsed) {
    return Obx(() {
      final currentTab = analysisCtrl.selectedTab.value;
      final factClaims = _getFactClaims(parsed.claims);
      final opinionClaims = _getOpinionClaims(parsed.claims);
      final effectiveChapters = parsed.chapters.isNotEmpty
          ? parsed.chapters
          : ((videoCtrl.factCheckData['chapters'] is List)
              ? (videoCtrl.factCheckData['chapters'] as List)
              : video.chapters);

      return Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                _buildNewTabItem(
                  key: const Key('tab_claims'),
                  title: 'Fact Claims',
                  count: '${factClaims.length}',
                  icon: Icons.article_outlined,
                  isSelected: currentTab == 0,
                  onTap: () => analysisCtrl.setSelectedTab(0),
                ),
                _buildNewTabItem(
                  key: const Key('tab_overview'),
                  title: 'Overview',
                  icon: Icons.show_chart_rounded,
                  isSelected: currentTab == 1,
                  onTap: () => analysisCtrl.setSelectedTab(1),
                ),
                if (opinionClaims.isNotEmpty || currentTab == 4)
                  _buildNewTabItem(
                    key: const Key('tab_opinions'),
                    title: 'Opinions & Beliefs',
                    count: opinionClaims.isNotEmpty ? '${opinionClaims.length}' : null,
                    icon: Icons.psychology_outlined,
                    isSelected: currentTab == 4,
                    onTap: () => analysisCtrl.setSelectedTab(4),
                  ),
                if (effectiveChapters.isNotEmpty || currentTab == 5)
                  _buildNewTabItem(
                    key: const Key('tab_chapters'),
                    title: 'Chapters & Topics',
                    count: effectiveChapters.isNotEmpty ? '${effectiveChapters.length}' : null,
                    icon: Icons.bookmarks_outlined,
                    isSelected: currentTab == 5,
                    onTap: () => analysisCtrl.setSelectedTab(5),
                  ),
                _buildNewTabItem(
                  key: const Key('tab_sources'),
                  title: 'Sources',
                  count: parsed.sources.isNotEmpty ? '${parsed.sources.length}' : null,
                  icon: Icons.menu_book_outlined,
                  isSelected: currentTab == 2,
                  onTap: () => analysisCtrl.setSelectedTab(2),
                ),
                _buildNewTabItem(
                  key: const Key('tab_conclusion'),
                  title: 'Conclusion',
                  icon: Icons.verified_user_outlined,
                  isSelected: currentTab == 3,
                  onTap: () => analysisCtrl.setSelectedTab(3),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.6, color: AppColors.bgDivider),
        ],
      );
    });
  }

  Widget _buildNewTabItem({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    String? count,
    Key? key,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 15.5,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    title,
                    maxLines: 1,
                    style: GoogleFonts.roboto(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  if (count != null && count.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count,
                        style: GoogleFonts.roboto(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.black : Colors.white, // Strictly black on white!
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Active Underline Indicator Bar
            Container(
              height: 2.5,
              width: 28,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isMobileSized(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width < 768 || size.height < 500;
  }

  Widget _buildClaimsTabContent(BuildContext context, ParsedFactCheckData parsed) {
    final isMobile = _isMobileSized(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Verification Summary Card (Hidden on mobile sized devices & web mobiles)
        if (!isMobile) ...[
          VerificationSummaryCard(
            totalClaims: parsed.claims.length,
            verifiedCount: parsed.verifiedCount,
            cautionCount: parsed.cautionCount,
            falseCount: parsed.falseCount,
            trustScore: parsed.trustScore ?? (video.trustScore > 0 ? video.trustScore : null),
          ),
          const SizedBox(height: 16),
        ],

        // Fact-Checked Claims
        if (parsed.claims.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Column(
              children: [
                TruthLottieAnimation.emptyClaims(size: 56),
                const SizedBox(height: 14),
                Text(
                  'No Fact-Checked Claims',
                  style: GoogleFonts.roboto(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'No verifiable empirical claims were found in this video. The dialogue may consist of opinion, philosophy, or personal commentary.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
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

        // Citations & Verified Sources
        if (parsed.sources.isNotEmpty) ...[
          VideoAnalysisSourcesSection(sources: parsed.sources),
          const SizedBox(height: 16),
        ],

        // Transparent Scoring Methodology (IFCN / World-Class Standard)
        const VideoAnalysisMethodologySection(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOverviewTabContent(BuildContext context, ParsedFactCheckData parsed) {
    final isMobile = _isMobileSized(context);
    final summaryText = parsed.summary.isNotEmpty
        ? parsed.summary
        : (video.summary.isNotEmpty && UserFeedbackSanitizer.isValidVideoSummary(video.summary)
            ? video.summary
            : (video.description.trim().isNotEmpty
                ? video.description.trim()
                : ''));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Executive Video & Verification Overview Card
        _buildExecutiveOverviewCard(parsed, summaryText),
        const SizedBox(height: 16),

        // 2. Claims Overview & Key Findings Card
        if (parsed.claims.isNotEmpty) ...[
          _buildClaimsOverviewCard(context, parsed),
          const SizedBox(height: 16),
        ],

        // 3. Most Valuable Sources & Citations Card
        if (parsed.sources.isNotEmpty) ...[
          _buildMostValuableSourcesCard(context, parsed),
          const SizedBox(height: 16),
        ],

        // 4. Verification Summary Card (Hidden on mobile sized devices & web mobiles)
        if (!isMobile) ...[
          VerificationSummaryCard(
            totalClaims: parsed.claims.length,
            verifiedCount: parsed.verifiedCount,
            cautionCount: parsed.cautionCount,
            falseCount: parsed.falseCount,
            trustScore: parsed.trustScore ?? (video.trustScore > 0 ? video.trustScore : null),
          ),
          const SizedBox(height: 16),
        ],

        // 3. Confidence Level & Authenticity Breakdown
        if (parsed.confidenceVal > 0.05) ...[
          VideoAnalysisConfidenceBar(
            value: parsed.confidenceVal,
          ),
          const SizedBox(height: 16),
        ],

        // 4. AI Verification Methodology
        const VideoAnalysisMethodologySection(),
        const SizedBox(height: 16),

        // 5. Scoring Factors / Multi-Dimensional Breakdown
        if (parsed.factors.isNotEmpty) ...[
          VideoAnalysisFactorsCard(factors: parsed.factors),
          const SizedBox(height: 16),
        ],

        // 6. Chapter Trust Breakdown & Topic Extraction
        if (parsed.chapters.isNotEmpty) ...[
          VideoAnalysisChaptersSection(
            chapters: parsed.chapters,
            videoCtrl: videoCtrl,
          ),
          const SizedBox(height: 16),
        ],

        // 7. AI Viewer Note / Advisory
        if (parsed.viewerNote.isNotEmpty) ...[
          VideoAnalysisViewerNoteCard(note: parsed.viewerNote),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildExecutiveOverviewCard(
    ParsedFactCheckData parsed,
    String summaryText,
  ) {
    final effectiveSummary = summaryText.isNotEmpty
        ? summaryText
        : 'Our empirical verification system analyzed ${parsed.claims.length} claims in this video across ${parsed.sources.length} authoritative sources to evaluate its accuracy and credibility.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'EXECUTIVE OVERVIEW',
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              if (parsed.claims.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '${parsed.claims.length} CLAIMS',
                    style: GoogleFonts.roboto(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            effectiveSummary,
            style: GoogleFonts.roboto(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcesTabContent(ParsedFactCheckData parsed) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        if (parsed.sources.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF14161F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Center(
              child: Text(
                'No external citation links cataloged for this video.',
                style: GoogleFonts.roboto(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          VideoAnalysisSourcesSection(sources: parsed.sources),
      ],
    );
  }

  Widget _buildConclusionTabContent(BuildContext context, ParsedFactCheckData parsed) {
    final effectiveConclusion = ClaimVerdictHelper.buildCompleteVideoConclusion(
      rawConclusion: parsed.conclusion.isNotEmpty
          ? parsed.conclusion
          : (video.uiReport?.narrative.isNotEmpty ?? false
              ? video.uiReport!.narrative
              : ''),
      summary: parsed.summary.isNotEmpty ? parsed.summary : video.summary,
      videoTitle: video.title,
      claims: parsed.claims,
      verifiedCount: parsed.verifiedCount,
      cautionCount: parsed.cautionCount,
      falseCount: parsed.falseCount,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Synthesized Conclusion (Single Paragraph Complete Answer)
        if (effectiveConclusion.isNotEmpty) ...[
          VideoAnalysisConclusionCard(
            conclusion: effectiveConclusion,
          ),
          const SizedBox(height: 16),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 36,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Conclusion In Progress',
                  style: GoogleFonts.roboto(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'A final synthesized conclusion is being generated from verified claims. You can inspect each claim breakdown in the Fact-Claims tab.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 2. Navigation Actions: Switch to Claims or Overview
        Row(
          children: [
            if (parsed.claims.isNotEmpty)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => analysisCtrl.setSelectedTab(0),
                  icon: const Icon(Icons.fact_check_outlined, size: 15, color: Colors.white),
                  label: Text(
                    'Fact-Claims (${parsed.claims.length})',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.bgDivider),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (parsed.claims.isNotEmpty) const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => analysisCtrl.setSelectedTab(1),
                icon: const Icon(Icons.insights_rounded, size: 15, color: Colors.white),
                label: const Text('Overview', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.bgDivider),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildClaimsOverviewCard(BuildContext context, ParsedFactCheckData parsed) {
    if (parsed.claims.isEmpty) return const SizedBox.shrink();

    final highlights = ClaimVerdictHelper.getClaimsOverviewHighlights(parsed.claims);
    final topVerified = highlights['topVerified'] as Map<String, dynamic>?;
    final secondaryVerified = highlights['secondaryVerified'] as Map<String, dynamic>?;
    final topCaution = highlights['topCaution'] as Map<String, dynamic>?;
    final topFalse = highlights['topFalse'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.checklist_rtl_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'CLAIMS OVERVIEW & KEY FINDINGS',
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Text(
                  '${parsed.claims.length} CLAIMS',
                  style: GoogleFonts.roboto(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mini Breakdown Pills Row
          Row(
            children: [
              _buildMiniVerdictPill(
                label: 'Verified True',
                count: parsed.verifiedCount,
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 8),
              _buildMiniVerdictPill(
                label: 'Needs Context',
                count: parsed.cautionCount,
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 8),
              _buildMiniVerdictPill(
                label: 'Contradicted',
                count: parsed.falseCount,
                color: const Color(0xFFEF4444),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Top findings
          if (topVerified != null) ...[
            _buildClaimHighlightRow(
              badgeLabel: 'VERIFIED FACT',
              badgeColor: const Color(0xFF10B981),
              icon: Icons.check_circle_rounded,
              claimMap: topVerified,
            ),
            const SizedBox(height: 10),
          ],
          if (topCaution != null) ...[
            _buildClaimHighlightRow(
              badgeLabel: 'REQUIRES CONTEXT',
              badgeColor: const Color(0xFFF59E0B),
              icon: Icons.info_outline_rounded,
              claimMap: topCaution,
            ),
            const SizedBox(height: 10),
          ],
          if (topFalse != null) ...[
            _buildClaimHighlightRow(
              badgeLabel: 'CONTRADICTED',
              badgeColor: const Color(0xFFEF4444),
              icon: Icons.cancel_rounded,
              claimMap: topFalse,
            ),
            const SizedBox(height: 10),
          ] else if (secondaryVerified != null && topCaution == null) ...[
            _buildClaimHighlightRow(
              badgeLabel: 'VERIFIED FACT',
              badgeColor: const Color(0xFF10B981),
              icon: Icons.check_circle_rounded,
              claimMap: secondaryVerified,
            ),
            const SizedBox(height: 10),
          ],

          Divider(height: 16, color: AppColors.bgDivider.withValues(alpha: 0.6)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Explore all ${parsed.claims.length} claims with citations',
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => analysisCtrl.setSelectedTab(0),
                icon: const Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.white),
                label: const Text(
                  'View All Claims',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClaimHighlightRow({
    required String badgeLabel,
    required Color badgeColor,
    required IconData icon,
    required Map<String, dynamic> claimMap,
  }) {
    final claimText = ClaimVerdictHelper.cleanClaimText(
      claimMap['claim'] ?? claimMap['text'] ?? '',
      0,
    );
    final explanation = (claimMap['explanation'] ??
            claimMap['response'] ??
            claimMap['reasoning'] ??
            claimMap['whyWrong'] ??
            '')
        .toString()
        .trim();
    final cleanExplanation = ClaimVerdictHelper.cleanResponseText(explanation);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14161F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 11, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      badgeLabel,
                      style: GoogleFonts.roboto(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            claimText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.35,
            ),
          ),
          if (cleanExplanation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              cleanExplanation,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMostValuableSourcesCard(BuildContext context, ParsedFactCheckData parsed) {
    final valuableSources = ClaimVerdictHelper.getMostValuableSources(parsed.sources, limit: 3);
    if (valuableSources.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'MOST VALUABLE SOURCES & CITATIONS',
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Text(
                  '${parsed.sources.length} TOTAL',
                  style: GoogleFonts.roboto(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Primary documentation, regulatory filings, and authoritative bodies evaluated for this video.',
            style: GoogleFonts.roboto(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),

          // Top Sources List
          Column(
            children: valuableSources.map((sourceMap) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: VideoAnalysisSourceCard(source: sourceMap),
              );
            }).toList(),
          ),

          if (parsed.sources.length > 3) ...[
            const SizedBox(height: 4),
            Divider(height: 16, color: AppColors.bgDivider.withValues(alpha: 0.6)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${parsed.sources.length} verified citations available',
                    style: GoogleFonts.roboto(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => analysisCtrl.setSelectedTab(2),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.white),
                  label: Text(
                    'View All (${parsed.sources.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConclusionStatusBanner(ParsedFactCheckData parsed) {
    final score = parsed.trustScore ?? 0.0;
    final ratingLabel = parsed.trustLabel.isNotEmpty ? parsed.trustLabel : 'ANALYZED';
    final scoreColor = parsed.scoreColor;

    return Container(
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
              color: scoreColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_rounded,
              color: scoreColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ratingLabel,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (score > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${score.toInt()}% TRUST',
                          style: GoogleFonts.roboto(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: scoreColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  parsed.confidenceVal > 0
                      ? 'Synthesized with ${(parsed.confidenceVal * 100).toInt()}% confidence across verified databases'
                      : 'Synthesized across verified academic and official knowledge bases',
                  style: GoogleFonts.roboto(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimsSummaryPillCard(ParsedFactCheckData parsed) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'UNDERLYING CLAIMS BREAKDOWN',
                style: GoogleFonts.roboto(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: AppColors.textSecondary,
                ),
              ),
              InkWell(
                onTap: () => analysisCtrl.setSelectedTab(0),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View all',
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMiniVerdictPill(
                label: 'Verified',
                count: parsed.verifiedCount,
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 8),
              _buildMiniVerdictPill(
                label: 'Caution',
                count: parsed.cautionCount,
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 8),
              _buildMiniVerdictPill(
                label: 'False',
                count: parsed.falseCount,
                color: const Color(0xFFEF4444),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniVerdictPill({
    required String label,
    required int count,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpinionsTabContent(BuildContext context, ParsedFactCheckData parsed) {
    final opinionClaims = _getOpinionClaims(parsed.claims);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Epistemic Context Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141624),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.psychology_rounded,
                        color: Color(0xFF38BDF8),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subjective Perspectives & Beliefs',
                          style: GoogleFonts.roboto(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Personal viewpoints, philosophy, faith & satire',
                          style: GoogleFonts.roboto(
                            fontSize: 11.5,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'TruthWorld respects personal viewpoints, theological convictions, and creative expression. These statements are categorized for contextual clarity and are never marked as "True" or "False".',
                style: GoogleFonts.roboto(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (opinionClaims.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.psychology_outlined,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 14),
                Text(
                  'No Subjective Statements Found',
                  style: GoogleFonts.roboto(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'All evaluated statements in this video were analyzed as testable empirical claims.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Row(
            children: [
              const Icon(Icons.psychology_rounded, size: 16, color: Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PERSPECTIVES & BELIEFS (${opinionClaims.length})',
                  style: context.twTypography.overline.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: opinionClaims.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final claimMap = opinionClaims[index];
              if (claimMap is! Map) return const SizedBox.shrink();
              return VideoAnalysisClaimCard(
                claim: claimMap,
                index: index,
                allClaims: parsed.claims,
                allSources: parsed.sources,
                videoCtrl: videoCtrl,
                analysisCtrl: analysisCtrl,
                video: video,
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildChaptersTabContent(BuildContext context, ParsedFactCheckData parsed) {
    final effectiveChapters = parsed.chapters.isNotEmpty
        ? parsed.chapters
        : ((videoCtrl.factCheckData['chapters'] is List)
            ? (videoCtrl.factCheckData['chapters'] as List)
            : video.chapters);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Chapter Timeline Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141624),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.bookmarks_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interactive Timeline Chapters',
                      style: GoogleFonts.roboto(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select any topic chapter to jump to that segment in the video',
                      style: GoogleFonts.roboto(
                        fontSize: 11.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (effectiveChapters.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.bookmarks_outlined,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 14),
                Text(
                  'No Chapters Available',
                  style: GoogleFonts.roboto(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This video does not have automated topic markers or timestamps yet.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          VideoAnalysisChaptersSection(
            chapters: effectiveChapters,
            videoCtrl: videoCtrl,
          ),
        ],
      ],
    );
  }
}
