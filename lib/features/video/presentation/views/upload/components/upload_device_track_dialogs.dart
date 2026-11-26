import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Production dialogs for picking and attaching local subtitle and audio/video files
/// directly to the video upload payload.
class UploadDeviceTrackDialogs {
  const UploadDeviceTrackDialogs._();

  /// Displays dialog for picking a device subtitle file (.srt, .vtt) and assigning a language.
  static void showUploadSubtitleDialog({
    required BuildContext context,
    required UploadController controller,
    required bool isDarkMode,
    String? defaultLangCode,
  }) {
    final selectedLangCode = (defaultLangCode ?? 'en').obs;
    final selectedFile = Rx<PlatformFile?>(null);

    final supported = controller.supportedLanguagesList;
    final defaultMatch = supported.any((l) => l.code.toLowerCase() == selectedLangCode.value.toLowerCase());
    if (!defaultMatch && supported.isNotEmpty) {
      selectedLangCode.value = supported.first.code;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Obx(() {
          final file = selectedFile.value;

          return AlertDialog(
            backgroundColor: AppColors.appBarSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.bgSurface),
            ),
            title: const Row(
              children: [
                Icon(Icons.subtitles_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Upload Subtitles from Device',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Target Language',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgInput,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.bgSurface),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedLangCode.value,
                          dropdownColor: AppColors.appBarSurface,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          isExpanded: true,
                          items: supported.map((lang) {
                            return DropdownMenuItem<String>(
                              value: lang.code,
                              child: Text(
                                lang.nativeName.isNotEmpty && lang.nativeName != lang.name
                                    ? '${lang.name} (${lang.nativeName})'
                                    : lang.name,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) selectedLangCode.value = val;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Subtitle File (.srt, .vtt)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['srt', 'vtt', 'txt', 'json'],
                          withData: true,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          selectedFile.value = result.files.first;
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: file != null ? Colors.white70 : AppColors.bgSurface,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              file != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                              size: 32,
                              color: file != null ? Colors.white : AppColors.textSecondary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              file != null ? file.name : 'Select subtitle file (.srt, .vtt)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (file != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${(file.size / 1024).toStringAsFixed(1)} KB',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: file == null
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                        controller.attachDeviceSubtitle(selectedLangCode.value, file);
                      },
                child: const Text('Attach Subtitle', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            ],
          );
        });
      },
    );
  }

  /// Displays dialog for picking a device audio or video track (.mp3, .wav, .m4a, .mp4, .mov)
  /// and assigning a language and track role.
  static void showUploadAudioTrackDialog({
    required BuildContext context,
    required UploadController controller,
    required bool isDarkMode,
    String? defaultLangCode,
    String? defaultRole,
  }) {
    final selectedLangCode = (defaultLangCode ?? 'es').obs;
    final selectedRole = (defaultRole ?? 'Dubbed Audio').obs;
    final selectedFile = Rx<PlatformFile?>(null);

    final supported = controller.supportedLanguagesList;
    final defaultMatch = supported.any((l) => l.code.toLowerCase() == selectedLangCode.value.toLowerCase());
    if (!defaultMatch && supported.isNotEmpty) {
      selectedLangCode.value = supported.first.code;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Obx(() {
          final file = selectedFile.value;

          return AlertDialog(
            backgroundColor: AppColors.appBarSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.bgSurface),
            ),
            title: const Row(
              children: [
                Icon(Icons.audiotrack_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Upload Audio Track from Device',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        color: AppColors.bgInput,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.bgSurface),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedLangCode.value,
                          dropdownColor: AppColors.appBarSurface,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          isExpanded: true,
                          items: supported.map((lang) {
                            return DropdownMenuItem<String>(
                              value: lang.code,
                              child: Text(
                                lang.nativeName.isNotEmpty && lang.nativeName != lang.name
                                    ? '${lang.name} (${lang.nativeName})'
                                    : lang.name,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) selectedLangCode.value = val;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Track Role / Category',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgInput,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.bgSurface),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole.value,
                          dropdownColor: AppColors.appBarSurface,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'Dubbed Audio', child: Text('Dubbed Audio Track')),
                            DropdownMenuItem(value: 'AI Voiceover', child: Text('AI Voiceover Stream')),
                            DropdownMenuItem(value: 'Director Commentary', child: Text('Director Commentary')),
                            DropdownMenuItem(value: 'Secondary Audio', child: Text('Secondary Audio Track')),
                          ],
                          onChanged: (val) {
                            if (val != null) selectedRole.value = val;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Audio or Video File (.mp3, .wav, .m4a, .mp4, .mov)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final result = await FilePicker.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: [
                            'mp3',
                            'wav',
                            'm4a',
                            'aac',
                            'mp4',
                            'mov',
                            'mkv',
                            'webm',
                            'ogg',
                          ],
                          withData: true,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          selectedFile.value = result.files.first;
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: file != null ? Colors.white70 : AppColors.bgSurface,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              file != null ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
                              size: 32,
                              color: file != null ? Colors.white : AppColors.textSecondary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              file != null ? file.name : 'Select file (.mp3, .wav, .m4a, .mp4, .mov)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (file != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: file == null
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                        controller.attachDeviceAudioTrack(
                          selectedLangCode.value,
                          file,
                          selectedRole.value,
                        );
                      },
                child: const Text('Attach Audio', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            ],
          );
        });
      },
    );
  }
}
