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

/// Studio Full Verification & Credibility Inspector Modal.
/// Combines the full consumer app [VideoAnalysisView] with advanced
/// Studio-exclusive creator actions and management tools.
class TruthVerificationFullInspectorModal extends StatelessWidget {
  TruthVerificationFullInspectorModal({
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
          trustScore: videoItem.truthScore > 1.0
              ? videoItem.truthScore
              : videoItem.truthScore * 100.0,
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
  }

  final VideoFactCheckItem videoItem;
  final String channelId;
  final bool isDarkMode;
  final void Function(String videoId, bool currentStatus) onToggleApproval;

  late final Video video;
  late final VideoController videoCtrl;
  late final VideoAnalysisController analysisCtrl;

  static void open(
    BuildContext context, {
    required VideoFactCheckItem videoItem,
    required String channelId,
    required bool isDarkMode,
    required void Function(String videoId, bool currentStatus) onToggleApproval,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TruthVerificationFullInspectorModal(
        videoItem: videoItem,
        channelId: channelId,
        isDarkMode: isDarkMode,
        onToggleApproval: onToggleApproval,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.92,
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDarkMode ? AppColors.bgDivider : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle & Close
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 20, right: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white24
                        : Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    size: 22,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Studio Header & Creator Management Toolbar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 76,
                    height: 48,
                    color: isDarkMode
                        ? const Color(0xFF242424)
                        : const Color(0xFFE5E7EB),
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
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
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
                              color: videoItem.isFactCheckApproved
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  videoItem.isFactCheckApproved
                                      ? Icons.check_circle_rounded
                                      : Icons.lock_clock_rounded,
                                  size: 12,
                                  color: videoItem.isFactCheckApproved
                                      ? AppColors.success
                                      : AppColors.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  videoItem.isFactCheckApproved
                                      ? 'Approved (Visible to Viewers)'
                                      : 'Creator Review (Held Private)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: videoItem.isFactCheckApproved
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
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Studio Management Actions Ribbon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  if (videoItem.isPendingApproval)
                    ElevatedButton.icon(
                      onPressed: () {
                        onToggleApproval(videoItem.id, false);
                        Navigator.pop(context);
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () {
                        onToggleApproval(
                          videoItem.id,
                          videoItem.isFactCheckApproved,
                        );
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        videoItem.isFactCheckApproved
                            ? Icons.visibility_off_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 14,
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : Colors.black87,
                      ),
                      label: Text(
                        videoItem.isFactCheckApproved
                            ? 'Make Private'
                            : 'Publish to Viewers',
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
                          horizontal: 10,
                          vertical: 7,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        TruthVerificationDialogs.showExportAuditDossierModal(
                      context,
                      videoItem,
                      channelId,
                      isDarkMode: isDarkMode,
                    ),
                    icon: Icon(
                      Icons.description_outlined,
                      size: 14,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    label: const Text('Export Dossier'),
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
                        horizontal: 10,
                        vertical: 7,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                        horizontal: 10,
                        vertical: 7,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                        horizontal: 10,
                        vertical: 7,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Divider(
            color: isDarkMode ? AppColors.bgDivider : const Color(0xFFE5E7EB),
            height: 1,
          ),

          // CONSUMER APP EMBEDDED FACT-CHECK DASHBOARD
          Expanded(
            child: VideoAnalysisView(
              video: video,
              videoCtrl: videoCtrl,
              analysisCtrl: analysisCtrl,
            ),
          ),
        ],
      ),
    );
  }
}
