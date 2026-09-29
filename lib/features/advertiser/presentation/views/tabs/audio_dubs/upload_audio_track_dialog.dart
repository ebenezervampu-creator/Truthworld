import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog for uploading a custom recorded audio track from device.
class UploadAudioTrackDialog extends StatelessWidget {
  const UploadAudioTrackDialog({required this.controller, super.key});
  final AdvertiserPortalController controller;

  static void show(BuildContext context, AdvertiserPortalController controller) {
    Get.dialog(UploadAudioTrackDialog(controller: controller));
  }

  @override
  Widget build(BuildContext context) {
    final selectedLang = 'hi'.obs;
    final selectedFile = Rxn<PlatformFile>();

    return Obx(
      () => AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
        title: const Text(
          'Upload Custom Audio Track',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload custom recorded audio (.mp3, .wav, .m4a, .aac) from your device for this ad. Please select the language first.',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Target Language',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedLang.value,
                  dropdownColor: const Color(0xFF161618),
                  iconEnabledColor: Colors.white,
                  isExpanded: true,
                  items: [
                    for (final lang in controller.supportedAudioLanguages)
                      if (lang['code'] != 'en')
                        DropdownMenuItem(
                          value: lang['code'],
                          child: Text(
                            lang['name']!,
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: Colors.white,
                            ),
                          ),
                        ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      selectedLang.value = val;
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Audio File (.mp3, .wav, .m4a, .aac)',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final result = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
                  withData: true,
                );
                if (result != null && result.files.isNotEmpty) {
                  selectedFile.value = result.files.first;
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selectedFile.value != null
                        ? const Color(0xFF10B981)
                        : const Color(0xFF27272A),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedFile.value != null
                          ? Icons.check_circle_outline_rounded
                          : Icons.file_upload_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        selectedFile.value != null
                            ? '${selectedFile.value!.name} (${(selectedFile.value!.size / (1024 * 1024)).toStringAsFixed(2)} MB)'
                            : 'Choose audio file from device...',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: selectedFile.value != null
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: selectedFile.value == null || controller.isUploadingAudioTrack.value
                ? null
                : () async {
                    Get.back();
                    await controller.uploadDirectAudioTrack(
                      langCode: selectedLang.value,
                      file: selectedFile.value!,
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              disabledBackgroundColor: const Color(0xFF27272A),
              disabledForegroundColor: AppColors.textSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              controller.isUploadingAudioTrack.value
                  ? 'Uploading...'
                  : 'Upload & Save',
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
