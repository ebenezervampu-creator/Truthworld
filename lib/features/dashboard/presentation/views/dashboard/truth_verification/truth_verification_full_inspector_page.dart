import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_dialogs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/truth_verification/truth_verification_models.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_controller.dart';
import 'package:truthworld/features/video/presentation/widgets/analysis/video_analysis_view.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Studio Full Verification & Credibility Inspector Dedicated Page.
/// Opens as a first-class route containing an app bar, creator management tools,
/// and the complete [VideoAnalysisView] credibility dashboard.
class TruthVerificationFullInspectorPage extends StatelessWidget {
  TruthVerificationFullInspectorPage({
    required this.videoItem,
    required this.channelId,
    required this.isDarkMode,
    required this.onToggleApproval,
    super.key,
  }) {
    final effectiveVideo = videoItem.video ??
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

    final tag = effectiveVideo.id;
    if (Get.isRegistered<VideoController>(tag: tag)) {
      videoCtrl = Get.find<VideoController>(tag: tag);
    } else {
      videoCtrl = Get.put(VideoController(), tag: tag);
    }
    videoCtrl.rxVideo.value = effectiveVideo;

    if (Get.isRegistered<VideoAnalysisController>(tag: tag)) {
      analysisCtrl = Get.find<VideoAnalysisController>(tag: tag);
    } else {
      analysisCtrl = Get.put(VideoAnalysisController(), tag: tag);
    }

    if (effectiveVideo.factCheckUrl.isNotEmpty &&
        videoCtrl.factCheckData.isEmpty &&
        !videoCtrl.hasAttemptedFactCheck.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (videoCtrl.factCheckData.isEmpty &&
            !videoCtrl.isLoadingFactCheck.value) {
          videoCtrl.loadFactCheckData(effectiveVideo.factCheckUrl);
        }
      });
    }

    video = effectiveVideo;
    rxIsApproved.value = videoItem.isFactCheckApproved;
    rxIsPendingApproval.value = videoItem.isPendingApproval;
  }

  final VideoFactCheckItem videoItem;
  final String channelId;
  final bool isDarkMode;
  final void Function(String videoId, bool currentStatus) onToggleApproval;

  late final Video video;
  late final VideoController videoCtrl;
  late final VideoAnalysisController analysisCtrl;

  final RxBool rxIsApproved = false.obs;
  final RxBool rxIsPendingApproval = false.obs;

  /// Opens the full verification inspection report on a separate page.
  static Future<void> open(
    BuildContext context, {
    required VideoFactCheckItem videoItem,
    required String channelId,
    required bool isDarkMode,
    required void Function(String videoId, bool currentStatus) onToggleApproval,
  }) async {
    await Get.to<void>(
      () => TruthVerificationFullInspectorPage(
        videoItem: videoItem,
        channelId: channelId,
        isDarkMode: isDarkMode,
        onToggleApproval: onToggleApproval,
      ),
      transition: Transition.rightToLeftWithFade,
      curve: Curves.easeOutCubic,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.bgPage : AppColors.textPrimary,
      appBar: AppBar(
        backgroundColor: isDarkMode ? AppColors.bgSurface : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDarkMode ? AppColors.textPrimary : Colors.black87,
          ),
          tooltip: 'Back to Fact-Checks',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Get.back();
            }
          },
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Fact-Check & Verification Report',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.textPrimary : Colors.black87,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              video.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 11.5,
                color: isDarkMode ? AppColors.textSecondary : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          Obx(() {
            final isApproved = rxIsApproved.value;
            final isPending = rxIsPendingApproval.value;
            final color = isApproved
                ? AppColors.success
                : (isPending ? AppColors.warning : AppColors.info);
            final label = isApproved
                ? 'Approved'
                : (isPending ? 'Pending Review' : 'Private');
            final icon = isApproved
                ? Icons.check_circle_rounded
                : (isPending
                    ? Icons.lock_clock_rounded
                    : Icons.visibility_off_rounded);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 12, color: color),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDarkMode ? AppColors.bgDivider : AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStudioHeader(context),
                _buildStudioActionsRibbon(context),
                Divider(
                  color: isDarkMode
                      ? AppColors.bgDivider
                      : AppColors.textPrimary,
                  height: 1,
                ),
                Expanded(
                  child: VideoAnalysisView(
                    video: video,
                    videoCtrl: videoCtrl,
                    analysisCtrl: analysisCtrl,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudioHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: isDarkMode ? AppColors.bgSurface : Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 80,
              height: 50,
              color: isDarkMode
                  ? AppColors.bgSurface
                  : AppColors.textPrimary,
              child: video.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      video.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Icon(
                        Icons.video_library_rounded,
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : Colors.black54,
                      ),
                    )
                  : Icon(
                      Icons.video_library_rounded,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : Colors.black54,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
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
                  ),
                ),
                const SizedBox(height: 6),
                Obx(() {
                  final isApproved = rxIsApproved.value;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isApproved
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isApproved
                                  ? Icons.check_circle_rounded
                                  : Icons.lock_clock_rounded,
                              size: 12,
                              color: isApproved
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isApproved
                                  ? 'Approved (Visible to Viewers)'
                                  : 'Creator Review (Held Private)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isApproved
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '• ${videoItem.claims.length} assertions',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : Colors.black54,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudioActionsRibbon(BuildContext context) {
    return Container(
      color: isDarkMode ? AppColors.bgSurface : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            Obx(() {
              final isApproved = rxIsApproved.value;
              final isPending = rxIsPendingApproval.value;

              if (isPending) {
                return ElevatedButton.icon(
                  onPressed: () {
                    rxIsApproved.value = true;
                    rxIsPendingApproval.value = false;
                    onToggleApproval(videoItem.id, false);
                  },
                  icon: const Icon(
                    Icons.check_circle_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                  label: const Text('Approve for Viewers'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }

              return OutlinedButton.icon(
                onPressed: () {
                  final currentStatus = rxIsApproved.value;
                  rxIsApproved.value = !currentStatus;
                  onToggleApproval(videoItem.id, currentStatus);
                },
                icon: Icon(
                  isApproved
                      ? Icons.visibility_off_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 14,
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : Colors.black87,
                ),
                label: Text(
                  isApproved ? 'Make Private' : 'Publish to Viewers',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDarkMode
                      ? AppColors.textPrimary
                      : Colors.black87,
                  side: BorderSide(
                    color: isDarkMode
                        ? AppColors.bgDivider
                        : const Color(0xFFD1D5DB),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              );
            }),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => TruthVerificationDialogs.showTalkToAiDialog(
                context,
                videoItem,
                isDarkMode: isDarkMode,
                onSubmit: (commentary, sources) async {
                  AppSnackbar.success(
                    'Additional sources queued for AI evaluation.',
                  );
                },
              ),
              icon: Icon(
                Icons.psychology_rounded,
                size: 14,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              label: const Text('Talk to AI (Add Sources)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDarkMode
                    ? AppColors.textPrimary
                    : Colors.black87,
                side: BorderSide(
                  color: isDarkMode
                      ? AppColors.bgDivider
                      : const Color(0xFFD1D5DB),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => TruthVerificationDialogs.showDisputeDialog(
                context,
                videoItem,
                isDarkMode: isDarkMode,
                onConfirmDispute: (reason, url) async {
                  AppSnackbar.success(
                    'Dispute submitted to truth consensus review.',
                  );
                },
              ),
              icon: const Icon(
                Icons.gavel_rounded,
                size: 14,
                color: AppColors.warning,
              ),
              label: const Text('Dispute'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
