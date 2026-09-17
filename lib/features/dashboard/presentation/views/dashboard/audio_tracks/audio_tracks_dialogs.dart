import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_video_sidebar.dart';
import 'package:truthworld/theme/app_colors.dart';

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
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Add Audio Dub Language',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
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
                        : (isDarkMode ? const Color(0xFF141414) : const Color(0xFFF1F5F9)),
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
              child: const Text('Close'),
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Video for Audio Workspace',
                  style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
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
            backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Upload Audio Dub Track',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Language Dropdown
                  Text(
                    'Language',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.textSecondary : const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedLangCode.value,
                    dropdownColor: isDarkMode ? const Color(0xFF262626) : Colors.white,
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                    items: controller.supportedLanguages.map((lang) {
                      return DropdownMenuItem(value: lang.code, child: Text(lang.name));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) selectedLangCode.value = val;
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDarkMode ? const Color(0xFF141414) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Track Type Dropdown
                  Text(
                    'Track Type / Role',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.textSecondary : const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedRole.value,
                    dropdownColor: isDarkMode ? const Color(0xFF262626) : Colors.white,
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
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
                      fillColor: isDarkMode ? const Color(0xFF141414) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                        color: isDarkMode ? const Color(0xFF141414) : const Color(0xFFF1F5F9),
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
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
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
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDarkMode ? AppColors.textSecondary : const Color(0xFF6B7280),
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
