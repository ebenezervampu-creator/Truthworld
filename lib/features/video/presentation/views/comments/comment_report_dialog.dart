import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/comment_report.dart';
import 'package:truthworld/features/video/data/services/comment_service.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Premium report dialog for comments and replies
class CommentReportController extends GetxController {
  final TextEditingController descriptionController = TextEditingController();
  final Rxn<ReportReason> selectedReason = Rxn<ReportReason>();
  final RxBool isSubmitting = false.obs;

  @override
  void onClose() {
    descriptionController.dispose();
    super.onClose();
  }
}

/// Premium report dialog for comments and replies
class CommentReportDialog extends StatelessWidget {
  const CommentReportDialog({
    required this.comment,
    required this.videoId,
    this.replyId,
    super.key,
  });
  final Comment comment;
  final String videoId;
  final String? replyId;

  static void show({
    required BuildContext context,
    required Comment comment,
    required String videoId,
    String? replyId,
  }) {
    showDialog(
      context: context,
      builder: (_) => CommentReportDialog(
        comment: comment,
        videoId: videoId,
        replyId: replyId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      CommentReportController(),
      tag: 'comment_report_${comment.id}_$replyId',
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final commentService = CommentService();
    final authService = FirebaseAuth.instance;

    Future<void> submitReport() async {
      if (controller.selectedReason.value == null) {
        Get.snackbar(
          'Error',
          'Please select a reason',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      try {
        controller.isSubmitting.value = true;

        final currentUser = authService.currentUser;
        if (currentUser == null) {
          Get.snackbar(
            'Error',
            'You must be logged in to report',
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }

        await commentService.reportComment(
          commentId: comment.id,
          replyId: replyId,
          videoId: videoId,
          reporterId: currentUser.uid,
          reporterName: currentUser.displayName ?? 'Anonymous',
          reason: controller.selectedReason.value!,
          description: controller.descriptionController.text.isEmpty
              ? null
              : controller.descriptionController.text,
        );

        Get.snackbar(
          'Success',
          'Thank you for reporting. Our team will review this.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: AppColors.textPrimary,
        );
        if (context.mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to submit report: $e',
          snackPosition: SnackPosition.BOTTOM,
        );
      } finally {
        controller.isSubmitting.value = false;
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgSurface : AppColors.textPrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(
                      Icons.flag_outlined,
                      color: AppColors.error,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Report ${replyId != null ? 'Reply' : 'Comment'}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.bgPage,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Reason text
                Text(
                  'Why are you reporting this?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textSecondary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Reason selection
                Obx(
                  () => Column(
                    children: _buildReasonOptions(isDark, controller),
                  ),
                ),

                const SizedBox(height: 16),

                // Description field
                Obx(
                  () => TextField(
                    controller: controller.descriptionController,
                    maxLines: 3,
                    maxLength: 200,
                    enabled: !controller.isSubmitting.value,
                    decoration: InputDecoration(
                      hintText: 'Additional details (optional)',
                      hintStyle: TextStyle(
                        color: isDark
                            ? AppColors.textTertiary
                            : AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.bgSurface
                          : AppColors.textSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.bgDivider
                              : AppColors.textSecondary,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.bgDivider
                              : AppColors.textSecondary,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.brand,
                          width: 2,
                        ),
                      ),
                      counterStyle: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textTertiary
                            : AppColors.textSecondary,
                      ),
                    ),
                    style: TextStyle(
                      color: isDark ? AppColors.textPrimary : AppColors.bgPage,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
                Obx(() {
                  final isSubmitting = controller.isSubmitting.value;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textSecondary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isSubmitting ? null : submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          disabledBackgroundColor: AppColors.textSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    AppColors.textPrimary,
                                  ),
                                ),
                              )
                            : const Text(
                                'Submit Report',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildReasonOptions(
    bool isDark,
    CommentReportController controller,
  ) {
    return ReportReason.values.map((reason) {
      final isSelected = controller.selectedReason.value == reason;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () => controller.selectedReason.value = reason,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.brand.withAlpha(30)
                  : isDark
                  ? AppColors.bgSurface
                  : AppColors.textSecondary,
              border: Border.all(
                color: isSelected
                    ? AppColors.brand
                    : isDark
                    ? AppColors.bgDivider
                    : AppColors.textSecondary,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.brand
                          : AppColors.textSecondary,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.brand,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reason.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.bgPage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
}
