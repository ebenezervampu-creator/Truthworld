import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/presentation/controllers/clip_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive modal bottom sheet for clipping moments from videos with range sliders,
/// title customization, privacy controls, and direct creation.
class VideoClipDialog {
  static void show({
    required BuildContext context,
    required VideoController controller,
    required VoidCallback onSignInPrompt,
  }) {
    if (!AuthService.to.isAuthenticated.value) {
      onSignInPrompt();
      return;
    }

    final clipController = Get.put(ClipController(video: controller.video));

    // Check creator permission and content safety restrictions
    final restriction = clipController.getClippingRestrictionReason();
    if (restriction != null) {
      Get.delete<ClipController>();
      AppSnackbar.info(
        restriction,
        title: 'Clipping Notice',
      );
      return;
    }

    // Attempt to get video duration and current position for slider
    final totalDuration =
        controller.videoPlayerController?.value.duration.inSeconds.toDouble() ??
        (controller.video.durationSeconds > 0
            ? controller.video.durationSeconds.toDouble()
            : 300.0);

    if (totalDuration < 15.0) {
      Get.snackbar(
        'Clipping Unavailable',
        'This video is too short to create clips from (minimum 15 seconds required).',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.bgSurface,
        colorText: AppColors.textPrimary,
        icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
      );
      return;
    }

    final currentPos =
        controller.videoPlayerController?.value.position.inSeconds.toDouble() ??
        0.0;
    clipController.startSeconds.value = currentPos.clamp(0.0, (totalDuration - 5.0).clamp(0.0, totalDuration));
    clipController.endSeconds.value =
        (clipController.startSeconds.value + 15.0).clamp(
          (clipController.startSeconds.value + clipController.minDuration).clamp(0.0, totalDuration),
          totalDuration,
        );
    clipController.titleError.value = '';
    clipController.clipTitle.value = '';

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.content_cut_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Text(
                  'Create Clip',
                  style: GoogleFonts.roboto(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Title Input ---
            TextField(
              onChanged: clipController.onTitleChanged,
              maxLength: 100,
              style: GoogleFonts.roboto(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Add a title (3-100 characters)...',
                hintStyle: GoogleFonts.roboto(color: AppColors.textSecondary),
                counterStyle: GoogleFonts.roboto(color: AppColors.textSecondary, fontSize: 11),
                filled: true,
                fillColor: AppColors.bgSurface.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            Obx(() {
              if (clipController.titleError.value.isEmpty) {
                return const SizedBox(height: 8);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        clipController.titleError.value,
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // --- Clip Range Selector ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SELECT SEGMENT',
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brand,
                    letterSpacing: 1.2,
                  ),
                ),
                Obx(() {
                  final duration =
                      clipController.endSeconds.value -
                      clipController.startSeconds.value;
                  final isOutOfBounds =
                      duration < clipController.minDuration ||
                      duration > clipController.maxDuration;
                  return Row(
                    children: [
                      Text(
                        '${duration.toStringAsFixed(1)}s',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isOutOfBounds
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        ' (${clipController.minDuration.toInt()}s min - ${clipController.maxDuration.toInt()}s max)',
                        style: GoogleFonts.roboto(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
            const SizedBox(height: 24),

            Obx(
              () => Column(
                children: [
                  RangeSlider(
                    values: RangeValues(
                      clipController.startSeconds.value,
                      clipController.endSeconds.value,
                    ),
                    max: totalDuration > 0 ? totalDuration : 300.0,
                    activeColor: AppColors.brand,
                    inactiveColor: AppColors.bgDivider.withValues(alpha: 0.1),
                    labels: RangeLabels(
                      FormatUtils.formatDuration(
                        Duration(
                          seconds: clipController.startSeconds.value.toInt(),
                        ),
                      ),
                      FormatUtils.formatDuration(
                        Duration(
                          seconds: clipController.endSeconds.value.toInt(),
                        ),
                      ),
                    ),
                    onChanged: (values) {
                      var start = values.start;
                      var end = values.end;
                      final span = end - start;
                      if (span < clipController.minDuration) {
                        if ((start - clipController.startSeconds.value).abs() >
                            (end - clipController.endSeconds.value).abs()) {
                          start = (end - clipController.minDuration).clamp(0.0, totalDuration);
                        } else {
                          end = (start + clipController.minDuration).clamp(0.0, totalDuration);
                        }
                      }
                      if (end - start > clipController.maxDuration) {
                        if ((start - clipController.startSeconds.value).abs() >
                            (end - clipController.endSeconds.value).abs()) {
                          end = (start + clipController.maxDuration).clamp(0.0, totalDuration);
                        } else {
                          start = (end - clipController.maxDuration).clamp(0.0, totalDuration);
                        }
                      }
                      clipController.updateStart(start);
                      clipController.updateEnd(end);
                      controller.videoPlayerController?.seekTo(
                        Duration(seconds: clipController.startSeconds.value.toInt()),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          FormatUtils.formatDuration(
                            Duration(
                              seconds: clipController.startSeconds.value
                                  .toInt(),
                            ),
                          ),
                          style: GoogleFonts.robotoMono(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          FormatUtils.formatDuration(
                            Duration(
                              seconds: clipController.endSeconds.value.toInt(),
                            ),
                          ),
                          style: GoogleFonts.robotoMono(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // --- Actions (Save & Share) ---
            Obx(
              () => Row(
                children: [
                  // --- Save Clip ---
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: clipController.isSaving.value
                            ? null
                            : clipController.saveClip,
                        icon: clipController.isSaving.value
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.bookmark_add_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                        label: Text(
                          'Save Clip',
                          style: GoogleFonts.roboto(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: AppColors.brand.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // --- Share Clip ---
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            clipController.shareClipWithWatermark(context),
                        icon: const Icon(
                          Icons.share_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          'Share Clip',
                          style: GoogleFonts.roboto(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.bgSurface.withValues(
                            alpha: 0.8,
                          ),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: AppColors.brand.withValues(alpha: 0.8),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: Get.back,
                child: Text(
                  'Cancel',
                  style: GoogleFonts.roboto(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isScrollControlled: true,
    ).whenComplete(() {
      if (Get.isRegistered<ClipController>()) {
        Get.delete<ClipController>();
      }
    });
  }


}
