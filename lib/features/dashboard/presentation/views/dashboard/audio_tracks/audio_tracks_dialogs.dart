import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_video_sidebar.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Clean modal dialogs and bottom sheets matching Channel Creation styling.
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
          backgroundColor: const Color(0xFF161618),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF27272A)),
          ),
          title: const Text(
            'Add Audio Dub Language',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: controller.supportedLanguages.map((lang) {
                  final isAlreadyAdded =
                      controller.availableLanguages.contains(lang.code);
                  return InkWell(
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      controller.addLanguageLayer(lang.code);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isAlreadyAdded
                            ? const Color(0xFF27272A)
                            : const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isAlreadyAdded
                              ? Colors.white.withValues(alpha: 0.2)
                              : const Color(0xFF27272A),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAlreadyAdded
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            lang.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isAlreadyAdded
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Material(
          color: const Color(0xFF18181B),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.75,
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F3F46),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.video_library_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Select Video for Audio Workspace',
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF27272A)),
                Expanded(
                  child: AudioTracksVideoSidebar(
                    controller: controller,
                    searchController: searchController,
                    surfaceColor: const Color(0xFF18181B),
                    textColor: Colors.white,
                    textSecondaryColor: AppColors.textSecondary,
                    borderColor: const Color(0xFF27272A),
                    isDarkMode: true,
                  ),
                ),
              ],
            ),
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
            backgroundColor: const Color(0xFF161618),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF27272A)),
            ),
            title: const Text(
              'Upload Audio Dub Track',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF27272A)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedLangCode.value,
                        dropdownColor: const Color(0xFF161618),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        isExpanded: true,
                        items: controller.supportedLanguages.map((lang) {
                          return DropdownMenuItem(
                            value: lang.code,
                            child: Text(lang.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) selectedLangCode.value = val;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Track Type Dropdown
                  const Text(
                    'Track Type / Role',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF27272A)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedRole.value,
                        dropdownColor: const Color(0xFF161618),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'Dubbed Audio',
                            child: Text('Dubbed Audio Track'),
                          ),
                          DropdownMenuItem(
                            value: 'AI Voiceover',
                            child: Text('AI Voiceover Stream'),
                          ),
                          DropdownMenuItem(
                            value: 'Director Commentary',
                            child: Text('Director Commentary'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) selectedRole.value = val;
                        },
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
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: file != null
                              ? Colors.white.withValues(alpha: 0.5)
                              : const Color(0xFF27272A),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            file != null
                                ? Icons.check_circle_outline_rounded
                                : Icons.cloud_upload_rounded,
                            size: 28,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            file != null
                                ? file.name
                                : 'Select audio file (.mp3, .wav, .m4a)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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
                child: const Text(
                  'Upload & Attach',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }
}
