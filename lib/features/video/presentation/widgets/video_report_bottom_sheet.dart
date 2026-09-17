import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal bottom sheet for submitting video reports with predefined categories,
/// optional current player timestamp, and detailed descriptions.
class VideoReportBottomSheet {
  static void show({
    required BuildContext context,
    required VideoController controller,
    required MainController mainController,
    required VoidCallback onSignInPrompt,
  }) {
    if (!AuthService.to.isAuthenticated.value) {
      onSignInPrompt();
      return;
    }

    final reasons = [
      {
        'label': 'Sexual content',
        'description': 'Nudity, sexually explicit content, or pornography',
      },
      {
        'label': 'Violent or repulsive content',
        'description': 'Fight clips, self-harm, gore, or animal abuse',
      },
      {
        'label': 'Hateful or abusive content',
        'description': 'Promoting violence or hatred against protected groups',
      },
      {
        'label': 'Harassment or bullying',
        'description': 'Cyberbullying or personal abuse',
      },
      {
        'label': 'Harmful or dangerous acts',
        'description': 'Dangerous challenges, stunts, or drug promotion',
      },
      {
        'label': 'Child abuse',
        'description': 'Endangerment, exploitation, or sexualization of minors',
      },
      {
        'label': 'Promotes terrorism',
        'description': 'Incitement to violence or terrorist recruitment',
      },
      {
        'label': 'Spam or misleading',
        'description': 'Scams, clickbait, or deceptive metadata',
      },
      {
        'label': 'Infringement of my rights',
        'description': 'Copyright violation or privacy invasion',
      },
    ];

    final selectedReason = RxnString();
    final currentStep =
        1.obs; // Step 1: select reason, Step 2: comment & timestamp
    final commentController = TextEditingController();

    // Get current playback time to suggest as timestamp
    final currentSeconds =
        controller.videoPlayerController?.value.position.inSeconds ?? 0;
    final minutes = currentSeconds ~/ 60;
    final seconds = currentSeconds % 60;
    final defaultTimestamp =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final includeTimestamp = false.obs;
    final isSubmitting = false.obs;

    Get.bottomSheet(
      Obx(() {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  if (currentStep.value == 2)
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () {
                        currentStep.value = 1;
                      },
                    ),
                  const Icon(Icons.flag_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    currentStep.value == 1 ? 'Report video' : 'Provide details',
                    style: GoogleFonts.roboto(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (currentStep.value == 1) ...[
                // Info note
                Text(
                  'Flagged videos are reviewed by staff 24/7 to determine whether they violate Community Guidelines. Severe violations may result in immediate video removal or account termination.',
                  style: GoogleFonts.roboto(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Reasons List
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 350),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: reasons.length,
                      itemBuilder: (context, index) {
                        final r = reasons[index];
                        final label = r['label']!;
                        final desc = r['description']!;
                        final isSelected = selectedReason.value == label;

                        return InkWell(
                          onTap: () {
                            selectedReason.value = label;
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Radio<String>(
                                  value: label,
                                  groupValue: selectedReason.value,
                                  activeColor: AppColors.brand,
                                  onChanged: (val) {
                                    selectedReason.value = val;
                                  },
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: GoogleFonts.roboto(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        desc,
                                        style: GoogleFonts.roboto(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Next / Cancel
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: Get.back,
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.roboto(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: selectedReason.value == null
                          ? null
                          : () {
                              currentStep.value = 2;
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Next',
                        style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Step 2: Timestamp & comments
                Text(
                  'Selected Reason: ${selectedReason.value}',
                  style: GoogleFonts.roboto(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Timestamp checkbox
                CheckboxListTile(
                  value: includeTimestamp.value,
                  activeColor: AppColors.brand,
                  title: Text(
                    'Include timestamp at $defaultTimestamp',
                    style: GoogleFonts.roboto(color: AppColors.textPrimary, fontSize: 13),
                  ),
                  subtitle: Text(
                    'Helps reviewers locate the issue quickly',
                    style: GoogleFonts.roboto(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    includeTimestamp.value = val ?? false;
                  },
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: commentController,
                  maxLines: 4,
                  maxLength: 500,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText:
                        'Provide additional details (e.g. description, background info)...',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    counterStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit / Back
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        currentStep.value = 1;
                      },
                      child: Text(
                        'Back',
                        style: GoogleFonts.roboto(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: isSubmitting.value
                          ? null
                          : () {
                              isSubmitting.value = true;
                              Get.back();

                              // Build detailed comment including timestamp
                              final timestampPrefix = includeTimestamp.value
                                  ? '[Timestamp: $defaultTimestamp] '
                                  : '';
                              final finalComment =
                                  '$timestampPrefix${commentController.text.trim()}';

                              mainController.reportVideo(
                                context: context,
                                videoId: controller.video.id,
                                channelId: controller.video.channelId,
                                reason: selectedReason.value!,
                                comment: finalComment,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Submit',
                        style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      }),
      isScrollControlled: true,
    );
  }

}
