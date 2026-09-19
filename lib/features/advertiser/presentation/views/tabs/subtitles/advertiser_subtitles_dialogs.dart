import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Shows dialog to start AI subtitle translation for a target language track.
void showAddSubtitlesTrackDialog(AdvertiserPortalController controller) {
  final selectedLang = 'hi'.obs;

  Get.dialog(
    Obx(
      () => AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
        title: const Text(
          'Add Subtitles Track',
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
              'Translate your video campaign into another language using AI voice translation.',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
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
                    for (final lang in controller.supportedLanguages)
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
            onPressed: () {
              Get.back();
              controller.requestAdSubtitles(selectedLang.value);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Start AI Translation',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Shows dialog to upload custom subtitle file (.vtt, .srt, .txt) from user device.
void showUploadSubtitlesDialog(AdvertiserPortalController controller) {
  final selectedLang = (controller
              .selectedLanguageForSubtitles.value.isNotEmpty
          ? controller.selectedLanguageForSubtitles.value
          : 'en')
      .obs;
  final selectedFile = Rxn<PlatformFile>();

  Get.dialog(
    Obx(
      () => AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
        title: const Text(
          'Upload Custom Subtitles',
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
              'Directly upload subtitle files (.vtt, .srt, .txt) from your device for this ad. Please select the target language first.',
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
                    for (final lang in controller.supportedLanguages)
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
              'Subtitle File (.vtt, .srt, .txt)',
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
                  allowedExtensions: ['vtt', 'srt', 'txt'],
                  withData: true,
                );
                if (result != null && result.files.isNotEmpty) {
                  selectedFile.value = result.files.first;
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
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
                            ? '${selectedFile.value!.name} (${(selectedFile.value!.size / 1024).toStringAsFixed(1)} KB)'
                            : 'Choose file from device...',
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
            onPressed: selectedFile.value == null ||
                    controller.isUploadingSubtitles.value
                ? null
                : () async {
                    Get.back();
                    await controller.uploadDirectSubtitles(
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
              controller.isUploadingSubtitles.value
                  ? 'Importing...'
                  : 'Import & Save',
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
