import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Production-grade percentage progress bar and real-time user availability
/// tracker for Fact-Check enabled videos in Creator Studio.
///
/// Gives channels 100% real-time transparency into:
/// - Exact AI verification progress (real percentage: 0% - 100%).
/// - Stage explanation (media ingestion, claim extraction, IFCN grounding, synthesis).
/// - User availability status (Available to Users, Pending Creator Approval, Held Private).
/// - Instant one-tap publishing for creator review approval.
///
/// Follows TruthWorld strict accessibility and zero white-on-white policies.
class TruthVerificationProgressBar extends StatelessWidget {
  const TruthVerificationProgressBar({
    required this.video,
    required this.isDarkMode,
    this.onApprove,
    this.onToggleApproval,
    this.onRetrigger,
    super.key,
  });

  final VideoFactCheckItem video;
  final bool isDarkMode;
  final void Function(String videoId)? onApprove;
  final void Function(String videoId, bool currentStatus)? onToggleApproval;
  final void Function(String videoId)? onRetrigger;

  static String getStageDescription(int progress) {
    if (progress >= 100) {
      return 'AI truth verification complete. Epistemic evidence grounded.';
    }
    if (progress >= 85) {
      return 'Step 5/5: Synthesizing truth report & credibility badges...';
    }
    if (progress >= 65) {
      return 'Step 4/5: Cross-referencing authoritative citations & IFCN consensus...';
    }
    if (progress >= 40) {
      return 'Step 3/5: Querying knowledge registries & fact registries...';
    }
    if (progress >= 15) {
      return 'Step 2/5: Extracting claims & empirical assertions from audio/media...';
    }
    return 'Step 1/5: Initializing media streams & resolving audio track...';
  }

