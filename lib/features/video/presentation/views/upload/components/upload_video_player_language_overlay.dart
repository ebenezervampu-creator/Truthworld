import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_multi_language_picker_sheet.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/upload_add_language_options_sheet.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/upload_generate_subtitles_sheet.dart';
import 'package:truthworld/features/video/presentation/views/upload/pages/upload_audio_track_dubbing_page.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Floating multi-language switcher pills overlay positioned over the video preview player
/// in Step 2 (Video File), exactly matching the Audio Tracks Studio player overlay.
class UploadVideoPlayerLanguageOverlay extends StatelessWidget {
  const UploadVideoPlayerLanguageOverlay({
    required this.controller,
    required this.isDarkMode,
    super.key,
  });

  final UploadController controller;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final baseCode = controller.effectiveVideoLanguage.trim().toLowerCase();
      final baseName = controller.getLanguageName(baseCode);
      final activePreview = controller.activePreviewLanguage.value.trim().toLowerCase();
      final isBaseActive = activePreview.isEmpty || activePreview == baseCode;

      // Extract all added target language codes (excluding base language)
      final addedCodes = <String>{};
      for (final l in controller.aiDubbingLanguages) {
        final c = l.trim().toLowerCase();
        if (c.isNotEmpty && c != baseCode) addedCodes.add(c);
      }
      for (final l in controller.aiTranslationLanguages) {
        final c = l.trim().toLowerCase();
        if (c.isNotEmpty && c != baseCode) addedCodes.add(c);
      }
      for (final l in controller.attachedAudioFiles.keys) {
        final c = l.trim().toLowerCase();
        if (c.isNotEmpty && c != baseCode) addedCodes.add(c);
      }
      for (final l in controller.attachedSubtitleFiles.keys) {
        final c = l.trim().toLowerCase();
        if (c.isNotEmpty && c != baseCode) addedCodes.add(c);
      }

      final sortedAddedCodes = addedCodes.toList();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        alignment: Alignment.bottomCenter,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Original Spoken Base Language Pill (Solid White when active)
              _buildOriginalLanguagePill(
                context: context,
                baseName: baseName,
                isActive: isBaseActive,
                onTap: () {
                  if (!isBaseActive) {
                    controller.activePreviewLanguage.value = '';
                  } else {
                    showSpokenLanguagePicker(
                      context: context,
                      controller: controller,
                    );
                  }
                },
              ),

              // 2. Added Staged Language Pills
              for (final langCode in sortedAddedCodes) ...[
                const SizedBox(width: 6),
                _buildAddedLanguagePill(
                  context: context,
                  langCode: langCode,
                  isActive: activePreview == langCode,
                  onTap: () => _showTrackDetailsModal(context, langCode),
                ),
              ],

