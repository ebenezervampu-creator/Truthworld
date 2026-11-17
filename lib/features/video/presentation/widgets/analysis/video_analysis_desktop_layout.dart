import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/core/widgets/truth_lottie_animation.dart';
import 'package:truthworld/features/video/data/models/claim_verdict_helper.dart';
import 'package:truthworld/features/video/data/models/fact_check_data_parser.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Desktop-tailored 2-column layout for the AI Credibility & Analysis Screen.
///
/// Provides a widescreen experience:
/// - Left Sidebar (~390px): Video preview anchor, Authenticity Index gauge,
///   2x2 stat boxes, AI synthesized takeaway, and empirical methodology notes.
/// - Right Main Canvas: Sleek desktop tab bar, wide search bar, sort dropdown,
///   filter pills, and interactive claim cards or deep-dive tabs.
class VideoAnalysisDesktopLayout extends StatelessWidget {
  const VideoAnalysisDesktopLayout({
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
    return Obx(() {
      final reportData = videoCtrl.factCheckData;
      if (videoCtrl.isLoadingFactCheck.value) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 64),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TruthLottieAnimation.aiScanning(size: 64),
                const SizedBox(height: 18),
                Text(
                  'SCANNING VIDEO FOR EMPIRICAL CLAIMS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cross-referencing verified knowledge bases & peer-reviewed sources…',
                  style: TextStyle(
                    fontSize: 13.5,
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
        isVideoFactChecked: video.isFactChecked,
      );

      if (!video.isFactChecked &&
          (parsed.isEmpty ||
              (parsed.claims.isEmpty && parsed.viewerNote.isEmpty))) {
        return VideoAnalysisEmptyFallback(video: video);
      }

      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                if (isOwner && isPendingApproval)
                  _buildOwnerApprovalBanner(context),
                if (parsed.isProvisional)
                  _buildProvisionalNoticeBanner(context),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. LEFT SIDEBAR (Video Context + Authenticity Summary)
                      SizedBox(
                        width: 390,
                        child: _buildDesktopSidebar(context, parsed),
                      ),
                      const SizedBox(width: 24),

                      // 2. RIGHT MAIN CONTENT PANE (Desktop Tabs + Content)
                      Expanded(
                        child: _buildDesktopMainPane(context, parsed),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildOwnerApprovalBanner(BuildContext context) {
    final remaining = video.factCheckGracePeriodRemaining;
    final remainingHours = remaining.inHours;
    final remainingMins = remaining.inMinutes % 60;
    final timeStr = remainingHours > 0
        ? '${remainingHours}h ${remainingMins}m'
        : '${remainingMins}m';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_clock_rounded,
            color: AppColors.warning,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Creator Review Window Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Auto-publishes to viewers in $timeStr to maintain platform truth transparency.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
              } catch (_) {
                AppSnackbar.error(
                  'Failed to approve fact-check. Please try again.',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Approve for Viewers',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvisionalNoticeBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Color(0xFF60A5FA),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FAST TRIAGE • PROVISIONAL CREDIBILITY',
                  style: TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Preliminary multimodal OCR and speech verification completed. Deep multi-source grounding and cross-examination are finalizing in the background.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingReviewBlockerView() {
    final remaining = video.factCheckGracePeriodRemaining;
    final remainingHours = remaining.inHours;
    final remainingMins = remaining.inMinutes % 60;
    final timeStr = remainingHours > 0
        ? '${remainingHours} hours and ${remainingMins} minutes'
        : '${remainingMins} minutes';

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
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                size: 40,
                color: AppColors.warning,
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
              'The creator has selected preliminary review. To protect viewers and uphold epistemic transparency, this fact-check report will automatically become public in $timeStr.',
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

  Widget _buildDesktopSidebar(BuildContext context, ParsedFactCheckData parsed) {
    // 1. Resolve duration string
    final durationStr = video.durationValue.inSeconds > 0
        ? FormatUtils.formatDuration(video.durationValue)
        : (video.duration.isNotEmpty ? video.duration : '00:00');

    // 2. Resolve title and subtitle
    var mainTitle = video.title.trim();
    var subtitle = '';

    if (mainTitle.contains(' - ')) {
      final parts = mainTitle.split(' - ');
      mainTitle = parts.first.trim();
      subtitle = parts.sublist(1).join(' - ').trim();
    } else if (mainTitle.contains(' | ')) {
      final parts = mainTitle.split(' | ');
      mainTitle = parts.first.trim();
      subtitle = parts.sublist(1).join(' | ').trim();
    } else if (mainTitle.contains('? ') && mainTitle.indexOf('? ') < mainTitle.length - 2) {
      final idx = mainTitle.indexOf('? ');
      subtitle = mainTitle.substring(idx + 2).trim();
      mainTitle = mainTitle.substring(0, idx + 1).trim();
    }

    if (subtitle.isEmpty) {
      if (video.channelName.isNotEmpty) {
        subtitle = video.channelName;
      } else if (video.description.isNotEmpty) {
        subtitle = video.description.split('\n').first.trim();
      } else {
        subtitle = 'The Science & Truth Explained';
      }
    }

    final rawSnippet = parsed.conclusion.isNotEmpty
        ? parsed.conclusion
        : (video.uiReport?.narrative.isNotEmpty ?? false
            ? video.uiReport!.narrative
            : '');

    final effectiveConclusionSnippet = FactCheckDataParser.isPlaceholderStatus(rawSnippet)
        ? (parsed.claims.isNotEmpty
            ? '${parsed.verifiedCount} of ${parsed.claims.length} claims verified with documented evidence across ${parsed.sources.length} sources.'
            : '')
        : rawSnippet;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Desktop Video Context Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (video.thumbnailUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: video.thumbnailUrl,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => ColoredBox(
                              color: Colors.white.withValues(alpha: 0.05),
                              child: const Center(
                                child: Icon(Icons.image, size: 24, color: AppColors.textTertiary),
                              ),
                            ),
                            errorWidget: (c, u, e) => ColoredBox(
                              color: Colors.white.withValues(alpha: 0.05),
                              child: const Icon(Icons.broken_image, size: 24, color: AppColors.textTertiary),
                            ),
                          )
                        else
                          ColoredBox(
                            color: Colors.white.withValues(alpha: 0.05),
                            child: const Icon(Icons.videocam, size: 24, color: AppColors.textTertiary),
                          ),
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              durationStr,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  mainTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.account_circle_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        Get.back();
                      }
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 15, color: Colors.white),
                    label: const Text(
                      'Back to Video',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Desktop Verification Summary Card
          VerificationSummaryCard(
            totalClaims: parsed.claims.length,
            verifiedCount: parsed.verifiedCount,
            cautionCount: parsed.cautionCount,
            falseCount: parsed.falseCount,
            isSidebar: true,
          ),
          const SizedBox(height: 16),

          // 3. AI Synthesized Takeaway Card (if applicable)
          if (effectiveConclusionSnippet.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, size: 15, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text(
                        'Truth Intelligence Takeaway',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    effectiveConclusionSnippet,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => analysisCtrl.setSelectedTab(3),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Full Conclusion →',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 4. Transparent Methodology Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Evaluated with peer-reviewed literature and empirical cross-referencing.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildDesktopMainPane(BuildContext context, ParsedFactCheckData parsed) {
    return Column(
      children: [
        _buildDesktopTabBar(context, parsed),
        Expanded(
          child: Obx(() {
            final currentTab = analysisCtrl.selectedTab.value;
            if (currentTab == 7) {
              return VideoCommunityNotesTab(video: video, parsed: parsed);
            }
            if (currentTab == 6) {
              return AiCredibilityChatSheet(
                video: video,
                allSources: parsed.parsedSources.isNotEmpty ? parsed.parsedSources : parsed.sources,
                allClaims: parsed.claims,
                summary: parsed.summary.isNotEmpty ? parsed.summary : parsed.conclusion,
                isEmbedded: true,
                onClose: () => analysisCtrl.selectedTab.value = 0,
              );
            }
            if (currentTab == 5) {
              return _buildDesktopChaptersTab(context, parsed);
            }
            if (currentTab == 4) {
              return _buildDesktopOpinionsTab(context, parsed);
            }
            if (currentTab == 3) {
              return _buildDesktopConclusionTab(context, parsed);
            }
            if (currentTab == 2) {
              return _buildDesktopSourcesTab(context, parsed);
            }
            if (currentTab == 1) {
              return _buildDesktopOverviewTab(context, parsed);
            }
            return _buildDesktopClaimsTab(context, parsed);
          }),
        ),
      ],
    );
  }

  Widget _buildDesktopTabBar(BuildContext context, ParsedFactCheckData parsed) {
    final factClaims = _getFactClaims(parsed.claims);
    final opinionClaims = _getOpinionClaims(parsed.claims);
    final effectiveChapters = parsed.chapters.isNotEmpty
        ? parsed.chapters
        : ((videoCtrl.factCheckData['chapters'] is List)
            ? (videoCtrl.factCheckData['chapters'] as List)
            : video.chapters);

    return Obx(() {
      final currentTab = analysisCtrl.selectedTab.value;
      return Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                _buildDesktopTabItem(
                  key: const Key('tab_claims'),
                  title: 'Fact Claims',
                  count: '${factClaims.length}',
                  icon: Icons.article_outlined,
                  isSelected: currentTab == 0,
                  onTap: () => analysisCtrl.setSelectedTab(0),
                ),
                _buildDesktopTabItem(
                  key: const Key('tab_overview'),
                  title: 'Overview',
                  icon: Icons.show_chart_rounded,
                  isSelected: currentTab == 1,
                  onTap: () => analysisCtrl.setSelectedTab(1),
                ),
                if (opinionClaims.isNotEmpty || currentTab == 4)
                  _buildDesktopTabItem(
                    key: const Key('tab_opinions'),
                    title: 'Opinions & Beliefs',
                    count: opinionClaims.isNotEmpty ? '${opinionClaims.length}' : null,
                    icon: Icons.psychology_outlined,
                    isSelected: currentTab == 4,
                    onTap: () => analysisCtrl.setSelectedTab(4),
                  ),
                if (effectiveChapters.isNotEmpty || currentTab == 5)
                  _buildDesktopTabItem(
                    key: const Key('tab_chapters'),
                    title: 'Chapters & Topics',
                    count: effectiveChapters.isNotEmpty ? '${effectiveChapters.length}' : null,
                    icon: Icons.bookmarks_outlined,
                    isSelected: currentTab == 5,
                    onTap: () => analysisCtrl.setSelectedTab(5),
                  ),
                _buildDesktopTabItem(
                  key: const Key('tab_sources'),
                  title: 'Sources',
                  count: parsed.sources.isNotEmpty ? '${parsed.sources.length}' : null,
                  icon: Icons.menu_book_outlined,
                  isSelected: currentTab == 2,
                  onTap: () => analysisCtrl.setSelectedTab(2),
                ),
                _buildDesktopTabItem(
                  key: const Key('tab_conclusion'),
                  title: 'Conclusion',
                  icon: Icons.verified_user_outlined,
                  isSelected: currentTab == 3,
                  onTap: () => analysisCtrl.setSelectedTab(3),
                ),
                _buildDesktopTabItem(
                  key: const Key('tab_community_notes'),
                  title: 'Community Notes',
                  icon: Icons.forum_outlined,
                  isSelected: currentTab == 7,
                  onTap: () => analysisCtrl.setSelectedTab(7),
                ),
                _buildDesktopTabItem(
                  key: const Key('tab_ai_chat'),
                  title: 'Ask AI',
                  icon: Icons.auto_awesome_rounded,
                  isSelected: currentTab == 6,
                  onTap: () {
                    AskAiScreen.open(
                      context,
                      video: video,
                      controller: videoCtrl,
                      allSources: parsed.parsedSources.isNotEmpty ? parsed.parsedSources : parsed.sources,
                      allClaims: parsed.claims,
                      summary: parsed.summary.isNotEmpty ? parsed.summary : parsed.conclusion,
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.6, color: AppColors.bgDivider),
        ],
      );
    });
  }

  Widget _buildDesktopTabItem({
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
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  if (count != null && count.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count,
                        style: TextStyle(
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
            Container(
              height: 2.5,
              width: 32,
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

  Widget _buildDesktopOpinionsTab(BuildContext context, ParsedFactCheckData parsed) {
    final opinionClaims = _getOpinionClaims(parsed.claims);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 24),
      children: [
        // Epistemic Context Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF141624),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.textLink.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.textLink.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.textLink.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.psychology_rounded,
                        color: AppColors.textLink,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subjective Perspectives, Beliefs & Traditions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Philosophical arguments, religious doctrines, satire & creative commentary',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'TruthWorld respects personal viewpoints, theological convictions, and creative expression. These statements are categorized for contextual clarity and are never marked as "True" or "False".',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        if (opinionClaims.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.psychology_outlined,
                  size: 52,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 14),
                Text(
                  'No Subjective Statements Found',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'All evaluated statements in this video were analyzed as testable empirical claims.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Row(
            children: [
              const Icon(Icons.psychology_rounded, size: 18, color: AppColors.textLink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PERSPECTIVES & BELIEFS (${opinionClaims.length})',
                  style: context.twTypography.overline.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: opinionClaims.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
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

  Widget _buildDesktopChaptersTab(BuildContext context, ParsedFactCheckData parsed) {
    final effectiveChapters = parsed.chapters.isNotEmpty
        ? parsed.chapters
        : ((videoCtrl.factCheckData['chapters'] is List)
            ? (videoCtrl.factCheckData['chapters'] as List)
            : video.chapters);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
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
                width: 40,
                height: 40,
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
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interactive Timeline Chapters',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Click any topic chapter to jump directly to that point in the video',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        if (effectiveChapters.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.bookmarks_outlined,
                  size: 52,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 14),
                Text(
                  'No Chapters Available',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This video does not have automated topic markers or timestamps yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
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

  Widget _buildDesktopClaimsTab(BuildContext context, ParsedFactCheckData parsed) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 24),
      children: [
        // 1. Claims Header: Title + Search Field + Sort Dropdown
        Obx(() {
          final sortOrder = analysisCtrl.sortOrder.value;
          return Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.article_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 7),
                  Text(
                    'Fact-Checked Claims (${parsed.claims.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Dedicated Desktop Search Field
              Container(
                width: 270,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        style: TextStyle(color: Colors.white, fontSize: 12.5),
                        decoration: const InputDecoration(
                          hintText: 'Search claims...',
                          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12.5),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: analysisCtrl.setSearchQuery,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Sort Dropdown Pill
              PopupMenuButton<String>(
                onSelected: analysisCtrl.setSortOrder,
                color: AppColors.bgSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                itemBuilder: (ctx) => [
                  _buildPopupItem('Video Order', sortOrder == 'Video Order'),
                  _buildPopupItem('Highest Confidence', sortOrder == 'Highest Confidence'),
                  _buildPopupItem('Disputed First', sortOrder == 'Disputed First'),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getSortLabel(sortOrder),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 12),

        // 2. Filter Pills Row
        Obx(() {
          final current = analysisCtrl.selectedClaimFilter.value;
          return Row(
            children: [
              _buildFilterPill(
                filterKey: 'All',
                label: 'All (${parsed.claims.length})',
                isSelected: current == 'All',
              ),
              const SizedBox(width: 8),
              _buildFilterPill(
                filterKey: 'Verified',
                label: 'Verified (${parsed.verifiedCount})',
                dotColor: AppColors.success,
                isSelected: current == 'Verified',
              ),
              const SizedBox(width: 8),
              _buildFilterPill(
                filterKey: 'Caution',
                label: 'Caution (${parsed.cautionCount})',
                dotColor: AppColors.warning,
                isSelected: current == 'Caution',
              ),
              const SizedBox(width: 8),
              _buildFilterPill(
                filterKey: 'False',
                label: 'False (${parsed.falseCount})',
                dotColor: AppColors.error,
                isSelected: current == 'False',
              ),
            ],
          );
        }),
        const SizedBox(height: 14),

        // 3. Claims List
        Obx(() {
          final filter = analysisCtrl.selectedClaimFilter.value;
          final search = analysisCtrl.searchQuery.value.toLowerCase().trim();
          final sort = analysisCtrl.sortOrder.value;

          final workingList = parsed.claims.where((c) {
            final claimMap = c;
            if (filter != 'All') {
              final verdict = ClaimVerdictHelper.resolveVerdict(claimMap);
              if (filter == 'Verified' && !verdict.isVerified) return false;
              if (filter == 'Caution' && !verdict.isCaution) return false;
              if (filter == 'False' && !verdict.isFalse) return false;
            }
            if (search.isNotEmpty) {
              final text = (claimMap['claim'] ?? claimMap['text'] ?? '').toString().toLowerCase();
              final explanation = (claimMap['explanation'] ?? '').toString().toLowerCase();
              final source = (claimMap['source'] ?? '').toString().toLowerCase();
              return text.contains(search) || explanation.contains(search) || source.contains(search);
            }
            return true;
          }).toList();

          if (sort == 'Disputed First') {
            workingList.sort((a, b) {
              final vA = ClaimVerdictHelper.resolveVerdict(a);
              final vB = ClaimVerdictHelper.resolveVerdict(b);
              final rankA = vA.isFalse ? 0 : (vA.isCaution ? 1 : 2);
              final rankB = vB.isFalse ? 0 : (vB.isCaution ? 1 : 2);
              return rankA.compareTo(rankB);
            });
          } else if (sort == 'Highest Confidence') {
            workingList.sort((a, b) {
              final vA = ClaimVerdictHelper.resolveVerdict(a);
              final vB = ClaimVerdictHelper.resolveVerdict(b);
              final scoreA = (a['confidence'] is num) ? (a['confidence'] as num).toDouble() : (vA.isVerified ? 1.0 : 0.5);
              final scoreB = (b['confidence'] is num) ? (b['confidence'] as num).toDouble() : (vB.isVerified ? 1.0 : 0.5);
              return scoreB.compareTo(scoreA);
            });
          }

          if (workingList.isEmpty) {
            final isSearch = search.isNotEmpty;
            final hasZeroTotalClaims = parsed.claims.isEmpty;

            if (isSearch) {
              return Container(
                padding: const EdgeInsets.all(28),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Center(
                  child: Text(
                    'No claims match "$search"',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }

            if (hasZeroTotalClaims) {
              return Container(
                padding: const EdgeInsets.all(32),
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fact_check_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Factual Claims Detected',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Our verification engine analyzed this video and found no specific verifiable factual claims. The content may consist of commentary, personal opinions, creative expression, or general conversation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => analysisCtrl.setSelectedTab(1),
                          icon: const Icon(Icons.show_chart_rounded, size: 16, color: Colors.black),
                          label: const Text(
                            'View Overview',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => analysisCtrl.setSelectedTab(3),
                          icon: const Icon(Icons.verified_user_outlined, size: 16, color: Colors.white),
                          label: const Text(
                            'View Conclusion',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(28),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Center(
                child: Text(
                  'No claims found in "$filter" category.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: workingList.length,
            separatorBuilder: (_, _) => const Divider(
              height: 16,
              thickness: 0.6,
              color: AppColors.bgDivider,
            ),
            itemBuilder: (context, index) {
              final claim = workingList[index];
              final originalIndex = parsed.claims.indexOf(claim);

              return VideoAnalysisClaimCard(
                claim: claim,
                index: originalIndex != -1 ? originalIndex : index,
                allClaims: parsed.claims,
                allSources: parsed.sources,
                videoCtrl: videoCtrl,
                analysisCtrl: analysisCtrl,
                video: video,
              );
            },
          );
        }),
        const SizedBox(height: 20),

        if (parsed.sources.isNotEmpty) ...[
          VideoAnalysisSourcesSection(sources: parsed.sources),
          const SizedBox(height: 16),
        ],

        const VideoAnalysisMethodologySection(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDesktopOverviewTab(BuildContext context, ParsedFactCheckData parsed) {
    final summaryText = parsed.summary.isNotEmpty
        ? parsed.summary
        : (video.summary.isNotEmpty && UserFeedbackSanitizer.isValidVideoSummary(video.summary)
            ? video.summary
            : (video.description.trim().isNotEmpty
                ? video.description.trim()
                : ''));

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 24),
      children: [
        // 1. Executive Video & Verification Overview Card
        _buildExecutiveOverviewCard(context, parsed, summaryText),
        const SizedBox(height: 16),

        // 2. Claims Overview & Key Findings Card
        if (parsed.claims.isNotEmpty) ...[
          _buildDesktopClaimsOverviewCard(context, parsed),
          const SizedBox(height: 16),
        ],

        // 3. Most Valuable Sources & Citations Card
        if (parsed.sources.isNotEmpty) ...[
          _buildDesktopMostValuableSourcesCard(context, parsed),
          const SizedBox(height: 16),
        ],

        // 3. System Confidence Bar (if scored / high confidence)
        if (parsed.confidenceVal > 0.05) ...[
          VideoAnalysisConfidenceBar(value: parsed.confidenceVal),
          const SizedBox(height: 16),
        ],

        // 4. Transparent Methodology Accordion
        const VideoAnalysisMethodologySection(),
        const SizedBox(height: 16),

        // 5. Scoring Factors (if present)
        if (parsed.factors.isNotEmpty) ...[
          VideoAnalysisFactorsCard(factors: parsed.factors),
          const SizedBox(height: 16),
        ],

        // 6. Chapter Breakdown
        if (parsed.chapters.isNotEmpty) ...[
          VideoAnalysisChaptersSection(
            chapters: parsed.chapters,
            videoCtrl: videoCtrl,
          ),
          const SizedBox(height: 16),
        ],

        // 7. AI Viewer Advisory & Synthesis Note
        if (parsed.viewerNote.isNotEmpty) ...[
          VideoAnalysisViewerNoteCard(note: parsed.viewerNote),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildExecutiveOverviewCard(
    BuildContext context,
    ParsedFactCheckData parsed,
    String summaryText,
  ) {
    final effectiveSummary = summaryText.isNotEmpty
        ? summaryText
        : 'Our empirical verification system analyzed ${parsed.claims.length} claims in this video across ${parsed.sources.length} authoritative sources to evaluate its accuracy and credibility.';

    return Container(
      padding: const EdgeInsets.all(18),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'EXECUTIVE VIDEO & TOPIC OVERVIEW',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              if (parsed.claims.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '${parsed.claims.length} CLAIMS ANALYZED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            effectiveSummary,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.55,
            ),
          ),
          if (parsed.claims.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: AppColors.bgDivider.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${parsed.verifiedCount} of ${parsed.claims.length} claims verified with documented evidence.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => analysisCtrl.setSelectedTab(0),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                  label: const Text(
                    'View All Claims',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  Widget _buildDesktopSourcesTab(BuildContext context, ParsedFactCheckData parsed) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 24),
      children: [
        if (parsed.sources.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Center(
              child: Text(
                'No external citation links cataloged for this video.',
                style: TextStyle(
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

  Widget _buildDesktopConclusionTab(BuildContext context, ParsedFactCheckData parsed) {
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
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 24),
      children: [
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
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'A final synthesized conclusion is being generated from verified claims. You can inspect each claim breakdown in the Fact-Claims tab.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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

        Row(
          children: [
            if (parsed.claims.isNotEmpty)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => analysisCtrl.setSelectedTab(0),
                  icon: const Icon(Icons.fact_check_outlined, size: 15, color: Colors.white),
                  label: const Text('Inspect Claims', style: TextStyle(color: Colors.white)),
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
            if (parsed.claims.isNotEmpty) const SizedBox(width: 12),
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
      ],
    );
  }

  Widget _buildDesktopClaimsOverviewCard(BuildContext context, ParsedFactCheckData parsed) {
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.checklist_rtl_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'CLAIMS OVERVIEW & KEY FINDINGS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Text(
                  '${parsed.claims.length} CLAIMS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Claims Distribution Row (Verified, Caution, False)
          Row(
            children: [
              Expanded(
                child: _buildBreakdownPill(
                  label: 'Verified True',
                  count: parsed.verifiedCount,
                  color: AppColors.success,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBreakdownPill(
                  label: 'Needs Context',
                  count: parsed.cautionCount,
                  color: AppColors.warning,
                  icon: Icons.error_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBreakdownPill(
                  label: 'Contradicted',
                  count: parsed.falseCount,
                  color: AppColors.error,
                  icon: Icons.cancel_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Highlighted Key Findings
          if (topVerified != null) ...[
            _buildClaimHighlightRow(
              badgeLabel: 'VERIFIED FACT',
              badgeColor: AppColors.success,
              icon: Icons.check_circle_rounded,
              claimMap: topVerified,
            ),
            const SizedBox(height: 10),
          ],
          if (topCaution != null) ...[
            _buildClaimHighlightRow(
              badgeLabel: 'REQUIRES CONTEXT',
              badgeColor: AppColors.warning,
              icon: Icons.info_outline_rounded,
              claimMap: topCaution,
            ),
            const SizedBox(height: 10),
          ],
          if (topFalse != null) ...[
            _buildClaimHighlightRow(
              badgeLabel: 'CONTRADICTED',
              badgeColor: AppColors.error,
              icon: Icons.cancel_rounded,
              claimMap: topFalse,
            ),
            const SizedBox(height: 10),
          ] else if (secondaryVerified != null && topCaution == null) ...[
            _buildClaimHighlightRow(
              badgeLabel: 'VERIFIED FACT',
              badgeColor: AppColors.success,
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
                  'Explore all ${parsed.claims.length} claims with citations & timestamps',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => analysisCtrl.setSelectedTab(0),
                icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                label: const Text(
                  'View All Claims',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            claimText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          if (cleanExplanation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              cleanExplanation,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopMostValuableSourcesCard(BuildContext context, ParsedFactCheckData parsed) {
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'MOST VALUABLE SOURCES & CITATIONS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Text(
                  '${parsed.sources.length} TOTAL SOURCES',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Primary documentation, regulatory filings, and authoritative bodies evaluated for this video.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

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
                    'Cataloging ${parsed.sources.length} verified references and citations',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => analysisCtrl.setSelectedTab(2),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                  label: Text(
                    'View All (${parsed.sources.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            children: [
              const Icon(Icons.analytics_outlined, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                'CLAIMS VERIFICATION BREAKDOWN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBreakdownPill(
                  label: 'Verified',
                  count: parsed.verifiedCount,
                  color: AppColors.success,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBreakdownPill(
                  label: 'Caution',
                  count: parsed.cautionCount,
                  color: AppColors.warning,
                  icon: Icons.error_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBreakdownPill(
                  label: 'False',
                  count: parsed.falseCount,
                  color: AppColors.error,
                  icon: Icons.cancel_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownPill({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required String filterKey,
    required String label,
    required bool isSelected,
    Color? dotColor,
  }) {
    final bgColor = isSelected ? Colors.white : AppColors.bgSurface;
    final textColor = isSelected ? Colors.black : Colors.white;
    final borderColor = isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.12);

    return InkWell(
      onTap: () => analysisCtrl.selectedClaimFilter.value = filterKey,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 7.5,
                height: 7.5,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: textColor, // Strictly black on white!
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String title, bool isSelected) {
    return PopupMenuItem<String>(
      value: title,
      height: 38,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check_rounded : Icons.circle_outlined,
            size: 16,
            color: isSelected ? AppColors.success : AppColors.textTertiary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _getSortLabel(String order) {
    switch (order) {
      case 'Highest Confidence':
        return 'Confidence';
      case 'Disputed First':
        return 'Disputed';
      default:
        return 'Video Order';
    }
  }
}
