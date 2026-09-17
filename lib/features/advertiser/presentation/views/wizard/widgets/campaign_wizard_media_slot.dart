import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive media upload card slot with upload indicator, replace, and clear controls.
Widget buildCampaignMediaUploadSlot({
  required String title,
  required String subtitle,
  required TextEditingController urlController,
  required RxString fileNameNotifier,
  required RxString metaNotifier,
  required RxBool isUploadingNotifier,
  required RxDouble uploadProgressNotifier,
  required RxString uploadStatusNotifier,
  required IconData mediaIcon,
  required VoidCallback onPickDevice,
  required VoidCallback onPickPreset,
  bool isRequired = false,
}) {
  return Obx(() {
    final isUploading = isUploadingNotifier.value;
    final progress = uploadProgressNotifier.value;
    final statusText = uploadStatusNotifier.value;
    final fileName = fileNameNotifier.value;
    final hasFile = fileName.isNotEmpty || urlController.text.trim().isNotEmpty;
    final metaText = metaNotifier.value;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUploading
              ? AppColors.brand
              : hasFile
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : const Color(0xFF27272A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isRequired) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: Color(0xFFF87171),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),

          if (isUploading) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            statusText.isNotEmpty ? statusText : 'Processing media...',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.brand,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: const Color(0xFF27272A),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (hasFile) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      mediaIcon,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName.isNotEmpty ? fileName : urlController.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'READY',
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: Color(0xFF10B981),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (metaText.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                metaText,
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onPickDevice,
                    icon: const Icon(
                      Icons.sync_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    label: const Text(
                      'Replace',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF3F3F46)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    tooltip: 'Remove media',
                    onPressed: () {
                      urlController.clear();
                      fileNameNotifier.value = '';
                      metaNotifier.value = '';
                    },
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onPickDevice,
                    icon: const Icon(
                      Icons.file_upload_rounded,
                      color: Colors.black,
                      size: 16,
                    ),
                    label: const Text(
                      'Pick from Device',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onPickPreset,
                  icon: const Icon(
                    Icons.video_library_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: const Text(
                    'Presets',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF18181B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF27272A)),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  });
}


/// Widget wrapper for media upload slot.
class CampaignWizardMediaUploadSlot extends StatelessWidget {
  final String title;
  final String subtitle;
  final TextEditingController urlController;
  final RxString fileNameNotifier;
  final RxString metaNotifier;
  final RxBool isUploadingNotifier;
  final RxDouble uploadProgressNotifier;
  final RxString uploadStatusNotifier;
  final IconData mediaIcon;
  final VoidCallback onPickDevice;
  final VoidCallback onPickPreset;
  final bool isRequired;

  const CampaignWizardMediaUploadSlot({
    required this.title,
    required this.subtitle,
    required this.urlController,
    required this.fileNameNotifier,
    required this.metaNotifier,
    required this.isUploadingNotifier,
    required this.uploadProgressNotifier,
    required this.uploadStatusNotifier,
    required this.mediaIcon,
    required this.onPickDevice,
    required this.onPickPreset,
    this.isRequired = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return buildCampaignMediaUploadSlot(
      title: title,
      subtitle: subtitle,
      urlController: urlController,
      fileNameNotifier: fileNameNotifier,
      metaNotifier: metaNotifier,
      isUploadingNotifier: isUploadingNotifier,
      uploadProgressNotifier: uploadProgressNotifier,
      uploadStatusNotifier: uploadStatusNotifier,
      mediaIcon: mediaIcon,
      onPickDevice: onPickDevice,
      onPickPreset: onPickPreset,
      isRequired: isRequired,
    );
  }
}