              // 3. + Language Pill
              const SizedBox(width: 6),
              _buildAddLanguagePill(
                onTap: () => showUploadAddLanguageOptionsSheet(
                  context: context,
                  controller: controller,
                  isDarkMode: isDarkMode,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ORIGINAL SPOKEN LANGUAGE PILL
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildOriginalLanguagePill({
    required BuildContext context,
    required String baseName,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    if (isActive) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                baseName,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: Colors.black, size: 16),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Text(
          baseName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ADDED LANGUAGE PILL (With CC / Audio / Queued indicators)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildAddedLanguagePill({
    required BuildContext context,
    required String langCode,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final clean = langCode.trim().toLowerCase();
    final name = controller.getLanguageName(clean);

    final hasAiDub = controller.aiDubbingLanguages.any((l) => l.trim().toLowerCase() == clean);
    final hasAiSub = controller.aiTranslationLanguages.any((l) => l.trim().toLowerCase() == clean);
    final hasDeviceAudio = controller.attachedAudioFiles.containsKey(clean);
    final hasDeviceSub = controller.attachedSubtitleFiles.containsKey(clean);

    final isAudioTrack = hasAiDub || hasDeviceAudio;
    final isSubtitleTrack = hasAiSub || hasDeviceSub;
    final isQueuedAi = (hasAiDub && !hasDeviceAudio) || (hasAiSub && !hasDeviceSub);

    final bgColor = isActive ? Colors.white : Colors.black.withOpacity(0.65);
    final fgColor = isActive ? Colors.black : Colors.white;
    final borderColor = isActive ? Colors.white : Colors.white.withOpacity(0.25);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: isActive
              ? const [
                  BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: TextStyle(
                color: fgColor,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: 5),
            if (isAudioTrack) ...[
              Icon(Icons.volume_up_rounded, color: fgColor, size: 13),
              const SizedBox(width: 3),
            ],
            if (isSubtitleTrack) ...[
              Icon(Icons.subtitles_rounded, color: fgColor, size: 13),
              const SizedBox(width: 3),
            ],
            if (isQueuedAi) ...[
              Container(
                margin: const EdgeInsets.only(left: 2),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isActive ? Colors.black.withOpacity(0.12) : Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Queued',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: fgColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // + LANGUAGE PILL
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildAddLanguagePill({required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text(
              '+ Language',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TRACK DETAILS & ACTION MODAL
  // ───────────────────────────────────────────────────────────────────────────
  void _showTrackDetailsModal(BuildContext context, String langCode) {
    final clean = langCode.trim().toLowerCase();
    final name = controller.getLanguageName(clean);

    final hasAiDub = controller.aiDubbingLanguages.any((l) => l.trim().toLowerCase() == clean);
    final hasAiSub = controller.aiTranslationLanguages.any((l) => l.trim().toLowerCase() == clean);
    final hasDeviceAudio = controller.attachedAudioFiles.containsKey(clean);
    final hasDeviceSub = controller.attachedSubtitleFiles.containsKey(clean);

    final isQueuedAi = (hasAiDub && !hasDeviceAudio) || (hasAiSub && !hasDeviceSub);
    final attachedRole = controller.attachedAudioRoles[clean] ?? 'Dubbed Audio';

    Get.bottomSheet<void>(
      Material(
        color: AppColors.bgPage,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$name Track Options',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Get.back<void>(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasAiDub) ...[
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, color: Color(0xFFA78BFA), size: 16),
                            SizedBox(width: 8),
                            Text(
                              'AI Voice Dubbing (Queued on upload)',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (hasAiSub) ...[
                        const Row(
                          children: [
                            Icon(Icons.subtitles, color: Color(0xFF60A5FA), size: 16),
                            SizedBox(width: 8),
                            Text(
                              'AI Subtitles & Captions (Queued on upload)',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (hasDeviceAudio) ...[
                        Row(
                          children: [
                            const Icon(Icons.audiotrack, color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Device Audio: ${controller.attachedAudioFiles[clean]?.name ?? ""} ($attachedRole)',
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (hasDeviceSub) ...[
                        Row(
                          children: [
                            const Icon(Icons.upload_file, color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Device Subtitle: ${controller.attachedSubtitleFiles[clean]?.name ?? ""}',
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Edit settings (for AI)
                if (isQueuedAi) ...[
                  ListTile(
                    leading: const Icon(Icons.tune_rounded, color: Colors.white),
                    title: const Text('Edit AI Generation Settings', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Get.back<void>();
                      if (hasAiDub) {
                        Get.to(() => UploadAudioTrackDubbingPage(initialLangCode: clean));
                      } else {
                        showUploadGenerateSubtitlesSheet(
                          context: context,
                          controller: controller,
                          isDarkMode: isDarkMode,
                          initialLangCode: clean,
                        );
                      }
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    tileColor: AppColors.bgSurface,
                  ),
                  const SizedBox(height: 10),
                ],
                // Remove Track
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: Text('Remove $name Track', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Get.back<void>();
                    controller.removeLanguageTrack(clean);
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  tileColor: AppColors.bgSurface,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
