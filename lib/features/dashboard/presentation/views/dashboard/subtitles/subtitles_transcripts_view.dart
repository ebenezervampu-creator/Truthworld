import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/dialogs/generate_ai_subtitles_modal.dart';
import 'package:truthworld/theme/app_theme.dart';

class SubtitlesTranscriptsView extends StatelessWidget {
  const SubtitlesTranscriptsView({
    required this.controller,
    required this.isDarkMode,
    super.key,
  });

  final SubtitlesController controller;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    const primaryText = AppColors.textPrimary;
    const secondaryText = AppColors.textSecondary;
    const cardColor = AppColors.bgSurface;
    const borderColor = AppColors.bgDivider;

    final searchRx = ''.obs;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Obx(() {
            final code = controller.selectedLanguage.value;
            var langName = controller.getLanguageName(code);
            if (code == 'en') {
              langName = 'English (Original)';
            }
            final availableLangs = controller.configuredLanguages;
            final currentCode = availableLangs.contains(code)
                ? code
                : (availableLangs.isNotEmpty ? availableLangs.first : code);

            return Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Transcript: $langName',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                        if (availableLangs.length > 1) ...[
                          const SizedBox(width: 10),
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: AppColors.bgPage,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF3E3E3E)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: currentCode.isNotEmpty ? currentCode : null,
                                dropdownColor: AppColors.bgSurface,
                                icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 20),
                                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                                items: availableLangs.map((lCode) {
                                  final isBase = lCode == normalizeLanguageCode(controller.selectedVideo.value?.language ?? 'en');
                                  final name = controller.getLanguageName(lCode, includeNative: true);
                                  final label = isBase ? '$name (Original)' : name;
                                  return DropdownMenuItem<String>(
                                    value: lCode,
                                    child: Text(
                                      label,
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newLang) {
                                  if (newLang != null && newLang.isNotEmpty) {
                                    controller.switchLanguage(newLang);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _copyFullTranscript(context),
                  icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.white),
                  label: const Text(
                    'Copy text',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3E3E3E)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => controller.downloadTxtTrack(),
                  icon: const Icon(Icons.download_rounded, size: 14, color: Colors.white),
                  label: const Text(
                    'Download TXT',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3E3E3E)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 12),

          // Search Field
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              maxLength: 100,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: TruthworldTextInputFormatters.withLimit(100),
              style: const TextStyle(fontSize: 13, color: primaryText),
              decoration: const InputDecoration(
                hintText: 'Search transcript sentences...',
                hintStyle: TextStyle(fontSize: 13, color: secondaryText),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: secondaryText),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (val) => searchRx.value = val,
            ),
          ),
          const SizedBox(height: 12),

          // Transcript Content
          Expanded(
            child: Obx(() {
              final cues = controller.currentCues;
              final query = searchRx.value.toLowerCase().trim();

              if (cues.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.article_outlined,
                          size: 48,
                          color: Colors.white38,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No transcript available for this track',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Auto-generate transcripts with TruthWorld AI or add subtitle captions.',
                          style: TextStyle(fontSize: 13, color: secondaryText),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            GenerateAiSubtitlesModal.show(
                              context,
                              controller,
                              isDarkMode: isDarkMode,
                            );
                          },
                          icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                          label: const Text('Generate with AI'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.bgSurface,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final filtered = query.isEmpty
                  ? cues
                  : cues.where((c) => c.text.toLowerCase().contains(query)).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text(
                    'No sentences match your search.',
                    style: TextStyle(color: secondaryText, fontSize: 14),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(12),
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final cue = filtered[index];
                    final isActive = controller.activeCueIndex.value >= 0 &&
                        controller.activeCueIndex.value < cues.length &&
                        cues[controller.activeCueIndex.value].id == cue.id;

                    return InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        final originalIdx = cues.indexWhere((c) => c.id == cue.id);
                        if (originalIdx != -1) {
                          controller.seekToCue(originalIdx);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF1D2F44) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isActive ? AppColors.textLink : Colors.transparent,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.bgSurface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                cue.startTime.split('.').first,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textLink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                cue.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: isActive ? Colors.white : primaryText,
                                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _copyFullTranscript(BuildContext context) {
    if (controller.currentCues.isEmpty) {
      Get.snackbar('Notice', 'No transcript text available to copy.');
      return;
    }
    final fullText = controller.currentCues.map((c) => c.text).join(' ');
    Clipboard.setData(ClipboardData(text: fullText));
    Get.snackbar(
      'Copied',
      'Full transcript copied to clipboard.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.bgSurface,
      colorText: Colors.white,
    );
  }
}
