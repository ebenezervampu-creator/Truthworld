import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/studio_media_download_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/multi_audio_player_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_track_dubbing_options_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/audio_tracks_video_sidebar.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Clean modal dialogs and bottom sheets matching Channel Creation styling.
class AudioTracksDialogs {
  const AudioTracksDialogs._();

  /// Displays the rich Audio Track & Dubbing Options page for a specific language.
  /// Shows AI Voice Dubbing options and Direct Audio Track studio guide & upload.
  static void showAudioTrackDubbingOptionsModal({
    required BuildContext context,
    required AudioTracksController controller,
    required String langCode,
    required bool isDarkMode,
    String? initialTier,
    String initialMediaType = 'audio',
  }) {
    Get.to<void>(
      () => AudioTrackDubbingOptionsPage(
        controller: controller,
        initialLangCode: langCode,
        isDarkMode: isDarkMode,
        initialTierId: initialTier,
        initialMediaType: initialMediaType,
      ),
    );
  }

  /// Displays dedicated page to add an audio track with language selection and dubbing options.
  static void showAddAudioTrackWithOptionsModal({
    required BuildContext context,
    required AudioTracksController controller,
    required bool isDarkMode,
    String? initialTier = 'audio_track',
    String initialMediaType = 'audio',
  }) {
    Get.to<void>(
      () => AudioTrackDubbingOptionsPage(
        controller: controller,
        initialLangCode: 'te',
        isDarkMode: isDarkMode,
        initialTierId: initialTier,
        initialMediaType: initialMediaType,
      ),
    );
  }

  /// Displays dedicated page to configure and generate Video Dubbing with AI Dubbing.
  static void showAddVideoTrackWithOptionsModal({
    required BuildContext context,
    required AudioTracksController controller,
    required bool isDarkMode,
    String initialTier = 'audio_track',
  }) {
    Get.to<void>(
      () => AudioTrackDubbingOptionsPage(
        controller: controller,
        initialLangCode: 'te',
        isDarkMode: isDarkMode,
        initialTierId: initialTier,
      ),
    );
  }

