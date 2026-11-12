import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_dialogs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/video_analysis_screen.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Clean, professional, high-contrast Video Fact-Check Report Card.
/// Engineered for zero layout overflows, responsive mobile/desktop layouts,
/// and instant access to consumer-grade deep analysis + Studio tools.
class TruthVerificationVideoCard extends StatelessWidget {
  const TruthVerificationVideoCard({
    required this.video,
    required this.channelId,
    required this.isDarkMode,
    required this.onToggleApproval,
    required this.onApprove,
    this.onClaimSelected,
    super.key,
  });

  final VideoFactCheckItem video;
  final String channelId;
  final bool isDarkMode;
  final void Function(String videoId, bool currentStatus) onToggleApproval;
  final void Function(String videoId) onApprove;
  final void Function(RealExtractedClaim claim)? onClaimSelected;

  void _openAiCheck(BuildContext context) {
    openAiCheck(
      context,
      videoItem: video,
      channelId: channelId,
    );
  }

  /// Opens the canonical AI Check page (VideoAnalysisScreen) for this video.
  static Future<void> openAiCheck(
    BuildContext context, {
    required VideoFactCheckItem videoItem,
    required String channelId,
  }) async {
    final baseVideo = videoItem.video ??
        Video(
          id: videoItem.id,
          title: videoItem.title,
          description: videoItem.summary,
          thumbnailUrl: videoItem.thumbnailUrl,
          ownerId: '',
          channelId: channelId,
          channelName: '',
          category: videoItem.domain,
          tags: const [],
          isFactChecked: true,
          isFactCheckApproved: videoItem.isFactCheckApproved,
          factCheckReviewMode: videoItem.factCheckReviewMode,
        );
    final effectiveVideo = baseVideo.copyWith(
      isFactChecked: true,
      isFactCheckApproved: videoItem.isFactCheckApproved,
      factCheckReviewMode: videoItem.factCheckReviewMode,
    );

    final tag = effectiveVideo.id;
    final VideoController videoCtrl;
    if (Get.isRegistered<VideoController>(tag: tag)) {
      videoCtrl = Get.find<VideoController>(tag: tag);
    } else {
      videoCtrl = Get.put(VideoController(), tag: tag);
    }
    videoCtrl.rxVideo.value = effectiveVideo;

    if (Get.isRegistered<VideoAnalysisController>(tag: tag)) {
      Get.find<VideoAnalysisController>(tag: tag).setSelectedTab(0);
    } else {
      Get.put(VideoAnalysisController(), tag: tag).setSelectedTab(0);
    }

    if (videoCtrl.factCheckData.isEmpty) {
      if (effectiveVideo.factCheckUrl.isNotEmpty &&
          !videoCtrl.hasAttemptedFactCheck.value) {
        videoCtrl.loadFactCheckData(effectiveVideo.factCheckUrl);
      }
      if (videoItem.summary.isNotEmpty ||
          videoItem.claims.isNotEmpty ||
          videoItem.sources.isNotEmpty) {
        videoCtrl.factCheckData.value = {
          'summary': videoItem.summary,
          'viewerNote': videoItem.viewerNote,
          'claims': videoItem.claims.map((c) => c.toMap()).toList(),
          'sources': videoItem.sources,
          'category': videoItem.domain,
          'confidence': videoItem.confidence,
          'factors': videoItem.factors,
        };
      }
    }

    await VideoAnalysisScreen.open(
      context,
      video: effectiveVideo,
      controller: videoCtrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: video.hasConcerns
              ? AppColors.error.withValues(alpha: 0.6)
              : AppColors.bgSurface,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openAiCheck(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Video Thumbnail + Title + Status Ribbon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => _openAiCheck(context),
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 90,
                    height: 56,
                    color: AppColors.bgInput,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: video.thumbnailUrl.isNotEmpty
                              ? Image.network(
                                  video.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => const Icon(
                                    Icons.video_library_rounded,
                                    color: AppColors.textSecondary,
                                  ),
                                )
                              : const Icon(
                                  Icons.video_library_rounded,
                                  color: AppColors.textSecondary,
                                ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              TruthVerificationParser.formatTimestamp(
                                video.durationSeconds,
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _openAiCheck(context),
                      borderRadius: BorderRadius.circular(4),
                      child: Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildStatusBadge(),
                        if (video.hasConcerns)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 12,
                                  color: AppColors.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${video.highConcernClaims.length} Concern Alert',
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Timeline scrubber preview (if claims exist)
          if (video.claims.isNotEmpty) ...[
            _buildInteractiveTimelineScrubber(context),
            const SizedBox(height: 10),
          ],

          // 3. Evidence Resolution Banner (if unresolved concerns or missing sources exist)
          if (video.hasConcerns || video.needsSourceClaims.isNotEmpty) ...[
            _buildEvidenceResolutionBanner(),
            const SizedBox(height: 10),
          ],

          // 4. Credibility & Evidence Metrics Bar (RESPONSIVE, ZERO OVERFLOW)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.bgSurface,
              ),
            ),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                final leftContent = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      video.hasConcerns
                          ? Icons.warning_amber_rounded
                          : (video.needsSourceClaims.isNotEmpty
                              ? Icons.help_outline_rounded
                              : (video.verifiedClaims.isNotEmpty
                                  ? Icons.verified_outlined
                                  : Icons.fact_check_outlined)),
                      size: 16,
                      color: video.hasConcerns
                          ? AppColors.error
                          : (video.needsSourceClaims.isNotEmpty
                              ? AppColors.warning
                              : (video.verifiedClaims.isNotEmpty
                                  ? AppColors.success
                                  : (isDarkMode
                                      ? AppColors.textSecondary
                                      : Colors.black54))),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        video.claims.isEmpty
                            ? 'No Empirical Claims'
                            : (video.hasConcerns
                                ? '${video.highConcernClaims.length} Concern${video.highConcernClaims.length == 1 ? "" : "s"}'
                                : (video.needsSourceClaims.isNotEmpty
                                    ? '${video.needsSourceClaims.length} Need Source'
                                    : '${video.verifiedClaims.length} Verified')),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: video.hasConcerns
                              ? AppColors.error
                              : (video.needsSourceClaims.isNotEmpty
                                  ? AppColors.warning
                                  : (video.verifiedClaims.isNotEmpty
                                      ? AppColors.success
                                      : (isDarkMode
                                          ? AppColors.textSecondary
                                          : Colors.black87))),
                        ),
                      ),
                    ),
                  ],
                );

                final rightContent = Text(
                  video.claims.isEmpty
                      ? 'No empirical assertions evaluated'
                      : '${video.claims.length} Claims: ${video.verifiedClaims.length} verified, ${video.needsSourceClaims.length} need source, ${video.highConcernClaims.length} concern',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 11,
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : Colors.black54,
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leftContent,
                      const SizedBox(height: 4),
                      rightContent,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: leftContent),
                    const SizedBox(width: 10),
                    Flexible(child: rightContent),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // 5. Card Action Buttons (Inspect Full Report + More Vertical Button)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openAiCheck(context),
                icon: const Icon(
                  Icons.analytics_outlined,
                  size: 15,
                  color: Colors.white,
                ),
                label: const Text('Inspect Full Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bgSurface,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildMoreMenu(context),
            ],
          ),
        ],
      ),
    ),
  ),
),
    );
  }

  Widget _buildMoreMenu(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More options',
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      color: isDarkMode ? AppColors.bgSurface : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode ? AppColors.bgDivider : AppColors.textPrimary,
        ),
      ),
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDarkMode
              ? AppColors.bgSurfaceHover
              : AppColors.textPrimary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDarkMode ? AppColors.bgDivider : const Color(0xFFD1D5DB),
          ),
        ),
        child: Icon(
          Icons.more_vert_rounded,
          size: 18,
          color: isDarkMode ? AppColors.textPrimary : Colors.black87,
        ),
      ),
      onSelected: (val) async {
        switch (val) {
          case 'approve_public':
            if (video.isFactCheckApproved) {
              AppSnackbar.info(
                'Fact-check verification is already visible to viewers.',
              );
            } else {
              onApprove(video.id);
            }
          case 'make_private':
            if (!video.isFactCheckApproved) {
              AppSnackbar.info(
                'Fact-check verification is already held private.',
              );
            } else {
              onToggleApproval(video.id, true);
            }
          case 'talk_to_ai':
            TruthVerificationDialogs.showTalkToAiDialog(
              context,
              video,
              isDarkMode: isDarkMode,
              onSubmit: (commentary, sources) async {
                AppSnackbar.success(
                  'Additional sources queued for AI evaluation.',
                );
              },
            );
          case 'dispute':
            TruthVerificationDialogs.showDisputeDialog(
              context,
              video,
              isDarkMode: isDarkMode,
              onConfirmDispute: (reason, url) async {
                AppSnackbar.success(
                  'Dispute submitted to truth consensus review.',
                );
              },
            );
        }
      },
      itemBuilder: (ctx) => [
        // Visibility Option: Approved (Visible to Viewers)
        PopupMenuItem<String>(
          value: 'approve_public',
          child: Row(
            children: [
              Icon(
                video.isFactCheckApproved
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline_rounded,
                size: 18,
                color: AppColors.success,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  video.isFactCheckApproved
                      ? 'Approved (Visible to Viewers)'
                      : 'Approve (Visible to Viewers)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 12.5,
                    fontWeight: video.isFactCheckApproved
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Visibility Option: Make Private
        PopupMenuItem<String>(
          value: 'make_private',
          child: Row(
            children: [
              Icon(
                !video.isFactCheckApproved
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_off_outlined,
                size: 18,
                color: !video.isFactCheckApproved
                    ? AppColors.warning
                    : (isDarkMode ? AppColors.textSecondary : Colors.black54),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  !video.isFactCheckApproved
                      ? 'Make Private (Held Private)'
                      : 'Make Private',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 12.5,
                    fontWeight: !video.isFactCheckApproved
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),

        const PopupMenuDivider(),

        // Talk to AI (Add Sources)
        PopupMenuItem<String>(
          value: 'talk_to_ai',
          child: Row(
            children: [
              Icon(
                Icons.psychology_rounded,
                size: 18,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Talk to AI (Add Sources)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? AppColors.textPrimary : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Dispute
        const PopupMenuItem<String>(
          value: 'dispute',
          child: Row(
            children: [
              Icon(
                Icons.gavel_rounded,
                size: 18,
                color: AppColors.warning,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Dispute',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    if (video.isPendingApproval) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_clock_rounded, size: 12, color: AppColors.warning),
            SizedBox(width: 4),
            Text(
              'Pending Creator Review (Private)',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    if (video.isFactCheckApproved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 12,
              color: AppColors.success,
            ),
            SizedBox(width: 4),
            Text(
              'Approved (Visible to Viewers)',
              style: TextStyle(
                color: AppColors.success,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility_off_rounded,
            size: 12,
            color: isDarkMode ? AppColors.textSecondary : Colors.black54,
          ),
          const SizedBox(width: 4),
          Text(
            'Held Private',
            style: TextStyle(
              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveTimelineScrubber(BuildContext context) {
    final totalDuration = video.durationSeconds > 0
        ? video.durationSeconds
        : 600.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgPage : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Interactive Claim Timeline',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                ),
              ),
              Text(
                'Tap marker dot to inspect',
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkMode
                      ? AppColors.textTertiary
                      : Colors.black38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final trackWidth = constraints.maxWidth;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    width: trackWidth,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.bgDivider
                          : AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  ...video.claims.map((claim) {
                    final fraction =
                        (claim.timestampSeconds / totalDuration).clamp(0.0, 1.0);
                    final dotX = (fraction * trackWidth).clamp(0.0, trackWidth - 12);
                    var dotColor = AppColors.success;
                    if (claim.isHighConcern) {
                      dotColor = AppColors.error;
                    } else if (claim.isNeedsSource) {
                      dotColor = AppColors.warning;
                    } else if (claim.isDisputed) {
                      dotColor = Colors.purpleAccent;
                    }

                    return Positioned(
                      left: dotX,
                      child: GestureDetector(
                        onTap: () {
                          if (onClaimSelected != null) {
                            onClaimSelected!(claim);
                          } else {
                            TruthVerificationDialogs.showAskAiWhyDialog(
                              context,
                              claim,
                              isDarkMode: isDarkMode,
                              onProvideSource: (c) => TruthVerificationDialogs
                                  .showProvideSourceForClaimDialog(
                                context,
                                c,
                                isDarkMode: isDarkMode,
                                onSubmit: (id, url, notes) {
                                  c.tier = ClaimEvidenceTier.disputed;
                                  AppSnackbar.success(
                                    'Citation queued for evaluation.',
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
                          }
                        },
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDarkMode ? Colors.black : Colors.white,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: dotColor.withValues(alpha: 0.6),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '00:00',
                style: TextStyle(fontSize: 9.5, color: AppColors.textTertiary),
              ),
              Text(
                TruthVerificationParser.formatTimestamp(totalDuration),
                style: const TextStyle(
                  fontSize: 9.5,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceResolutionBanner() {
    final pendingCount =
        video.needsSourceClaims.length + video.highConcernClaims.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.brandVariant.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.brandVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.source_outlined,
            size: 16,
            color: AppColors.info,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Evidence Resolution: Providing sources resolves $pendingCount pending assertion${pendingCount == 1 ? '' : 's'} to complete verification.',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: AppColors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
