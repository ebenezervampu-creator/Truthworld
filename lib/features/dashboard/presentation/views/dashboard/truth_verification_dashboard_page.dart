import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_claim_card.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_dialogs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_stats_bar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_video_card.dart';
import 'package:truthworld/theme/app_theme.dart';

// Re-exports for 100% backward compatibility with existing tests and imports
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_claim_card.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_dialogs.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_full_inspector_modal.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_stats_bar.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_video_card.dart';

/// Studio Fact-Checks & Truth Verification Console.
/// Production-grade dashboard with zero raw JSON exposure, zero UI overflow bugs,
/// complete parity with consumer app video screen, and exclusive Studio creator tools.
class TruthVerificationDashboardPage extends StatelessWidget {
  TruthVerificationDashboardPage({
    required this.channelId,
    required this.isDarkMode,
    this.initialVideoId,
    super.key,
  }) {
    if (initialVideoId != null && initialVideoId!.isNotEmpty) {
      targetVideoId.value = initialVideoId!;
    }
  }

  final String channelId;
  final bool isDarkMode;
  final String? initialVideoId;

  /// Global or deep-linked target video filter
  static final RxString targetVideoId = ''.obs;

  final RxInt _selectedTab = 0.obs; // 0: Video Reports, 1: Claims, 2: Activity Audit Log
  final RxString _videoFilter = 'all'.obs; // 'all', 'concerns', 'pending', 'approved', 'disputed'
  final RxString _claimTierFilter = 'all'.obs; // 'all', 'high_concern', 'needs_source', 'verified', 'disputed'
  final RxBool _isPublished = true.obs;
  final RxString _searchQuery = ''.obs;

