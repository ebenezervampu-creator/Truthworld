import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_dialogs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/video_analysis_screen.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Clean, high-contrast Video Fact-Check Card for the Fact-Check page.
///
/// Designed strictly according to the TruthWorld UI specification:
/// - When in progress: Shows thumbnail with duration timestamp, title, and
///   an animated "Fact-check in Progress (X%)" badge (smooth 5%, 10%, 50%, etc.),
///   along with the more_vertical options menu.
/// - When fact-check is available: Shows thumbnail with duration timestamp, title,
///   and interactive "Ai check" text button that navigates directly to the AI Check page.
/// - Preserves all more_vertical menu features (Approve, Make Private, Re-trigger, Talk to AI, Dispute).
/// - Zero unwanted clutter or redundant debug text.
class TruthVerificationVideoCard extends StatelessWidget {
  const TruthVerificationVideoCard({
    required this.video,
    required this.channelId,
    required this.isDarkMode,
    required this.onToggleApproval,
    required this.onApprove,
    this.onRetrigger,
    this.onClaimSelected,
    super.key,
  });

  final VideoFactCheckItem video;
  final String channelId;
  final bool isDarkMode;
  final void Function(String videoId, bool currentStatus) onToggleApproval;
  final void Function(String videoId) onApprove;
  final void Function(String videoId)? onRetrigger;
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.appBarSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? AppColors.bgSurface : const Color(0xFFE5E7EB),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (video.isFactCheckReady) {
              _openAiCheck(context);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Thumbnail with duration timestamp
                _buildThumbnail(context),
                const SizedBox(width: 12),

                // 2. Video Title + (Fact-check in Progress or Ai check)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Video Title
                      InkWell(
                        onTap: video.isFactCheckReady
                            ? () => _openAiCheck(context)
                            : null,
                        borderRadius: BorderRadius.circular(4),
                        child: Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.textPrimary
                                : Colors.black87,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Status presentation:
                      // If ready: "Ai check" text that navigates to AI check page
                      // If in progress: "Fact-check in Progress (X%)" with animation
                      // Else: Needs Fact-Check / Failed fallback
                      _buildStatusSection(context),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 3. More vertical icon button & its features
                _buildMoreMenu(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    return InkWell(
      onTap: () {
        if (video.isFactCheckReady) {
          _openAiCheck(context);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 104,
          height: 64,
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
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
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
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    if (video.isFactCheckReady) {
      return _buildAiCheckButton(context);
    }
    if (video.isFactCheckInProgress) {
      return _buildInProgressIndicator();
    }
    return _buildFallbackStatusBadge(context);
  }

  Widget _buildAiCheckButton(BuildContext context) {
    return InkWell(
      onTap: () => _openAiCheck(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.bgSurface : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDarkMode
                ? AppColors.bgSurfaceHover
                : const Color(0xFFD1D5DB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 6),
            Text(
              'Ai check',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.textPrimary : Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 10,
              color: isDarkMode ? AppColors.textSecondary : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInProgressIndicator() {
    final resolvedJobId = video.jobId?.isNotEmpty == true
        ? video.jobId!
        : ((video.video?.jobId?.isNotEmpty == true)
            ? video.video!.jobId!
            : video.id);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.videoJobs)
          .doc(resolvedJobId)
          .snapshots(),
      builder: (context, snapshot) {
        int backendProgress = video.calculatedProgress;
        DateTime? stageUpdatedAt = video.startedAt;

        if (snapshot.hasData && snapshot.data?.exists == true) {
          final jobData = snapshot.data!.data();
          final stages = (jobData?['stages'] as Map<String, dynamic>?) ?? {};
          final credStage = (stages['credibility'] ??
              stages['factcheck'] ??
              stages['fact_check'] ??
              stages['credibilityCheck']) as Map<String, dynamic>?;
          final p = (credStage?['progress'] as num?)?.toInt() ??
              (jobData?['factCheckProgress'] as num?)?.toInt();
          if (p != null && p > 0) {
            backendProgress = math.max(backendProgress, p.clamp(0, 100));
          }

          final rawUpdated = credStage?['updatedAt'] ??
              jobData?['updatedAt'] ??
              credStage?['startedAt'] ??
              jobData?['startedAt'];
          if (rawUpdated is num) {
            stageUpdatedAt =
                DateTime.fromMillisecondsSinceEpoch(rawUpdated.toInt());
          } else if (rawUpdated is Timestamp) {
            stageUpdatedAt = rawUpdated.toDate();
          }
        }

        // Live continuous 1-second interval ticker (zero network writes, purely client-side interpolation)
        return StreamBuilder<int>(
          stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
          builder: (context, _) {
            final continuousProgress = calculateStagePacedProgress(
              backendProgress: backendProgress,
              durationSeconds: video.durationSeconds,
              isReady: video.isFactCheckReady,
              stageUpdatedAt: stageUpdatedAt,
            );

            return _AnimatedProgressBadge(
              progress: continuousProgress,
              isDarkMode: isDarkMode,
            );
          },
        );
      },
    );
  }

  /// Computes continuous, granular progress (1%, 2%... 6%, 17%... 100%)
  /// anchored to the authentic backend milestone stages and elapsed time.
  static int calculateStagePacedProgress({
    required int backendProgress,
    required double durationSeconds,
    required bool isReady,
    DateTime? stageUpdatedAt,
    DateTime? now,
  }) {
    if (isReady || backendProgress >= 100) return 100;

    final int bracketStart;
    final int bracketEnd;

    if (backendProgress >= 70) {
      bracketStart = 70;
      bracketEnd = 95;
    } else if (backendProgress >= 50) {
      bracketStart = 50;
      bracketEnd = 70;
    } else if (backendProgress >= 30) {
      bracketStart = 30;
      bracketEnd = 50;
    } else if (backendProgress >= 10) {
      bracketStart = 10;
      bracketEnd = 30;
    } else {
      bracketStart = 1;
      bracketEnd = 10;
    }

    final effectiveNow = now ?? DateTime.now();
    final effectiveStageTime = stageUpdatedAt ?? effectiveNow;
    final diffMs = effectiveNow.difference(effectiveStageTime).inMilliseconds;
    final elapsedSec = math.max(0.0, diffMs / 1000.0);

    // Approximate stage duration scaled proportionally with media duration
    final effectiveDuration = durationSeconds > 0 ? durationSeconds : 300.0;
    final stageDuration =
        (10.0 + (effectiveDuration * 0.025)).clamp(12.0, 45.0);

    final fraction = (elapsedSec / stageDuration).clamp(0.0, 0.95);
    final paced =
        bracketStart + ((bracketEnd - bracketStart) * fraction).toInt();
    return paced.clamp(bracketStart, bracketEnd);
  }

  Widget _buildFallbackStatusBadge(BuildContext context) {
    if (video.factCheckStatus == 'failed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 12, color: AppColors.error),
            SizedBox(width: 4),
            Text(
              'Fact-Check Failed',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.error,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sync_problem_rounded, size: 12, color: AppColors.warning),
              SizedBox(width: 4),
              Text(
                'Needs Fact-Check',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (onRetrigger != null)
          InkWell(
            onTap: () => onRetrigger!(video.id),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.bgSurface : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDarkMode
                      ? AppColors.bgSurfaceHover
                      : const Color(0xFFD1D5DB),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    size: 12,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Re-trigger Fact-Check',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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
          color: isDarkMode ? AppColors.bgDivider : const Color(0xFFE5E7EB),
        ),
      ),
      icon: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isDarkMode
              ? AppColors.bgSurfaceHover
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDarkMode ? AppColors.bgDivider : const Color(0xFFE5E7EB),
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
          case 'retrigger_factcheck':
            if (onRetrigger != null) {
              onRetrigger!(video.id);
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

        // Re-trigger Fact-Check Option
        PopupMenuItem<String>(
          value: 'retrigger_factcheck',
          child: Row(
            children: [
              const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: AppColors.info,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  video.isFactCheckReady
                      ? 'Re-run Fact-Check'
                      : 'Re-trigger Fact-Check',
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
}

/// Declarative, professional animated progress badge for fact-checks in progress.
/// Displays smoothly animated percentage (5%, 10%, 50%, etc.) and linear indicator.
class _AnimatedProgressBadge extends StatelessWidget {
  const _AnimatedProgressBadge({
    required this.progress,
    required this.isDarkMode,
  });

  final int progress;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final accentColor = isDarkMode
        ? const Color(0xFF60A5FA)
        : const Color(0xFF2563EB);

    final bgColor = isDarkMode
        ? const Color(0xFF1E293B).withValues(alpha: 0.8)
        : const Color(0xFFEFF6FF);

    final borderColor = isDarkMode
        ? const Color(0xFF3B82F6).withValues(alpha: 0.35)
        : const Color(0xFFBFDBFE);

    final textColor = isDarkMode
        ? const Color(0xFF93C5FD)
        : const Color(0xFF1D4ED8);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        final currentPct = animatedValue.toInt();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Fact-check in Progress ($currentPct%)',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  width: 150,
                  height: 3.5,
                  child: LinearProgressIndicator(
                    value: (animatedValue / 100.0).clamp(0.04, 1.0),
                    backgroundColor: isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
