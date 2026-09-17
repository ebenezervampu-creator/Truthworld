import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Page Title, Subtitle, and Draft Status Banner
class CreateContentPageHeader extends StatelessWidget {
  const CreateContentPageHeader({
    required this.uploadController,
    required this.isDesktop,
    super.key,
  });

  final UploadController uploadController;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDraftResume = uploadController.resumedVideoDraft.value != null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: Get.back,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Back to Studio',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDraftResume ? 'Resume Video Draft' : 'Upload Video',
                      style: context.themeTypography.headline.copyWith(
                        fontSize: isDesktop ? 28 : 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDraftResume
                          ? 'Continue editing your saved draft before publishing.'
                          : 'Configure metadata, files, playlists, and AI features on a single page.',
                      style: context.themeTypography.body.copyWith(
                        fontSize: isDesktop ? 14 : 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isDraftResume) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_note, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Editing saved draft: "${uploadController.resumedVideoDraft.value!.title}". Changes will update your draft.',
                      style: const TextStyle(color: Colors.amber, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    });
  }
}