  /// Displays bottom sheet asking user to choose between 'Generate Audio Dubbing', 'Generate Video Dubbing', or 'Add files',
  /// matching the Studio multi-tier production workflow.
  static void showAddAudioOptionsSheet({
    required BuildContext context,
    required AudioTracksController controller,
    required bool isDarkMode,
  }) {
    Get.bottomSheet<void>(
      Material(
        color: AppColors.bgPage,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Audio Track',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox.shrink(
                      child: Text(
                        'Add AudioTracks & VideoTracks Dubbing',
                        style: TextStyle(fontSize: 0, color: Colors.transparent),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Get.back<void>(),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Choose how you would like to create or add audio tracks.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.bgSurface, height: 1),
                const SizedBox(height: 16),

                // Option 1: Generate Audio tracks
                _buildAddOptionCard(
                  icon: Icons.auto_awesome_rounded,
                  iconBg: AppColors.brand.withValues(alpha: 0.15),
                  iconColor: Colors.white,
                  title: 'Generate Audio tracks',
                  subtitle:
                      'Auto-generate multi-language audio track & voiceover with AI',
                  onTap: () {
                    Get.back<void>();
                    showAddAudioTrackWithOptionsModal(
                      context: context,
                      controller: controller,
                      isDarkMode: isDarkMode,
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Option 2: Upload Audio track from device video/Audio
                _buildAddOptionCard(
                  icon: Icons.upload_file_rounded,
                  iconBg: AppColors.bgSurface,
                  iconColor: Colors.white,
                  title: 'Upload Audio track from device video/Audio',
                  subtitle:
                      'Upload existing audio or video files (.mp3, .wav, .m4a, .mp4, .mov) from your device',
                  onTap: () {
                    Get.back<void>();
                    showUploadTrackDialog(
                      context: context,
                      controller: controller,
                      isDarkMode: isDarkMode,
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  static Widget _buildAddOptionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgSurface),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
          backgroundColor: AppColors.appBarSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.bgSurface),
          ),
          title: const Text(
            'Add Audio Dub Language',
            style: TextStyle(
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
                      showAudioTrackDubbingOptionsModal(
                        context: context,
                        controller: controller,
                        langCode: lang.code,
                        isDarkMode: isDarkMode,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isAlreadyAdded
                            ? AppColors.bgSurface
                            : AppColors.bgInput,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isAlreadyAdded
                              ? Colors.white.withValues(alpha: 0.2)
                              : AppColors.bgSurface,
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
          color: AppColors.bgPage,
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
                    color: AppColors.bgElevated,
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
                const Divider(height: 1, color: AppColors.bgSurface),
                Expanded(
                  child: AudioTracksVideoSidebar(
                    controller: controller,
                    searchController: searchController,
                    surfaceColor: AppColors.bgPage,
                    textColor: Colors.white,
                    textSecondaryColor: AppColors.textSecondary,
                    borderColor: AppColors.bgSurface,
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

  /// Displays dialog for uploading audio track files with language and role selection,
  /// including full support for custom languages.
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
    final isCustomLanguage = false.obs;
    final customNameCtrl = TextEditingController();
    final customCodeCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Obx(() {
          final file = selectedFile.value;
          final isCustom = isCustomLanguage.value;

          final allLangs = <({String code, String name})>[
            ...controller.customLanguages.entries.map(
              (e) => (code: e.key, name: '${e.value} (Custom)'),
            ),
            ...controller.supportedLanguages,
          ];

          return AlertDialog(
            backgroundColor: AppColors.appBarSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.bgSurface),
            ),
            title: const Text(
              'Upload Audio Track from Device (Video / Audio)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Language Header with Custom Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Language',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        InkWell(
                          onTap: () => isCustomLanguage.value = !isCustomLanguage.value,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              isCustom ? 'Choose from list' : '+ Add custom language',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (!isCustom)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.bgSurface),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: allLangs.any((l) => l.code == selectedLangCode.value)
                                ? selectedLangCode.value
                                : (allLangs.isNotEmpty ? allLangs.first.code : 'en'),
                            dropdownColor: AppColors.appBarSurface,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            isExpanded: true,
                            items: allLangs.map((lang) {
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
                      )
                    else ...[
                      TextField(
                        controller: customNameCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Custom Language Name (e.g. Bhojpuri)',
                          hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.bgInput,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.bgSurface),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (val) {
                          if (customCodeCtrl.text.isEmpty && val.trim().length >= 2) {
                            customCodeCtrl.text = val.trim().substring(0, 2).toLowerCase();
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: customCodeCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Language Code (e.g. bho)',
                          hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.bgInput,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.bgSurface),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],

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
                        color: AppColors.bgInput,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.bgSurface),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole.value,
                          dropdownColor: AppColors.appBarSurface,
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
                            DropdownMenuItem(
                              value: 'Secondary Audio',
                              child: Text('Secondary Audio Track'),
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
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: file != null
                                ? Colors.white.withValues(alpha: 0.5)
                                : AppColors.bgSurface,
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
                                  : 'Select audio or video file (.mp3, .wav, .m4a, .mp4, .mov)',
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
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
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
                        var finalLangCode = selectedLangCode.value;
                        if (isCustom) {
                          final name = customNameCtrl.text.trim();
                          final code = customCodeCtrl.text.trim().toLowerCase();
                          if (name.isEmpty || code.isEmpty) {
                            return;
                          }
                          controller.addCustomLanguage(code, name);
                          finalLangCode = code;
                        }

                        Navigator.of(dialogContext).pop();
                        final config = BatchTrackUploadConfig(
                          file: file,
                          title: '${controller.getLanguageName(finalLangCode)} ${selectedRole.value}',
                          role: selectedRole.value,
                          type: 'Audio',
                          langCode: finalLangCode,
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

  /// Displays dialog for adding a commentary audio track with title, role, language, and file.
  static void showAddCommentaryDialog({
    required BuildContext context,
    required AudioTracksController controller,
    required bool isDarkMode,
  }) {
    final titleCtrl = TextEditingController(text: 'Director Commentary');
    final selectedRole = 'Director Commentary'.obs;
    final selectedLangCode = (controller.selectedVideo.value?.language ?? 'en').obs;
    final selectedFile = Rx<PlatformFile?>(null);
    final isCustomLanguage = false.obs;
    final customNameCtrl = TextEditingController();
    final customCodeCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Obx(() {
          final file = selectedFile.value;
          final isCustom = isCustomLanguage.value;

          final allLangs = <({String code, String name})>[
            ...controller.customLanguages.entries.map(
              (e) => (code: e.key, name: '${e.value} (Custom)'),
            ),
            ...controller.supportedLanguages,
          ];

          return AlertDialog(
            backgroundColor: AppColors.appBarSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.bgSurface),
            ),
            title: const Text(
              'Add Commentary Track',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Commentary Title
                    const Text(
                      'Commentary Title',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Director Commentary, Creator Breakdown',
                        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        filled: true,
                        fillColor: AppColors.bgInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.bgSurface),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Commentary Role
                    const Text(
                      'Commentary Type / Role',
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
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.bgSurface),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole.value,
                          dropdownColor: AppColors.appBarSurface,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'Director Commentary',
                              child: Text('Director Commentary'),
                            ),
                            DropdownMenuItem(
                              value: 'Actors Commentary',
                              child: Text('Actors Commentary'),
                            ),
                            DropdownMenuItem(
                              value: 'Behind the Scenes',
                              child: Text('Behind the Scenes Narration'),
                            ),
                            DropdownMenuItem(
                              value: 'Voiceover Track',
                              child: Text('Creator Voiceover Track'),
                            ),
                            DropdownMenuItem(
                              value: 'Reaction Commentary',
                              child: Text('Reaction / Discussion Track'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) selectedRole.value = val;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Language Header with Custom Language Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Language',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        InkWell(
                          onTap: () => isCustomLanguage.value = !isCustomLanguage.value,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              isCustom ? 'Choose from list' : '+ Custom language',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (!isCustom)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.bgSurface),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: allLangs.any((l) => l.code == selectedLangCode.value)
                                ? selectedLangCode.value
                                : (allLangs.isNotEmpty ? allLangs.first.code : 'en'),
                            dropdownColor: AppColors.appBarSurface,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            isExpanded: true,
                            items: allLangs.map((lang) {
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
                      )
                    else ...[
                      TextField(
                        controller: customNameCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Custom Language Name (e.g. Bhojpuri)',
                          hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.bgInput,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.bgSurface),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (val) {
                          if (customCodeCtrl.text.isEmpty && val.trim().length >= 2) {
                            customCodeCtrl.text = val.trim().substring(0, 2).toLowerCase();
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: customCodeCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Language Code (e.g. bho)',
                          hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.bgInput,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.bgSurface),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],

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
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: file != null
                                ? Colors.white.withValues(alpha: 0.5)
                                : AppColors.bgSurface,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              file != null
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.mic_rounded,
                              size: 28,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              file != null
                                  ? file.name
                                  : 'Select commentary audio (.mp3, .wav, .m4a)',
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
                        var finalLangCode = selectedLangCode.value;
                        if (isCustom) {
                          final name = customNameCtrl.text.trim();
                          final code = customCodeCtrl.text.trim().toLowerCase();
                          if (name.isNotEmpty && code.isNotEmpty) {
                            controller.addCustomLanguage(code, name);
                            finalLangCode = code;
                          }
                        }

                        Navigator.of(dialogContext).pop();
                        final config = BatchTrackUploadConfig(
                          file: file,
                          title: titleCtrl.text.trim().isNotEmpty
                              ? titleCtrl.text.trim()
                              : 'Commentary Track',
                          role: selectedRole.value,
                          type: 'Audio',
                          langCode: finalLangCode,
                        );
                        controller.uploadMultipleTrackFiles(items: [config]);
                      },
                child: const Text(
                  'Upload Commentary',
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

  /// Displays category-style bottom sheet for selecting and toggling languages,
  /// matching Channel Creation Category picker pattern.
  static void showLanguagePickerBottomSheet({
    required BuildContext context,
    required AudioTracksController controller,
    required bool isDarkMode,
  }) {
    final searchQuery = ''.obs;
    final searchCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Material(
          color: AppColors.bgPage,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            height: MediaQuery.of(sheetContext).size.height * 0.8,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Top header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Obx(
                        () => Text(
                          'Select Languages & Dubbing Layers (${controller.availableLanguages.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose languages to configure for viewer audio dubbing and switching.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                // Search field + Add Custom Language button
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.bgInput,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.bgSurface),
                        ),
                        child: TextField(
                          controller: searchCtrl,
                          onChanged: (val) => searchQuery.value = val.trim().toLowerCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Search language...',
                            hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                            prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 18),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        showAddCustomLanguageDialog(
                          context: context,
                          controller: controller,
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 14, color: Colors.black),
                      label: const Text(
                        'Custom',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(color: AppColors.bgSurface, height: 1),

                // Language list
                Expanded(
                  child: Obx(() {
                    final query = searchQuery.value;
                    final allLangs = <({String code, String name})>[
                      ...controller.customLanguages.entries.map(
                        (e) => (code: e.key, name: '${e.value} (Custom)'),
                      ),
                      ...controller.supportedLanguages,
                    ];

                    final filtered = query.isEmpty
                        ? allLangs
                        : allLangs.where((l) {
                            return l.name.toLowerCase().contains(query) ||
                                l.code.toLowerCase().contains(query);
                          }).toList();

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const Divider(
                        color: AppColors.bgSurface,
                        height: 1,
                      ),
                      itemBuilder: (ctx, index) {
                        final lang = filtered[index];
                        return Obx(() {
                          final isSelected = controller.availableLanguages.contains(lang.code);
                          final isBase = lang.code == (controller.selectedVideo.value?.language ?? 'en');

                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    lang.name,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.textSecondary,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (kElevenLabsV4SupportedLanguageCodes.contains(lang.code.toLowerCase()))
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFF334155)),
                                    ),
                                    child: const Text(
                                      'ElevenLabs v4',
                                      style: TextStyle(
                                        color: AppColors.textLink,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: isBase
                                ? const Text(
                                    'Original video language (Always active)',
                                    style: TextStyle(color: Colors.white54, fontSize: 11),
                                  )
                                : null,
                            trailing: Checkbox(
                              value: isSelected,
                              activeColor: Colors.white,
                              checkColor: Colors.black,
                              side: const BorderSide(color: AppColors.textDisabled),
                              onChanged: isBase
                                  ? null
                                  : (val) {
                                      if (isSelected) {
                                        controller.removeLanguageLayer(lang.code);
                                      } else {
                                        controller.addLanguageLayer(lang.code);
                                      }
                                    },
                            ),
                            onTap: () {
                              if (isBase) return;
                              if (isSelected) {
                                controller.removeLanguageLayer(lang.code);
                              } else {
                                controller.addLanguageLayer(lang.code);
                              }
                            },
                          );
                        });
                      },
                    );
                  }),
                ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Displays dialog for adding a custom language by entering name and code.
  static void showAddCustomLanguageDialog({
    required BuildContext context,
    required AudioTracksController controller,
  }) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.appBarSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.bgSurface),
          ),
          title: const Text(
            'Add Custom Language',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Language Name',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Bhojpuri, Sanskrit, Klingon',
                    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.bgSurface),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (val) {
                    if (codeCtrl.text.isEmpty && val.trim().length >= 2) {
                      codeCtrl.text = val.trim().substring(0, 2).toLowerCase();
                    }
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Language Code (2-5 letters)',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: codeCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. bho, sa, tlh',
                    hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.bgInput,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.bgSurface),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final code = codeCtrl.text.trim().toLowerCase();
                if (name.isEmpty || code.isEmpty) {
                  return;
                }
                controller.addCustomLanguage(code, name);
                Navigator.pop(dialogCtx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Add Language', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  /// Displays dialog for picking original language of video.
  static void showOriginalLanguageSelectorModal({
    required BuildContext context,
    required AudioTracksController controller,
    required bool isDarkMode,
  }) {
    final search = ''.obs;
    final currentLang = controller.selectedVideo.value?.language ?? 'en';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.appBarSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.bgSurface),
          ),
          title: const Text(
            'Select Video Language',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          content: SizedBox(
            width: 440,
            height: 480,
            child: Column(
              children: [
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.bgSurface),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (val) => search.value = val.toLowerCase().trim(),
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Search language...',
                            hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Obx(() {
                    final query = search.value;
                    final filtered = controller.supportedLanguages.where((l) {
                      if (query.isEmpty) return true;
                      return l.name.toLowerCase().contains(query) ||
                          l.code.toLowerCase().contains(query);
                    }).toList();

                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final lang = filtered[index];
                        final isSelected = lang.code == currentLang;

                        return InkWell(
                          onTap: () {
                            Navigator.of(dialogContext).pop();
                            controller.updateOriginalVideoLanguage(lang.code);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.bgSurface : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.language_rounded,
                                  size: 16,
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    lang.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Current',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Displays responsive video picker modal for all screen sizes.
  static void showVideoPickerModal({
    required BuildContext context,
    required AudioTracksController controller,
    required bool isDarkMode,
  }) {
    showMobileVideoPickerSheet(
      context: context,
      controller: controller,
      searchController: controller.searchController,
      surfaceColor: AppColors.bgPage,
      textColor: Colors.white,
      textSecondaryColor: AppColors.textSecondary,
      borderColor: AppColors.bgSurface,
      isDarkMode: isDarkMode,
    );
  }

  /// Displays the interactive "What's Next" AI Voice Dubbing Pipeline Progress Modal.
  /// Clearly explains the current stage, what happens next, and estimated completion time.
  static void showDubbingProgressModal({
    required BuildContext context,
    required AudioTracksController controller,
    required String langCode,
    required bool isDarkMode,
  }) {
    final langName = controller.getLanguageName(langCode);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.appBarSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.bgSurface),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540),
            padding: const EdgeInsets.all(24),
            child: Obx(() {
              final progressState = controller.getDubbingProgress(langCode);
              final progress = progressState?.progress ?? 20;
              final currentStep = progressState?.stageStep ?? 1;
              final stageTitle = progressState?.stageTitle ?? 'Analyzing audio & transcribing dialogue';
              final eta = progressState?.etaText ?? '~15-30 sec';

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Header Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.textLink,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI Voice Dubbing Progress',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Target Language: $langName',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        tooltip: 'Close',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Progress & ETA Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2E2E34)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Overall Progress: $progress%',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.bgSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    color: AppColors.textLink,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    eta,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textLink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (progress / 100.0).clamp(0.05, 1.0),
                            backgroundColor: AppColors.bgSurface,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.info),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.textLink),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                stageTitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textLink,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Pipeline Stages Breakdown (What's Next)
                  const Text(
                    'Dubbing Pipeline Stages',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildStageItem(
                    stepNumber: '1',
                    title: 'Speech Extraction & Transcription',
                    desc: 'Analyzes original video dialogue, timestamps, and acoustic pacing.',
                    isCurrent: currentStep == 1,
                    isDone: currentStep > 1,
                  ),
                  const SizedBox(height: 8),

                  _buildStageItem(
                    stepNumber: '2',
                    title: 'Nuance-Preserving AI Translation',
                    desc: 'Translates speech into $langName matching creator tone and idioms.',
                    isCurrent: currentStep == 2,
                    isDone: currentStep > 2,
                  ),
                  const SizedBox(height: 8),

                  _buildStageItem(
                    stepNumber: '3',
                    title: 'Neural Voice Synthesis & Dubbing',
                    desc: 'Generates studio-quality vocal tracks with natural cadence and inflection.',
                    isCurrent: currentStep == 3,
                    isDone: currentStep > 3,
                  ),
                  const SizedBox(height: 8),

                  _buildStageItem(
                    stepNumber: '4',
                    title: 'Studio Mastering & Synchronization',
                    desc: 'Applies smart audio ducking and syncs timeline at 44.1/48kHz.',
                    isCurrent: currentStep == 4,
                    isDone: false,
                  ),

                  const SizedBox(height: 16),

                  // Background Notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.bgSurface),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.textLink,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Generation continues in the cloud even if you leave this tab or switch studio pages. Your audio track will automatically appear ready here when completed.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => controller.checkDubbingStatus(langCode),
                        icon: const Icon(Icons.sync_rounded, size: 16, color: AppColors.textLink),
                        label: const Text(
                          'Check Status',
                          style: TextStyle(
                            color: AppColors.textLink,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.info),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          controller.retryDubbing(langCode);
                        },
                        child: const Text(
                          'Retry',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Got It',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
            }),
          ),
        );
      },
    );
  }

  static Widget _buildStageItem({
    required String stepNumber,
    required String title,
    required String desc,
    required bool isCurrent,
    required bool isDone,
  }) {
    final Color badgeBg;
    final Color badgeTextColor;
    final Widget badgeChild;

    if (isDone) {
      badgeBg = AppColors.success.withValues(alpha: 0.2);
      badgeTextColor = AppColors.success;
      badgeChild = const Icon(Icons.check_rounded, color: AppColors.success, size: 14);
    } else if (isCurrent) {
      badgeBg = AppColors.info;
      badgeTextColor = Colors.white;
      badgeChild = const SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    } else {
      badgeBg = AppColors.bgSurface;
      badgeTextColor = AppColors.textSecondary;
      badgeChild = Text(
        stepNumber,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeTextColor),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.info.withValues(alpha: 0.08)
            : const Color(0xFF121214),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent
              ? AppColors.info.withValues(alpha: 0.4)
              : const Color(0xFF222226),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: badgeChild,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isCurrent
                              ? AppColors.textLink
                              : (isDone ? Colors.white : AppColors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isDone
                          ? 'Completed'
                          : (isCurrent ? 'In Progress' : 'Upcoming'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDone
                            ? AppColors.success
                            : (isCurrent ? AppColors.textLink : AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Displays Studio Download modal for downloading video with selected language audio track,
  /// supporting dynamic switching between English, Hindi, Telugu, Tamil, and other available languages.
  static void showDubbedVideoDownloadModal({
    required BuildContext context,
    required Video video,
    required AudioTrackOption? track,
    required String langLabel,
    required String cleanTitle,
    required bool isBaseTrack,
    required String dubbedVideoUrl,
    required String audioUrl,
    required AudioTracksController tracksController,
    List<AudioTrackOption>? availableTracks,
  }) {
    // Collect all available tracks
    final tracks = (availableTracks != null && availableTracks.isNotEmpty)
        ? availableTracks
        : MultilingualStudioPlayerController.buildTrackOptions(
            video: video,
            tracksController: tracksController,
          );

    final initialCode = track?.code ?? video.language;
    final selectedLangCode = initialCode.obs;

    Get.bottomSheet<void>(
      Material(
        color: AppColors.appBarSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header with reactive language label
                  Obx(() {
                    final currentCode = selectedLangCode.value;
                    final currentTrack = tracks.firstWhereOrNull((t) => t.code == currentCode);
                    final currentLabel = currentTrack?.label ??
                        tracksController.getLanguageName(currentCode);

                    return Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.bgSurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Download $currentLabel Media',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Select wanted language format for ${video.title}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          onPressed: () => Get.back<void>(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    );
                  }),

                  const SizedBox(height: 14),

                  // Language Switcher Selector Bar
                  if (tracks.length > 1) ...[
                    const Text(
                      'Select Language',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Obx(() {
                      final currentCode = selectedLangCode.value;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (int i = 0; i < tracks.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              _buildModalLanguagePill(
                                label: tracks[i].label,
                                isSelected: tracks[i].code == currentCode,
                                onTap: () => selectedLangCode.value = tracks[i].code,
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  const Divider(height: 1, color: AppColors.bgSurface),
                  const SizedBox(height: 14),

                  // Reactive Main Download Options for Selected Language
                  Obx(() {
                    final currentCode = selectedLangCode.value;
                    final currentTrack = tracks.firstWhereOrNull((t) => t.code == currentCode);
                    final currentLabel = currentTrack?.label ??
                        tracksController.getLanguageName(currentCode);

                    final currentDubbed = currentTrack?.videoUrl ??
                        video.dubbedVideos[currentCode] ??
                        (currentCode == track?.code ? dubbedVideoUrl : '');

                    final currentAudio = currentTrack?.audioUrl ??
                        video.audioTracks[currentCode] ??
                        (currentCode == track?.code ? audioUrl : '');

                    final isBase = currentTrack?.isEmbedded == true ||
                        currentCode == video.language ||
                        currentCode == '__original__';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Option 1: Video (.mp4) with active language audio
                        InkWell(
                          onTap: () async {
                            Get.back<void>();
                            await StudioMediaDownloadService.downloadDubbedVideo(
                              video: video,
                              langCode: currentCode,
                              langLabel: currentLabel,
                              cleanTitle: cleanTitle,
                              track: currentTrack,
                              tracksController: tracksController,
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.bgPage,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.bgSurface),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.movie_creation_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Download Video with $currentLabel Audio (.mp4)',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        currentDubbed.isNotEmpty
                                            ? 'High-definition video rendered with $currentLabel audio stream'
                                            : (isBase
                                                ? 'Original video with native $currentLabel master audio'
                                                : 'Complete MP4 video rendered with $currentLabel audio track'),
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Video',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Option 2: Isolated Audio Track (.mp3)
                        if (currentAudio.isNotEmpty || isBase)
                          InkWell(
                            onTap: () async {
                              Get.back<void>();
                              await StudioMediaDownloadService.downloadAudioTrack(
                                video: video,
                                langCode: currentCode,
                                langLabel: currentLabel,
                                cleanTitle: cleanTitle,
                                track: currentTrack,
                                tracksController: tracksController,
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.bgPage,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.bgSurface),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.audiotrack_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Download $currentLabel Audio Track Only (.mp3)',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        const Text(
                                          'High-fidelity isolated audio stream for podcasting or studio mixing',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgSurface,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Audio',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  }),

                  // All Available Languages Quick-Download Section
                  if (tracks.length > 1) ...[
                    const SizedBox(height: 18),
                    const Divider(height: 1, color: AppColors.bgSurface),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Icon(Icons.translate_rounded, size: 15, color: AppColors.textSecondary),
                        SizedBox(width: 6),
                        Text(
                          'All Available Languages',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...tracks.map((t) {
                      final hasAudio = (t.audioUrl != null && t.audioUrl!.isNotEmpty) ||
                          (video.audioTracks[t.code]?.isNotEmpty ?? false) ||
                          t.isEmbedded ||
                          t.code == video.language;

                      // Provide MP4 Video for ALL languages that have an Audio Track
                      final hasVideo = hasAudio ||
                          (t.videoUrl != null && t.videoUrl!.isNotEmpty) ||
                          (video.dubbedVideos[t.code]?.isNotEmpty ?? false) ||
                          t.isEmbedded ||
                          t.code == video.language;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.bgPage,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.bgSurface),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    t.isEmbedded
                                        ? 'Original master'
                                        : (hasAudio ? 'Dubbed video & audio' : 'Video track'),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (hasVideo) ...[
                              InkWell(
                                onTap: () async {
                                  Get.back<void>();
                                  await StudioMediaDownloadService.downloadDubbedVideo(
                                    video: video,
                                    langCode: t.code,
                                    langLabel: t.label,
                                    cleanTitle: cleanTitle,
                                    track: t,
                                    tracksController: tracksController,
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'MP4 Video',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (hasAudio)
                              InkWell(
                                onTap: () async {
                                  Get.back<void>();
                                  await StudioMediaDownloadService.downloadAudioTrack(
                                    video: video,
                                    langCode: t.code,
                                    langLabel: t.label,
                                    cleanTitle: cleanTitle,
                                    track: t,
                                    tracksController: tracksController,
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgSurface,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: const Text(
                                    'MP3 Audio',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  static Widget _buildModalLanguagePill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    if (isSelected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