  @override
  Widget build(BuildContext context) {
    // If the video fact-check is already ready (100% complete) or NOT actively in progress,
    // render the card content directly without opening real-time Firestore listeners.
    if (video.isFactCheckReady || !video.isFactCheckInProgress) {
      return _buildCardContent(
        context,
        progress: video.calculatedProgress,
        status: video.factCheckStatus ??
            (video.isFactCheckReady ? 'completed' : 'idle'),
        isReady: video.isFactCheckReady,
        jobStartedAt: video.startedAt,
      );
    }

    // Otherwise, listen in real-time to the video pipeline job (video_jobs/{jobId})
    // with automatic fallback to video document metadata.
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
      builder: (context, jobSnapshot) {
        final jobData = jobSnapshot.data?.data();
        final stages = (jobData?['stages'] as Map<String, dynamic>?) ?? {};
        final credStage = (stages['credibility'] ??
            stages['factcheck'] ??
            stages['fact_check'] ??
            stages['credibilityCheck']) as Map<String, dynamic>?;

        var status = (credStage?['status'] as String?)?.toLowerCase() ??
            (jobData?['factCheckStatus'] as String?)?.toLowerCase() ??
            video.factCheckStatus?.toLowerCase() ??
            'running';

        var progress = (credStage?['progress'] as num?)?.toInt() ??
            (jobData?['factCheckProgress'] as num?)?.toInt() ??
            video.factCheckProgress ??
            video.calculatedProgress;

        if (status == 'completed' || progress >= 100) {
          progress = 100;
          status = 'completed';
        }

        final isReady = status == 'completed' || progress >= 100;

        DateTime? jobStartedAt;
        final rawJobStarted = credStage?['startedAt'] ?? jobData?['startedAt'];
        if (rawJobStarted is num) {
          jobStartedAt = DateTime.fromMillisecondsSinceEpoch(rawJobStarted.toInt());
        } else if (rawJobStarted is Timestamp) {
          jobStartedAt = rawJobStarted.toDate();
        }

        return _buildCardContent(
          context,
          progress: progress.clamp(0, 100),
          status: status,
          isReady: isReady,
          jobStartedAt: jobStartedAt,
        );
      },
    );
  }

  Widget _buildCardContent(
    BuildContext context, {
    required int progress,
    required String status,
    required bool isReady,
    DateTime? jobStartedAt,
  }) {
    final isFailed = status == 'failed';
    final isAvailable = isReady && video.isFactCheckApproved && !video.isPendingApproval;
    final isPendingReview = isReady && video.isPendingApproval;
    final isHeldPrivate = isReady && !video.isFactCheckApproved && !video.isPendingApproval;

    final etaText = video.calculateEstimatedTimeRemaining(
      currentProgress: progress,
      liveStartedAt: jobStartedAt,
    );

    // Progress bar theme colors
    final Color progressColor;
    final Color iconColor;
    final IconData statusIcon;

    if (isReady) {
      if (isAvailable) {
        progressColor = AppColors.success;
        iconColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
      } else if (isPendingReview) {
        progressColor = AppColors.warning;
        iconColor = AppColors.warning;
        statusIcon = Icons.lock_clock_rounded;
      } else {
        progressColor = isDarkMode ? Colors.white70 : Colors.black54;
        iconColor = isDarkMode ? Colors.white70 : Colors.black54;
        statusIcon = Icons.visibility_off_rounded;
      }
    } else if (isFailed) {
      progressColor = AppColors.error;
      iconColor = AppColors.error;
      statusIcon = Icons.error_outline_rounded;
    } else {
      progressColor = isDarkMode ? Colors.white : AppColors.brand;
      iconColor = isDarkMode ? Colors.white : AppColors.brand;
      statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isReady
              ? (isAvailable
                  ? AppColors.success.withValues(alpha: 0.3)
                  : (isPendingReview
                      ? AppColors.warning.withValues(alpha: 0.3)
                      : AppColors.bgSurface))
              : (isFailed
                  ? AppColors.error.withValues(alpha: 0.3)
                  : AppColors.brand.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Progress title with percentage + User Availability Badge (Wrap for zero overflow on mobile)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 16, color: iconColor),
                  const SizedBox(width: 8),
                  Text(
                    isReady
                        ? 'Factcheck Ready: 100%'
                        : (isFailed
                            ? 'Factcheck Failed'
                            : 'Factcheck In Progress: $progress%'),
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (!isReady && !isFailed) _buildEtaChip(etaText),
                  _buildAvailabilityChip(
                    isReady: isReady,
                    isAvailable: isAvailable,
                    isPendingReview: isPendingReview,
                    isHeldPrivate: isHeldPrivate,
                    isFailed: isFailed,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. High-Contrast Linear Percentage Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress / 100.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    backgroundColor: AppColors.bgSurfaceHover,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 3. Subtitle / Stage Context & Quick Action Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  isReady
                      ? (isAvailable
                          ? 'Available to Users: Credibility badges & verified claims are live on player.'
                          : (isPendingReview
                              ? 'Ready (100%): In Creator Review — approve to make visible to users.'
                              : 'Ready (100%): Held Private — hidden from viewer overlays.'))
                      : (isFailed
                          ? 'Verification encountered an error. Please retry from more options.'
                          : '${getStageDescription(progress)} • Est. $etaText (Not yet available to users)'),
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 11,
                    color: isDarkMode ? AppColors.textSecondary : Colors.black54,
                  ),
                ),
              ),
              if (!isReady && !video.isFactCheckInProgress && onRetrigger != null) ...[
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => onRetrigger!(video.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black, // Strictly black on white!
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Re-trigger Fact-Check',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Strictly black on white!
                    ),
                  ),
                ),
              ] else if (isPendingReview && onApprove != null) ...[
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => onApprove!(video.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black, // Strictly black on white!
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Approve for Users',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Strictly black on white!
                    ),
                  ),
                ),
              ] else if (isHeldPrivate && onToggleApproval != null) ...[
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => onToggleApproval!(video.id, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black, // Strictly black on white!
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Publish to Users',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Strictly black on white!
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEtaChip(String etaText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDarkMode ? AppColors.bgSurfaceHover : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 11,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
          const SizedBox(width: 4),
          Text(
            etaText,
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityChip({
    required bool isReady,
    required bool isAvailable,
    required bool isPendingReview,
    required bool isHeldPrivate,
    required bool isFailed,
  }) {
    final Color badgeBg;
    final Color badgeBorder;
    final Color badgeText;
    final IconData badgeIcon;
    final String badgeLabel;

    if (isReady) {
      if (isAvailable) {
        badgeBg = AppColors.success.withValues(alpha: 0.15);
        badgeBorder = AppColors.success.withValues(alpha: 0.4);
        badgeText = AppColors.success;
        badgeIcon = Icons.public_rounded;
        badgeLabel = 'Available to Users';
      } else if (isPendingReview) {
        badgeBg = AppColors.warning.withValues(alpha: 0.15);
        badgeBorder = AppColors.warning.withValues(alpha: 0.4);
        badgeText = AppColors.warning;
        badgeIcon = Icons.lock_clock_rounded;
        badgeLabel = 'Pending Approval (Private)';
      } else {
        badgeBg = Colors.grey.withValues(alpha: 0.15);
        badgeBorder = Colors.grey.withValues(alpha: 0.3);
        badgeText = isDarkMode ? AppColors.textSecondary : Colors.black54;
        badgeIcon = Icons.visibility_off_rounded;
        badgeLabel = 'Held Private';
      }
    } else if (isFailed) {
      badgeBg = AppColors.error.withValues(alpha: 0.15);
      badgeBorder = AppColors.error.withValues(alpha: 0.4);
      badgeText = AppColors.error;
      badgeIcon = Icons.cancel_outlined;
      badgeLabel = 'Unavailable';
    } else {
      badgeBg = AppColors.info.withValues(alpha: 0.15);
      badgeBorder = AppColors.info.withValues(alpha: 0.4);
      badgeText = AppColors.info;
      badgeIcon = Icons.access_time_rounded;
      badgeLabel = 'Not Yet Available to Users';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 12, color: badgeText),
          const SizedBox(width: 4),
          Text(
            badgeLabel,
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: badgeText,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
