import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_multi_language_picker_sheet.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Interactive modal sheet for configuring and staging AI Subtitles during video upload.
/// Matches the Subtitles studio experience with multi-language selection, search,
/// and instant staging into the video player overlay.
void showUploadGenerateSubtitlesSheet({
  required BuildContext context,
  required UploadController controller,
  required bool isDarkMode,
  String? initialLangCode,
}) {
  final baseLang = controller.effectiveVideoLanguage.trim().toLowerCase();
  final selectedLanguages = <String>{...controller.aiTranslationLanguages}.obs;

  if (initialLangCode != null && initialLangCode.trim().isNotEmpty) {
    selectedLanguages.add(initialLangCode.trim().toLowerCase());
  }

  final search = ''.obs;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Material(
        color: const Color(0xFF16171E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Generate Subtitles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Auto-generate multi-language subtitles & captions with AI.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),

                // Search Box
                TextField(
                  onChanged: (val) => search.value = val.trim().toLowerCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Search target subtitle languages...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13.5),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                    filled: true,
                    fillColor: const Color(0xFF222430),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Selected Count Chips bar
                Obx(() {
                  final count = selectedLanguages.length;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        count == 0
                            ? 'Select 1 or more languages'
                            : '$count ${count == 1 ? "language" : "languages"} selected',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (count > 0)
                        GestureDetector(
                          onTap: selectedLanguages.clear,
                          child: const Text(
                            'Clear All',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                    ],
                  );
                }),

                const SizedBox(height: 10),

                // Language Grid / List
                Expanded(
                  child: Obx(() {
                    final q = search.value;
                    final candidates = controller.supportedLanguagesList
                        .where((l) => l.code.toLowerCase() != baseLang)
                        .where((l) {
                      if (q.isEmpty) return true;
                      return l.name.toLowerCase().contains(q) ||
                          l.nativeName.toLowerCase().contains(q) ||
                          l.code.toLowerCase().contains(q);
                    }).toList();

                    if (candidates.isEmpty) {
                      return const Center(
                        child: Text('No languages match search', style: TextStyle(color: Colors.white38)),
                      );
                    }

                    return ListView.separated(
                      itemCount: candidates.length,
                      separatorBuilder: (ctx, idx) => const Divider(color: Color(0xFF222430), height: 1),
                      itemBuilder: (_, index) {
                        final lang = candidates[index];
                        final code = lang.code.toLowerCase();
                        final isSelected = selectedLanguages.contains(code);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          leading: buildLanguageFlag(lang.name),
                          title: Text(
                            lang.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13.5,
                            ),
                          ),
                          subtitle: lang.nativeName.isNotEmpty && lang.nativeName != lang.name
                              ? Text(
                                  lang.nativeName,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                )
                              : null,
                          trailing: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? Colors.white : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.white38,
                                width: 1.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 13, color: Colors.black)
                                : null,
                          ),
                          onTap: () {
                            if (isSelected) {
                              selectedLanguages.remove(code);
                            } else {
                              selectedLanguages.add(code);
                            }
                          },
                        );
                      },
                    );
                  }),
                ),

                const SizedBox(height: 14),

                // Solid white action button
                Obx(() {
                  final count = selectedLanguages.length;
                  return SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.auto_awesome, color: Colors.black87, size: 18),
                      label: Text(
                        count == 0
                            ? 'Select Languages'
                            : 'Generate Subtitles ($count)',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: count == 0
                          ? null
                          : () {
                              for (final code in selectedLanguages) {
                                if (!controller.aiTranslationLanguages.contains(code)) {
                                  controller.toggleSubtitleLanguage(code);
                                }
                              }
                              // Remove unselected ones if user removed them in sheet
                              final toRemove = controller.aiTranslationLanguages
                                  .where((code) => !selectedLanguages.contains(code))
                                  .toList();
                              toRemove.forEach(controller.toggleSubtitleLanguage);
                              controller.aiGenerateSubtitles.value = controller.aiTranslationLanguages.isNotEmpty;
                              Navigator.pop(ctx);
                              AppSnackbar.success('Queued ${selectedLanguages.length} subtitle languages on upload.');
                            },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );
    },
  );
}
