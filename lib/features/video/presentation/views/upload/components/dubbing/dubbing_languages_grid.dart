import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_dubbing_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_multi_language_picker_sheet.dart';

/// Target Dubbing Languages Section featuring Country-Selection style trigger modal
/// and clean ElevenLabs selected language chips.
class DubbingLanguagesGrid extends StatelessWidget {
  const DubbingLanguagesGrid({required this.controller, super.key});
  final UploadDubbingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.public, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Target Dubbing Languages',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Select target languages for AI audio translation and neural voice localization.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),

        // Country-Selection-Style Trigger Field (Channel Creation Style)
        Obx(() {
          final count = controller.selectedLanguages.length;
          final hasSelection = count > 0;

          return InkWell(
            onTap: () => showDubbingMultiLanguagePicker(
              context: context,
              controller: controller,
            ),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF14151B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasSelection
                      ? const Color(0xFFA78BFA).withValues(alpha: 0.5)
                      : const Color(0xFF262834),
                  width: hasSelection ? 1.2 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.translate,
                      color: Color(0xFFA78BFA),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasSelection
                              ? '$count Target ${count == 1 ? "Language" : "Languages"} Configured'
                              : 'Select Dubbing Languages (70+ Available)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: hasSelection ? Colors.white : Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasSelection
                              ? 'Tap to add, remove, or modify languages'
                              : 'Tap to open multi-language country selector',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F212A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF2D303E)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasSelection ? 'Edit' : 'Browse',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 12),

        // Quick Presets Row
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildPresetButton(
              title: '+ Top 5 Global',
              onTap: controller.selectTopGlobal,
            ),
            _buildPresetButton(
              title: '+ Top Indic',
              onTap: controller.selectTopIndic,
            ),
            _buildPresetButton(
              title: '+ Top European',
              onTap: controller.selectTopEuropean,
            ),
            Obx(() {
              if (controller.selectedLanguages.isNotEmpty) {
                return InkWell(
                  onTap: controller.clearAll,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1F27),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF2E303E)),
                    ),
                    child: const Text(
                      'Clear All',
                      style: TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),

        const SizedBox(height: 14),

        // Selected Languages Chips (ElevenLabs Modern Aesthetic)
        Obx(() {
          final selectedItems = controller.selectedLanguagesList;
          if (selectedItems.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF121318),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF222430)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.language,
                    size: 28,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No dubbing languages selected yet',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "Browse" or pick a preset above to configure neural dubbing',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF14151B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF242632)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Selected Dubbing Languages (${selectedItems.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F212A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Selected (${selectedItems.length})',
                            style: const TextStyle(
                              color: Color(0xFFA1A1AA),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: controller.clearAll,
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              color: Color(0xFFA1A1AA),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedItems.map((lang) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1F27),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2E3140)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          buildLanguageFlag(lang.name, width: 20, height: 14),
                          const SizedBox(width: 7),
                          Text(
                            lang.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (lang.nativeName.isNotEmpty && lang.nativeName != lang.name) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${lang.nativeName})',
                              style: const TextStyle(
                                color: Color(0xFF8E90A2),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => controller.removeLanguage(lang.name),
                            borderRadius: BorderRadius.circular(10),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.close,
                                size: 13,
                                color: Color(0xFFA1A1AA),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPresetButton({
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF191A22),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2A2C3A)),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
