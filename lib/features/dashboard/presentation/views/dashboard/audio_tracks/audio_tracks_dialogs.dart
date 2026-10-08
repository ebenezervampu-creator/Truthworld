import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_video_sidebar.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialogs and bottom sheets for Audio Tracks management.
class AudioTracksDialogs {
  const AudioTracksDialogs._();

  /// Displays dialog for adding a new language dub layer from supported catalog.
  static void showAddLanguageModal({
    required BuildContext context,
    required AudioTracksController controller,
    required bool isDarkMode,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.bgDivider),
          ),
          title: const Text(
            'Add Audio Dub Language',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: controller.supportedLanguages.map((lang) {
                  final isAlreadyAdded = controller.availableLanguages.contains(lang.code);
                  return ActionChip(
                    avatar: Icon(
                      isAlreadyAdded ? Icons.check : Icons.add,
                      size: 14,
                      color: Colors.white,
                    ),
                    label: Text(lang.name),
                    backgroundColor: isAlreadyAdded
                        ? AppColors.brand.withValues(alpha: 0.2)
                        : const Color(0xFF1E1E1E),
                    side: const BorderSide(color: AppColors.bgDivider),
                    labelStyle: const TextStyle(color: AppColors.textPrimary),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      controller.addLanguageLayer(lang.code);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close', style: TextStyle(color: AppColors.textPrimary)),
            ),
          ],
        );
      },
    );
  }

  /// Prompts file picker for audio file (.mp3, .wav, .m4a, .aac) and uploads for language.
  static Future<void> pickAndUploadSingleDub({
    required AudioTracksController controller,
    required String langCode,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      await controller.uploadSingleAudioDubForLanguage(
        langCode: langCode,
        file: file,
      );
    }
  }

  /// Displays bottom sheet for picking a video on mobile devices.
  static void showMobileVideoPickerSheet({
    required BuildContext context,
    required AudioTracksController controller,
    required TextEditingController searchController,
    required Color surfaceColor,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
    required bool isDarkMode,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select Video for Audio Workspace',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: AudioTracksVideoSidebar(
                  controller: controller,
                  searchController: searchController,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  textSecondaryColor: textSecondaryColor,
                  borderColor: borderColor,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Displays dialog for uploading audio track files with language and role selection.
  static void showUploadTrackDialog({
    required BuildContext context,
    required AudioTracksController controller,
    required bool isDarkMode,
    String? defaultLangCode,
    String? defaultRole,
  }) {
    final selectedLangCode = (defaultLangCode ?? 'es').obs;
    final selectedRole = (defaultRole ?? 'Dubbed Audio').obs;
    final selectedFile = Rx<PlatformFile?>(null);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Obx(() {
          final file = selectedFile.value;
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.bgDivider),
            ),
            title: const Text(
              'Upload Audio Dub Track',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Language Dropdown
                  const Text(
                    'Language',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedLangCode.value,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: controller.supportedLanguages.map((lang) {
                      return DropdownMenuItem(value: lang.code, child: Text(lang.name));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) selectedLangCode.value = val;
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.bgDivider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.bgDivider),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Track Type Dropdown
                  const Text(
                    'Track Type / Role',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedRole.value,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: const [
                      DropdownMenuItem(value: 'Dubbed Audio', child: Text('Dubbed Audio Track')),
                      DropdownMenuItem(value: 'AI Voiceover', child: Text('AI Voiceover Stream')),
                      DropdownMenuItem(value: 'Director Commentary', child: Text('Director Commentary')),
                    ],
                    onChanged: (val) {
                      if (val != null) selectedRole.value = val;
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.bgDivider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.bgDivider),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // File Picker Dropzone
                  InkWell(
                    onTap: () async {
                      final result = await FilePicker.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        selectedFile.value = result.files.first;
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: file != null ? AppColors.success : AppColors.brand.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            file != null ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
                            size: 32,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            file != null ? file.name : 'Click to Pick Audio File (.mp3, .wav, .m4a)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: file == null
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                        final config = BatchTrackUploadConfig(
                          file: file,
                          title: 'Dub Track - ${selectedLangCode.value}',
                          role: selectedRole.value,
                          type: 'Audio',
                          langCode: selectedLangCode.value,
                        );
                        controller.uploadMultipleTrackFiles(items: [config]);
                      },
                child: const Text('Upload & Attach', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        });
      },
    );
  }
}