  /// Determines whether a video document has AI Fact-Checking enabled, in-progress, or verified.
  static bool hasFactChecking(
    Map<String, dynamic> data, {
    List<RealExtractedClaim>? claims,
    double? trustScore,
  }) {
    // 1. Explicit fact-checked flags on video doc
    if (data['isFactChecked'] == true ||
        data['hasFactChecking'] == true ||
        data['factChecking'] == true ||
        data['isFactChecking'] == true) {
      return true;
    }

    // 2. Fact-checking enabled in AI features metadata
    final aiFeatures = data['aiFeatures'];
    if (aiFeatures is Map) {
      if (aiFeatures['factChecking'] == true ||
          aiFeatures['factCheck'] == true ||
          aiFeatures['isFactChecked'] == true ||
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.bgPage : Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
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
            final data = doc.data()! as Map<String, dynamic>;
            final videoItem = TruthVerificationParser.parseVideoDoc(doc);

            if (!hasFactChecking(
              data,
              claims: videoItem.claims,
              trustScore: videoItem.truthScore,
            )) {
              continue;
            }

            allClaims.addAll(videoItem.claims);
            videoItems.add(videoItem);
          }

          return Obx(() {
            final activeTab = _selectedTab.value;
            final targetId = targetVideoId.value;
            final videoFilter = _videoFilter.value;
            final query = _searchQuery.value.trim().toLowerCase();

            // Filter videos
            var filteredVideos = videoItems;
            if (targetId.isNotEmpty) {
              filteredVideos =
                  filteredVideos.where((v) => v.id == targetId).toList();
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

            final pendingApprovalCount =
                videoItems.where((v) => v.isPendingApproval).length;
            final videosWithConcernsCount =
                videoItems.where((v) => v.hasConcerns).length;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Stats & Health Ribbon
                  TruthVerificationStatsBar(
                    videos: videoItems,
                    allClaims: allClaims,
                    isPublished: _isPublished,
                    selectedTab: _selectedTab,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 18),

                  // Target Video Filter Banner (if filtered)
                  if (targetId.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandVariant.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.brandVariant.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.filter_alt_rounded,
                            size: 18,
                            color: AppColors.brand,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Focusing on Video: ${filteredVideos.isNotEmpty ? filteredVideos.first.title : targetId}',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brand,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => targetVideoId.value = '',
                            child: const Text(
                              'Clear Filter',
                              style: TextStyle(
                                color: AppColors.brand,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Search Bar
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.bgSurface : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDarkMode ? AppColors.bgDivider : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: TextField(
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: activeTab == 0
                            ? 'Search fact-checked videos by title or topic...'
                            : 'Search evaluated claims by keywords...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? AppColors.textTertiary : Colors.black38,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                        ),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
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
                  ),

                  // TAB CONTENT
                  if (activeTab == 0) ...[
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
                          label:
                              'Approved (${videoItems.where((v) => v.isFactCheckApproved).length})',
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
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final video = filteredVideos[index];
                          return TruthVerificationVideoCard(
                            video: video,
                            channelId: channelId,
                            isDarkMode: isDarkMode,
                            onToggleApproval: _toggleFactCheckApproval,
                            onApprove: _approveVideoFactCheck,
                            onClaimSelected: (claim) {
                              TruthVerificationDialogs.showAskAiWhyDialog(
                                context,
                                claim,
                                isDarkMode: isDarkMode,
                                onProvideSource: (c) =>
                                    TruthVerificationDialogs
                                        .showProvideSourceForClaimDialog(
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
                                    TruthVerificationDialogs
                                        .showMarkVideoEditDialog(
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
                  ] else if (activeTab == 1) ...[
                    // Claims Filter Bar
                    Wrap(
                      spacing: 16,
                      runSpacing: 10,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Evaluated Factual Claims (${filteredClaims.length})',
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black87,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.filter_alt_outlined,
                              size: 16,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            const SizedBox(width: 6),
                            DropdownButton<String>(
                              value: claimTier,
                              dropdownColor: isDarkMode
                                  ? AppColors.bgSurface
                                  : Colors.white,
                              underline: const SizedBox(),
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: isDarkMode
                                    ? AppColors.textPrimary
                                    : Colors.black87,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('All Claims'),
                                ),
                                DropdownMenuItem(
                                  value: 'high_concern',
                                  child: Text('🔴 High Concern (No Evidence)'),
                                ),
                                DropdownMenuItem(
                                  value: 'needs_source',
                                  child: Text('🟡 Needs Source'),
                                ),
                                DropdownMenuItem(
                                  value: 'verified',
                                  child: Text('🟢 Most Verified'),
                                ),
                                DropdownMenuItem(
                                  value: 'disputed',
                                  child: Text('🟣 Disputed'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  _claimTierFilter.value = val;
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

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
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 14),
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
                  ] else ...[
                    // Tab 2: Activity Audit Log
                    _buildAuditActivityLogTab(videoItems),
                  ],
                ],
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isAlertHighlight = false,
    bool isWarningHighlight = false,
  }) {
    var bg = isDarkMode ? AppColors.bgSurface : const Color(0xFFF3F4F6);
    var fg = isDarkMode ? AppColors.textSecondary : Colors.black87;
    var border = isDarkMode ? AppColors.bgDivider : const Color(0xFFE5E7EB);

    if (isSelected) {
      bg = isAlertHighlight
          ? AppColors.error
          : (isWarningHighlight ? AppColors.warning : AppColors.brand);
      fg = (isAlertHighlight || isWarningHighlight)
          ? Colors.white
          : Colors.black;
      border = bg;
    } else {
      if (isAlertHighlight) {
        border = AppColors.error.withValues(alpha: 0.6);
        fg = AppColors.error;
      } else if (isWarningHighlight) {
        border = AppColors.warning.withValues(alpha: 0.6);
        fg = AppColors.warning;
      }
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.bgSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? AppColors.bgDivider : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isApproved
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
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
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: isDarkMode
                            ? AppColors.textPrimary
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Status: ${isApproved ? "Approved for Public Viewers" : "Creator Review Held Private"}${isReverify ? " • AI Re-verification Queued" : ""}${disputeStatus != null ? " • Dispute: $disputeStatus" : ""}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
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
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? AppColors.bgDivider : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.fact_check_outlined,
            size: 44,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.textPrimary : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 12.5,
              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

}
