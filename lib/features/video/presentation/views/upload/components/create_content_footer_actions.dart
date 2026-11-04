import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/create_content_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Desktop Footer Actions Bar (Save, Schedule, Publish)
class CreateContentDesktopFooterActions extends StatelessWidget {
  const CreateContentDesktopFooterActions({
    required this.contentController,
    required this.uploadController,
    super.key,
  });

  final CreateContentController contentController;
  final UploadController uploadController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isUploading = uploadController.isUploading.value;
      final isScheduled = uploadController.isScheduled.value;
      final canPublish = contentController.canPublishVideo();

      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 1. Discard
          OutlinedButton(
            onPressed: isUploading
                ? null
                : () => contentController.showExitConfirmation(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Discard', style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(width: 16),

          // 2. Save (formerly Save Draft)
          OutlinedButton.icon(
            onPressed: isUploading
                ? null
                : () => contentController.handleVideoUpload(isDraft: true),
            icon: const Icon(Icons.save_as_outlined, color: Colors.white, size: 18),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 16),

          // 3. Mode switcher button (Schedule toggle when in publish mode, or Publish toggle when in schedule mode)
          if (!isScheduled)
            OutlinedButton.icon(
              onPressed: isUploading
                  ? null
                  : () => contentController.activateScheduleMode(context),
              icon: const Icon(Icons.schedule_outlined, color: Colors.white, size: 18),
              label: const Text('Schedule', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: isUploading
                  ? null
                  : () => uploadController.isScheduled.value = false,
              icon: const Icon(Icons.public, color: Colors.white, size: 18),
              label: const Text('Publish', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          const SizedBox(width: 16),

          // 4. Primary CTA Button: 'Publish' or 'Schedule' (YouTube style)
          ElevatedButton(
            onPressed: isUploading || !canPublish
                ? null
                : () => contentController.handleVideoUpload(isDraft: false),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: isUploading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                  )
                : Text(
                    isScheduled ? 'Schedule' : 'Publish',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      );
    });
  }
}

/// Mobile Sticky Bottom Footer Actions Bar (Save, Schedule, Publish)
class CreateContentMobileFooterActions extends StatelessWidget {
  const CreateContentMobileFooterActions({
    required this.contentController,
    required this.uploadController,
    super.key,
  });

  final CreateContentController contentController;
  final UploadController uploadController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isUploading = uploadController.isUploading.value;
      final isScheduled = uploadController.isScheduled.value;
      final canPublish = contentController.canPublishVideo();

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Row(
          children: [
            // 1. Save (formerly Save Draft)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: isUploading
                    ? null
                    : () => contentController.handleVideoUpload(isDraft: true),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 8),

            // 2. Secondary toggle (Schedule when not scheduled, or Publish when scheduled)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: isUploading
                    ? null
                    : () {
                        if (isScheduled) {
                          uploadController.isScheduled.value = false;
                        } else {
                          contentController.activateScheduleMode(context);
                        }
                      },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isScheduled ? 'Publish' : 'Schedule',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 3. Primary CTA: 'Publish' or 'Schedule'
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: isUploading || !canPublish
                    ? null
                    : () => contentController.handleVideoUpload(isDraft: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : Text(
                        isScheduled ? 'Schedule' : 'Publish',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
