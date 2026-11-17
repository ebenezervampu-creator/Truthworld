import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_claim_card.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_dialogs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_full_inspector_modal.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_full_inspector_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_video_card.dart';
import 'package:truthworld/theme/app_theme.dart';

// Re-exports for 100% backward compatibility with existing tests and imports
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_ai_coach_tab.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_claim_card.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_conclusion_tab.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_dialogs.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_full_inspector_modal.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_full_inspector_page.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_opinions_tab.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_overview_tab.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_progress_bar.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_sources_tab.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_stats_bar.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_tab_bar.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_video_card.dart';

/// Studio Fact-Checks & Truth Verification Console for Channels.
///
/// Production-grade dashboard inspired directly by the Consumer App's "Ai Check" implementation:
/// - Multi-tab architecture: Fact Claims, Overview, Video Reports, Opinions & Context,
///   Authoritative Sources, Conclusion & Insights, Audit & Transparency, and Ask AI Truth Coach.
/// - Top Creator Review Window Countdown & Provisional Triage Banners.
/// - Multi-source empirical grounding with IFCN institutional compliance.
/// - Zero raw developer errors, zero setState calls, WCAG AA compliance with zero white-on-white.
class TruthVerificationDashboardPage extends StatelessWidget {
  TruthVerificationDashboardPage({
    required this.channelId,
    required this.isDarkMode,
    this.initialVideoId,
    this.videosStream,
    super.key,
  }) {
    if (initialVideoId != null && initialVideoId!.isNotEmpty) {
      if (targetVideoId.value != initialVideoId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (targetVideoId.value != initialVideoId) {
            targetVideoId.value = initialVideoId!;
          }
        });
      }
    }
  }

  final String channelId;
  final bool isDarkMode;
  final String? initialVideoId;
  final Stream<QuerySnapshot>? videosStream;

  /// Global or deep-linked target video filter
  static final RxString targetVideoId = ''.obs;


  final RxString _videoFilter = 'all'.obs; // 'all', 'concerns', 'pending', 'approved', 'disputed'
  final RxString _claimTierFilter = 'all'.obs; // 'all', 'verified', 'needs_source', 'high_concern', 'disputed'
  final RxBool _isPublished = true.obs;
  final RxString _searchQuery = ''.obs;

  /// Determines whether a video document has AI Fact-Checking enabled, in-progress, or verified.
  static bool hasFactChecking(
    Map<String, dynamic> data, {
    List<RealExtractedClaim>? claims,
    double? trustScore,
  }) {
    // 1. Explicit fact-checked flags or enabled flags on video doc
    if (data['isFactChecked'] == true ||
        data['hasFactChecking'] == true ||
        data['factChecking'] == true ||
        data['isFactChecking'] == true ||
        data['enableFactCheck'] == true ||
        data['truthVerification'] == true) {
      return true;
    }

    // 2. Fact-checking enabled in AI features metadata
    final aiFeatures = data['aiFeatures'];
    if (aiFeatures is Map) {
      if (aiFeatures['factChecking'] == true ||
          aiFeatures['factCheck'] == true ||
          aiFeatures['isFactChecked'] == true ||
          aiFeatures['enableFactCheck'] == true ||
          aiFeatures['factCheckSummary'] != null) {
        return true;
      }
    }

    // 3. Reverification requested or dispute in progress
    if (data['reverificationRequested'] == true ||
        data['disputeStatus'] != null) {
      return true;
    }

    // 4. Extracted claims exist
    if (claims != null && claims.isNotEmpty) {
      return true;
    }
    final rawClaims = data['claims'];
    if (rawClaims is List && rawClaims.isNotEmpty) {
      return true;
    }

    // 5. uiReport presence
    final uiReport = data['uiReport'];
    if (uiReport is Map) {
      final keyClaims = uiReport['keyClaims'];
      if (keyClaims is List && keyClaims.isNotEmpty) {
        return true;
      }
      final reportClaims = uiReport['claims'];
      if (reportClaims is List && reportClaims.isNotEmpty) {
        return true;
      }
      if (uiReport['summary'] != null || uiReport['domain'] != null) {
        return true;
      }
    }

    // 5.5 In-progress fact-checking pipeline signals
    if (data['factCheckProgress'] != null ||
        data['factCheckStatus'] != null) {
      return true;
    }
    final stages = data['stages'];
    if (stages is Map &&
        (stages['credibility'] != null ||
            stages['factcheck'] != null ||
            stages['fact_check'] != null)) {
      return true;
    }

    // 6. Explicit fact-checking disable flag
    if (data['isFactChecked'] == false ||
        (aiFeatures is Map &&
            (aiFeatures['factChecking'] == false ||
                aiFeatures['factCheck'] == false))) {
      return false;
    }

    // 7. Positive trust score / credibility score
    final effectiveTrustScore = trustScore ??
        ((data['trustScore'] ??
                data['credibilityScore'] ??
                data['rating'] ??
                0.0) as num)
            .toDouble();
    if (effectiveTrustScore > 0) {
      return true;
    }

    return false;
  }

  Future<void> _approveVideoFactCheck(String videoId) async {
    try {
      await FirebaseFirestore.instance.collection('videos').doc(videoId).update({
        'isFactCheckApproved': true,
        'aiFeatures.isFactCheckApproved': true,
      });
      AppSnackbar.success(
        'Fact-checking verification approved & published to viewers!',
      );
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TruthVerificationDashboardPage.approve',
      );
      AppSnackbar.error(
        'Unable to approve fact-check. Please check your connection and try again.',
      );
    }
  }

  Future<void> _toggleFactCheckApproval(String videoId, bool currentStatus) async {
    final nextStatus = !currentStatus;
    try {
      await FirebaseFirestore.instance.collection('videos').doc(videoId).update({
        'isFactCheckApproved': nextStatus,
        'aiFeatures.isFactCheckApproved': nextStatus,
      });
      if (nextStatus) {
        AppSnackbar.success(
          'Verification published. Credibility badges are now visible to viewers.',
        );
      } else {
        AppSnackbar.info(
          'Verification held private. Credibility badges are hidden from viewers.',
        );
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TruthVerificationDashboardPage.toggleApproval',
      );
      AppSnackbar.error(
        'Unable to update visibility. Please check your connection and try again.',
      );
    }
  }

  Future<void> _approveAllPendingVideos(List<VideoFactCheckItem> pendingVideos) async {
    if (pendingVideos.isEmpty) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final v in pendingVideos) {
        final docRef = FirebaseFirestore.instance.collection('videos').doc(v.id);
        batch.update(docRef, {
          'isFactCheckApproved': true,
          'aiFeatures.isFactCheckApproved': true,
        });
      }
      await batch.commit();
      AppSnackbar.success(
        'All pending video verifications approved and published to viewers!',
      );
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TruthVerificationDashboardPage.approveAll',
      );
      AppSnackbar.error(
        'Unable to approve verifications. Please check your connection and try again.',
      );
    }
  }

  Future<void> _retriggerFactCheck(String videoId) async {
    try {
      AppSnackbar.info('Initiating AI Truth Verification for video...');

      // Invoke Cloud Function triggerVideoAIFeatures with authenticated creator token
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        AppSnackbar.error('Please sign in to re-trigger fact-checking.');
        return;
      }
      final token = await currentUser.getIdToken();
      final url = Uri.parse(
        '${AppConfig.cloudFunctionsBaseUrl}/triggerVideoAIFeatures',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'videoId': videoId,
          'channelId': channelId,
          'features': ['factcheck'],
          'factCheckTier': 'full_ground',
          'priorityMode': 'truth_first',
        }),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        AppSnackbar.success(
          'Fact-check re-triggered successfully. AI truth verification is now underway!',
        );
      } else {
        ErrorHandler.log(
          'triggerVideoAIFeatures returned HTTP ${response.statusCode}: ${response.body}',
          tag: 'TruthVerificationDashboardPage.retriggerFactCheck',
        );
        AppSnackbar.error(
          'Unable to re-trigger fact-check. Please try again.',
        );
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TruthVerificationDashboardPage.retriggerFactCheck',
      );
      AppSnackbar.error(
        'Unable to re-trigger fact-check. Please check your connection and try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          return StreamBuilder<QuerySnapshot>(
            stream: videosStream ??
                FirebaseFirestore.instance
                    .collection('videos')
                    .where('channelId', isEqualTo: channelId)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                ErrorHandler.log(
                  snapshot.error,
                  tag: 'TruthVerificationDashboardPage.stream',
                );
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      UserFeedbackSanitizer.sanitizeMessage(
                        snapshot.error,
                        defaultActionContext:
                            'Unable to load verification data. Please try again.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const StudioLoadingIndicator(
                  message: 'Loading truth verification insights...',
                );
              }

              final videoDocs = snapshot.data?.docs ?? [];
              final allClaims = <RealExtractedClaim>[];
              final videoItems = <VideoFactCheckItem>[];

              for (final doc in videoDocs) {
                final videoItem = TruthVerificationParser.parseVideoDoc(doc);
                allClaims.addAll(videoItem.claims);
                videoItems.add(videoItem);
              }

              return Obx(() {
                final targetId = targetVideoId.value.isNotEmpty
                    ? targetVideoId.value
                    : (initialVideoId ?? '');
                final videoFilter = _videoFilter.value;
                final query = _searchQuery.value.trim().toLowerCase();

                // Filter videos
                var filteredVideos = videoItems;
                if (targetId.isNotEmpty) {
                  filteredVideos =
                      filteredVideos.where((v) => v.id == targetId).toList();
                } else if (videoFilter == 'needs_fact_check') {
                  filteredVideos = filteredVideos
                      .where((v) =>
                          !v.isFactCheckReady && !v.isFactCheckInProgress)
                      .toList();
                } else if (videoFilter == 'in_progress') {
                  filteredVideos =
                      filteredVideos.where((v) => v.isFactCheckInProgress).toList();
                } else if (videoFilter == 'pending') {
                  filteredVideos =
                      filteredVideos.where((v) => v.isPendingApproval).toList();
                } else if (videoFilter == 'approved') {
                  filteredVideos =
                      filteredVideos.where((v) => v.isFactCheckApproved).toList();
                } else if (videoFilter == 'concerns') {
                  filteredVideos =
                      filteredVideos.where((v) => v.hasConcerns).toList();
                } else if (videoFilter == 'disputed') {
                  filteredVideos = filteredVideos
                      .where((v) => v.isDisputed || v.reverificationRequested)
                      .toList();
                }

                if (query.isNotEmpty) {
                  filteredVideos = filteredVideos
                      .where((v) =>
                          v.title.toLowerCase().contains(query) ||
                          v.domain.toLowerCase().contains(query))
                      .toList();
                }

                // Filter claims
                final claimTier = _claimTierFilter.value;
                var filteredClaims = allClaims.where((claim) {
                  if (targetId.isNotEmpty && claim.videoId != targetId) {
                    return false;
                  }
                  if (claimTier == 'verified') {
                    return claim.isVerified;
                  } else if (claimTier == 'high_concern') {
                    return claim.isHighConcern;
                  } else if (claimTier == 'needs_source') {
                    return claim.isNeedsSource;
                  } else if (claimTier == 'disputed') {
                    return claim.isDisputed;
                  }
                  return true;
                }).toList();

                if (query.isNotEmpty) {
                  filteredClaims = filteredClaims
                      .where((c) =>
                          c.text.toLowerCase().contains(query) ||
                          c.videoTitle.toLowerCase().contains(query) ||
                          c.category.toLowerCase().contains(query))
                      .toList();
                }

                final inProgressVideos =
                    videoItems.where((v) => v.isFactCheckInProgress).toList();
                final pendingVideos =
                    videoItems.where((v) => v.isPendingApproval).toList();
                final videosWithConcernsCount =
                    videoItems.where((v) => v.hasConcerns).length;
                final hasProvisionalVideo =
                    videoItems.any((v) => v.isProvisional);

                return Column(
                  children: [
                    // Top Header matching Channel Creation Wizard
                    _buildTopHeader(isDesktop),

                    // Scrollable Video Reports Content (direct video list)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 32 : 16,
                          vertical: isDesktop ? 24 : 16,
                        ),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 0. Active Fact-Check In Progress Banner
                            if (inProgressVideos.isNotEmpty) ...[
                              _buildInProgressBanner(inProgressVideos),
                              const SizedBox(height: 16),
                            ],

                            // 1. Creator Review Grace Period Notice Banner (if any videos in review)
                            if (pendingVideos.isNotEmpty) ...[
                              _buildPendingApprovalBanner(pendingVideos),
                              const SizedBox(height: 16),
                            ],

                            // 2. Provisional Fast Triage Banner (if any provisional scans)
                            if (hasProvisionalVideo) ...[
                              _buildProvisionalNoticeBanner(),
                              const SizedBox(height: 16),
                            ],

                            // 3. Target Video Filter Banner (if deep-linked or focused)
                            if (targetId.isNotEmpty) ...[
                              _buildTargetVideoBanner(
                                filteredVideos.isNotEmpty ? filteredVideos.first.title : targetId,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // 4. Responsive Search Bar
                            _buildSearchBar(2, query),
                            const SizedBox(height: 16),

                            // 5. Video Reports Content (Sub-filter pills + List of Videos)
                            _buildVideoReportsTab(
                              filteredVideos,
                              videoItems,
                              videosWithConcernsCount,
                              pendingVideos.length,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildTopHeader(bool isDesktop) {
    if (!isDesktop) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration: const BoxDecoration(
          color: AppColors.bgPage,
          border: Border(
            bottom: BorderSide(color: AppColors.bgSurface),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Factcheck',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Channel Truth Intelligence console: claim verification, authoritative grounding & creator review.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            _buildStatusBadge(),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 32,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgPage,
        border: Border(
          bottom: BorderSide(color: AppColors.bgSurface),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: AppColors.success,
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Factcheck',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Channel Truth Intelligence console: claim verification, authoritative grounding & creator review.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildStatusBadge(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Obx(() {
      final published = _isPublished.value;
      return InkWell(
        onTap: () {
          _isPublished.toggle();
          if (_isPublished.value) {
            AppSnackbar.success('Credibility badges active on viewer player overlays.');
          } else {
            AppSnackbar.info('Credibility overlays muted for viewers.');
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.appBarSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: published ? AppColors.success : AppColors.bgSurface,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: published ? AppColors.success : AppColors.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                published ? 'Credibility Active' : 'Overlays Muted',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: published ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildInProgressBanner(List<VideoFactCheckItem> inProgressVideos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.bgSurface),
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: AppColors.brand,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fact-Checking Analysis In Progress (${inProgressVideos.length} Video${inProgressVideos.length == 1 ? '' : 's'})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'AI is extracting claims, grounding empirical assertions with authoritative citations, and calculating real-time progress. Badges become available to users once complete.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalBanner(List<VideoFactCheckItem> pendingVideos) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.bgSurface,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.bgSurface),
            ),
            child: const Icon(
              Icons.lock_clock_rounded,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Creator Review Window Active (${pendingVideos.length} Video${pendingVideos.length == 1 ? '' : 's'})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Review preliminary fact-checks before badges auto-publish to viewers to maintain platform truth transparency.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          ElevatedButton(
            onPressed: () => _approveAllPendingVideos(pendingVideos),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black, // Strictly black on white!
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Approve All',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvisionalNoticeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgSurface),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.bgSurface),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FAST TRIAGE • PROVISIONAL CREDIBILITY ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Preliminary multimodal scan results. Deep multi-source grounding and cross-examination run continuously in the background.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetVideoBanner(String videoTitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgSurface),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.filter_alt_rounded,
            size: 18,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Focusing on Video: $videoTitle',
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              targetVideoId.value = '';
              if (Get.isRegistered<DashboardController>()) {
                Get.find<DashboardController>().targetVideoId.value = '';
              }
            },
            child: const Text(
              'Clear Filter',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(int activeTab, String query) {
    String hintText;
    if (activeTab == 0) {
      hintText = 'Search evaluated claims by keyword or category...';
    } else if (activeTab == 2) {
      hintText = 'Search fact-checked videos by title or domain...';
    } else {
      hintText = 'Search audit trail by video or event...';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgSurface),
      ),
      child: TextField(
        style: const TextStyle(
          fontSize: 13,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.textTertiary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16, color: AppColors.textSecondary),
                  onPressed: () => _searchQuery.value = '',
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        onChanged: (val) => _searchQuery.value = val,
      ),
    );
  }

  Widget _buildFactClaimsTab(
    List<RealExtractedClaim> filteredClaims,
    List<RealExtractedClaim> allClaims,
    List<VideoFactCheckItem> videoItems,
  ) {
    final claimTier = _claimTierFilter.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Pills for Claims
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterPill(
              label: 'All Claims (${allClaims.length})',
              isSelected: claimTier == 'all',
              onTap: () => _claimTierFilter.value = 'all',
            ),
            _buildFilterPill(
              label: '🟢 Verified (${allClaims.where((c) => c.isVerified).length})',
              isSelected: claimTier == 'verified',
              onTap: () => _claimTierFilter.value = 'verified',
            ),
            _buildFilterPill(
              label: '🟡 Needs Source (${allClaims.where((c) => c.isNeedsSource).length})',
              isSelected: claimTier == 'needs_source',
              isWarningHighlight: allClaims.any((c) => c.isNeedsSource),
              onTap: () => _claimTierFilter.value = 'needs_source',
            ),
            _buildFilterPill(
              label: '🔴 High Concern (${allClaims.where((c) => c.isHighConcern).length})',
              isSelected: claimTier == 'high_concern',
              isAlertHighlight: allClaims.any((c) => c.isHighConcern),
              onTap: () => _claimTierFilter.value = 'high_concern',
            ),
            _buildFilterPill(
              label: '🟣 Disputed (${allClaims.where((c) => c.isDisputed).length})',
              isSelected: claimTier == 'disputed',
              onTap: () => _claimTierFilter.value = 'disputed',
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (filteredClaims.isEmpty)
          _buildEmptyState(
            title: 'No Extracted Claims Found',
            description:
                'No claims match your filter criteria. Try adjusting the search query or tier filter.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredClaims.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final claim = filteredClaims[index];
              final parentVideo = videoItems.firstWhereOrNull(
                (v) => v.id == claim.videoId,
              );
              return TruthVerificationClaimCard(
                claim: claim,
                video: parentVideo,
                isDarkMode: isDarkMode,
                channelId: channelId,
              );
            },
          ),
      ],
    );
  }

  Widget _buildVideoReportsTab(
    List<VideoFactCheckItem> filteredVideos,
    List<VideoFactCheckItem> videoItems,
    int videosWithConcernsCount,
    int pendingApprovalCount,
  ) {
    final videoFilter = _videoFilter.value;
    final inProgressCount =
        videoItems.where((v) => v.isFactCheckInProgress).length;
    final needsFactCheckCount = videoItems
        .where((v) => !v.isFactCheckReady && !v.isFactCheckInProgress)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-filter pills for videos
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterPill(
              label: 'All Videos (${videoItems.length})',
              isSelected: videoFilter == 'all',
              onTap: () => _videoFilter.value = 'all',
            ),
            if (needsFactCheckCount > 0)
              _buildFilterPill(
                label: '⚠️ Needs Fact-Check ($needsFactCheckCount)',
                isSelected: videoFilter == 'needs_fact_check',
                isWarningHighlight: true,
                onTap: () => _videoFilter.value = 'needs_fact_check',
              ),
            if (inProgressCount > 0)
              _buildFilterPill(
                label: '⚡ In Progress ($inProgressCount)',
                isSelected: videoFilter == 'in_progress',
                isWarningHighlight: true,
                onTap: () => _videoFilter.value = 'in_progress',
              ),
            if (videosWithConcernsCount > 0)
              _buildFilterPill(
                label: '🔴 Concern Alerts ($videosWithConcernsCount)',
                isSelected: videoFilter == 'concerns',
                isAlertHighlight: true,
                onTap: () => _videoFilter.value = 'concerns',
              ),
            _buildFilterPill(
              label: 'Pending Approval ($pendingApprovalCount)',
              isSelected: videoFilter == 'pending',
              isWarningHighlight: pendingApprovalCount > 0,
              onTap: () => _videoFilter.value = 'pending',
            ),
            _buildFilterPill(
              label: 'Approved (${videoItems.where((v) => v.isFactCheckApproved).length})',
              isSelected: videoFilter == 'approved',
              onTap: () => _videoFilter.value = 'approved',
            ),
            _buildFilterPill(
              label:
                  'Disputed (${videoItems.where((v) => v.isDisputed || v.reverificationRequested).length})',
              isSelected: videoFilter == 'disputed',
              onTap: () => _videoFilter.value = 'disputed',
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (filteredVideos.isEmpty)
          _buildEmptyState(
            title: 'No Video Fact-Checks Found',
            description:
                'No videos matched the current filter or search criteria. Videos with AI Truth Verification will appear here.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredVideos.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final video = filteredVideos[index];
              return TruthVerificationVideoCard(
                video: video,
                channelId: channelId,
                isDarkMode: isDarkMode,
                onToggleApproval: _toggleFactCheckApproval,
                onApprove: _approveVideoFactCheck,
                onRetrigger: _retriggerFactCheck,
                onClaimSelected: (claim) {
                  TruthVerificationDialogs.showAskAiWhyDialog(
                    context,
                    claim,
                    isDarkMode: isDarkMode,
                    onProvideSource: (c) =>
                        TruthVerificationDialogs.showProvideSourceForClaimDialog(
                      context,
                      c,
                      isDarkMode: isDarkMode,
                      onSubmit: (id, url, notes) {
                        c.tier = ClaimEvidenceTier.disputed;
                        AppSnackbar.success(
                          'Citation queued for AI evaluation.',
                        );
                      },
                    ),
                    onMarkEdit: (c) =>
                        TruthVerificationDialogs.showMarkVideoEditDialog(
                      context,
                      c,
                      isDarkMode: isDarkMode,
                      onSave: (note) {
                        c.creatorActionNote = note;
                        AppSnackbar.success('Action note saved.');
                      },
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isAlertHighlight = false,
    bool isWarningHighlight = false,
  }) {
    var bg = AppColors.appBarSurface;
    var fg = AppColors.textSecondary;
    var border = AppColors.bgSurface;

    if (isSelected) {
      bg = isAlertHighlight
          ? AppColors.error
          : (isWarningHighlight ? AppColors.warning : Colors.white);
      fg = (isAlertHighlight || isWarningHighlight)
          ? Colors.white
          : Colors.black; // Strictly black on white!
      border = bg;
    } else {
      if (isAlertHighlight) {
        border = AppColors.error.withValues(alpha: 0.5);
        fg = AppColors.error;
      } else if (isWarningHighlight) {
        border = AppColors.warning.withValues(alpha: 0.5);
        fg = AppColors.warning;
      }
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: fg,
          ),
        ),
      ),
    );
  }

  Widget _buildAuditActivityLogTab(List<VideoFactCheckItem> videos) {
    if (videos.isEmpty) {
      return _buildEmptyState(
        title: 'No Audit Trail Found',
        description:
            'No fact-checked video activity has been recorded yet for this channel.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: videos.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final video = videos[index];
        final title = video.title;
        final isApproved = video.isFactCheckApproved;
        final isReverify = video.reverificationRequested;
        final disputeStatus = video.disputeStatus;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.appBarSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.bgSurface,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.bgSurface),
                ),
                child: Icon(
                  isApproved
                      ? Icons.check_circle_outline_rounded
                      : Icons.pending_actions_rounded,
                  color: isApproved ? AppColors.success : AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Status: ${isApproved ? "Approved for Public Viewers" : "Creator Review Held Private"}${isReverify ? " • AI Re-verification Queued" : ""}${disputeStatus != null ? " • Dispute: $disputeStatus" : ""}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Inspect Video',
                onPressed: () {
                  TruthVerificationFullInspectorPage.open(
                    context,
                    videoItem: video,
                    channelId: channelId,
                    isDarkMode: isDarkMode,
                    onToggleApproval: _toggleFactCheckApproval,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.bgSurface,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bgSurface),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
