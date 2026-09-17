import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Row showing moderation or validation outcome (e.g. Approved, Flagged, Pending)
class CreateContentValidationSummaryRow extends StatelessWidget {
  const CreateContentValidationSummaryRow({
    required this.label,
    required this.status,
    required this.reason,
    required this.isDark,
    super.key,
  });

  final String label;
  final String status;
  final String reason;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final approved = status == 'APPROVED';
    final rejected = status == 'REJECTED';
    final pending = status == 'PENDING';

    final color = approved
        ? const Color(0xFF10B981)
        : rejected
            ? const Color(0xFFEF4444)
            : const Color(0xFF3B82F6);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            approved
                ? Icons.check_circle_rounded
                : rejected
                    ? Icons.error_outline_rounded
                    : Icons.hourglass_top_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label validation',
                  style: context.themeTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimary
                        : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason.isNotEmpty
                      ? reason
                      : (pending
                          ? 'Validation is in progress...'
                          : 'No validation details available.'),
                  style: context.themeTypography.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.textPrimary.withValues(alpha: 0.75)
                        : const Color(0xFF4B5563),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Verification checklist verifying video upload, thumbnail approval, and title length
class CreateContentPublishChecklist extends StatelessWidget {
  const CreateContentPublishChecklist({
    required this.uploadController,
    required this.titleController,
    required this.isDark,
    super.key,
  });

  final UploadController uploadController;
  final TextEditingController titleController;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isUploading = uploadController.isUploading.value;
      final videoProgress = uploadController.videoUploadProgress.value;
      final videoUrl = uploadController.videoUrl.value;

      final checks = [
        (
          isUploading
              ? 'Uploading video... (${(videoProgress * 100).toInt()}%)'
              : (videoUrl.isNotEmpty
                  ? 'Video uploaded'
                  : 'Video not uploaded'),
          videoUrl.isNotEmpty,
          Icons.videocam_rounded,
          isUploading,
        ),
        (
          uploadController.finalstatus.value == 'APPROVED'
              ? 'Thumbnail approved'
              : (uploadController.finalstatus.value == 'REJECTED'
                  ? 'Thumbnail rejected'
                  : (uploadController.finalstatus.value == 'FLAGGED'
                      ? 'Thumbnail pending admin review...'
                      : (uploadController.finalstatus.value == 'PENDING'
                          ? 'Verifying thumbnail...'
                          : 'Thumbnail added'))),
          uploadController.finalstatus.value == 'APPROVED',
          uploadController.finalstatus.value == 'REJECTED'
              ? Icons.error_outline_rounded
              : (uploadController.finalstatus.value == 'FLAGGED'
                  ? Icons.hourglass_top_rounded
                  : Icons.image_rounded),
          uploadController.finalstatus.value == 'PENDING' ||
              uploadController.finalstatus.value == 'FLAGGED',
        ),
        (
          'Title (min. 5 chars)',
          titleController.text.trim().length >= 5,
          Icons.title_rounded,
          false,
        ),
      ];

      return Column(
        children: checks.map((check) {
          final (label, isComplete, icon, isProcessing) = check;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isComplete
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : isDark
                      ? const Color(0xFF1F2937)
                      : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isComplete
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : isDark
                        ? const Color(0xFF374151)
                        : const Color(0xFFE5E7EB),
                width: isComplete ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? const Color(0xFF10B981)
                        : isDark
                            ? const Color(0xFF374151)
                            : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isComplete ? Icons.check_rounded : icon,
                    size: 14,
                    color: isComplete
                        ? AppColors.textPrimary
                        : isDark
                            ? AppColors.textPrimary.withValues(alpha: 0.4)
                            : const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: context.themeTypography.body.copyWith(
                          color: isComplete
                              ? (isDark
                                  ? AppColors.textPrimary
                                  : const Color(0xFF111827))
                              : (isProcessing && isDark
                                  ? AppColors.textPrimary
                                  : isDark
                                      ? AppColors.textPrimary.withValues(
                                          alpha: 0.6,
                                        )
                                      : const Color(0xFF6B7280)),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isProcessing && !isComplete) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: videoProgress,
                            backgroundColor: isDark
                                ? AppColors.textPrimary.withValues(alpha: 0.1)
                                : AppColors.bgPage.withValues(alpha: 0.05),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF6366F1),
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    });
  }
}

/// Final publishing card containing checklist, validation statuses, and summary
class CreateContentFinalPublishSection extends StatelessWidget {
  const CreateContentFinalPublishSection({
    required this.uploadController,
    required this.titleController,
    required this.isDark,
    super.key,
  });

