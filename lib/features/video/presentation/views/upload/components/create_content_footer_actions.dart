import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/create_content_controller.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Desktop Footer Actions Bar
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
      final canPublish = contentController.canPublishVideo();

      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
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
          OutlinedButton.icon(
            onPressed: isUploading
                ? null
                : () => contentController.handleVideoUpload(isDraft: true),
            icon: const Icon(Icons.save_as_outlined, color: Colors.white, size: 18),
            label: const Text('Save Draft', style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: isUploading || !canPublish
                ? null
                : contentController.handleVideoUpload,
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
                : const Text('Publish Video', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    });
  }
}

/// Mobile Sticky Bottom Footer Actions Bar
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
            Expanded(
              child: OutlinedButton(
                onPressed: isUploading
                    ? null
                    : () => contentController.handleVideoUpload(isDraft: true),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Draft', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: isUploading || !canPublish
                    ? null
                    : contentController.handleVideoUpload,
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
                    : const Text('Publish Video', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    });
  }
}