  final UploadController uploadController;
  final TextEditingController titleController;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  size: 28,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to Publish',
                      style: context.themeTypography.headline.copyWith(
                        color: isDark
                            ? AppColors.textPrimary
                            : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your video will be processed and made available to viewers',
                      style: context.themeTypography.body.copyWith(
                        color: isDark
                            ? AppColors.textPrimary.withValues(alpha: 0.75)
                            : const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          CreateContentPublishChecklist(
            uploadController: uploadController,
            titleController: titleController,
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          Obx(
            () => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1F2937) : AppColors.textPrimary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thumbnail Status: ${uploadController.finalstatus.value}',
                          style: context.themeTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.textPrimary.withValues(alpha: 0.8)
                                : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CreateContentValidationSummaryRow(
                          label: 'Title',
                          status:
                              uploadController.titleValidationStatus.value,
                          reason:
                              uploadController.titleValidationReason.value,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 8),
                        CreateContentValidationSummaryRow(
                          label: 'Description',
                          status: uploadController
                              .descriptionValidationStatus.value,
                          reason: uploadController
                              .descriptionValidationReason.value,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Publish and Save Draft action buttons with progress animations
class CreateContentPublishActionRow extends StatelessWidget {
  const CreateContentPublishActionRow({
    required this.uploadController,
    required this.titleController,
    required this.canPublish,
    required this.onPublish,
    required this.onSaveDraft,
    required this.isDark,
    super.key,
  });

  final UploadController uploadController;
  final TextEditingController titleController;
  final bool canPublish;
  final VoidCallback onPublish;
  final VoidCallback onSaveDraft;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isProcessing = uploadController.isProcessing.value;
      final isUploading = uploadController.isUploading.value;

      if (isProcessing) {
        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                uploadController.processingMessage.value.isNotEmpty
                    ? uploadController.processingMessage.value
                    : 'Publishing Video...',
                style: context.themeTypography.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textSecondary
                      : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        );
      }

      if (isUploading && !canPublish) {
        final progress = uploadController.uploadProgress.value;
        final progressText = '${(progress * 100).toInt()}%';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.textPrimary,
                        ),
                        value: progress,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uploading...',
                          style: context.themeTypography.body.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textPrimary
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Processing your video',
                          style: context.themeTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    progressText,
                    style: context.themeTypography.headline.copyWith(
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: isDark
                      ? const Color(0xFF21262D)
                      : const Color(0xFFF3F4F6),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      final hasVideo = uploadController.videoUrl.value.isNotEmpty ||
          uploadController.pickedVideo.value != null ||
          uploadController.resumedVideoDraft.value != null;
      final hasTitle = titleController.text.trim().isNotEmpty;
      final canSaveDraft = hasVideo && hasTitle;

      return Row(
        children: [
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color:
                    isDark ? const Color(0xFF1F2937) : AppColors.textPrimary,
                border: Border.all(
                  color: canSaveDraft
                      ? (isDark
                          ? const Color(0xFF4B5563)
                          : const Color(0xFFD1D5DB))
                      : (isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFE5E7EB)),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: canSaveDraft ? onSaveDraft : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_outline_rounded,
                          size: 20,
                          color: canSaveDraft
                              ? (isDark
                                  ? AppColors.textPrimary
                                  : const Color(0xFF374151))
                              : (isDark
                                  ? AppColors.textPrimary
                                      .withValues(alpha: 0.3)
                                  : const Color(0xFF9CA3AF)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Save Draft',
                          style: context.themeTypography.button.copyWith(
                            color: canSaveDraft
                                ? (isDark
                                    ? AppColors.textPrimary
                                    : const Color(0xFF374151))
                                : (isDark
                                    ? AppColors.textPrimary
                                        .withValues(alpha: 0.3)
                                    : const Color(0xFF9CA3AF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: canPublish
                    ? LinearGradient(
                        colors: uploadController.isScheduled.value
                            ? [
                                const Color(0xFFF59E0B),
                                const Color(0xFFFBBF24)
                              ]
                            : [
                                const Color(0xFF6366F1),
                                const Color(0xFF8B5CF6)
                              ],
                      )
                    : null,
                color: canPublish
                    ? null
                    : isDark
                        ? const Color(0xFF21262D)
                        : const Color(0xFFE5E7EB),
                boxShadow: canPublish
                    ? [
                        BoxShadow(
                          color: (uploadController.isScheduled.value
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF6366F1))
                              .withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: canPublish ? onPublish : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          uploadController.isScheduled.value
                              ? Icons.schedule_rounded
                              : (isUploading
                                  ? Icons.cloud_sync_rounded
                                  : Icons.cloud_upload_rounded),
                          size: 22,
                          color: canPublish
                              ? AppColors.textPrimary
                              : isDark
                                  ? AppColors.textPrimary
                                      .withValues(alpha: 0.3)
                                  : const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          uploadController.isScheduled.value
                              ? 'Schedule Upload'
                              : (isUploading
                                  ? 'Publish (Uploading in background)'
                                  : 'Publish Now'),
                          style: context.themeTypography.title.copyWith(
                            color: canPublish
                                ? AppColors.textPrimary
                                : isDark
                                    ? AppColors.textPrimary
                                        .withValues(alpha: 0.3)
                                    : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
