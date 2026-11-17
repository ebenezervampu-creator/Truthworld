import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_multi_language_picker_sheet.dart';

/// Clean, high-contrast Spoken Video Language ("From") Selector Card.
/// Shared across Subtitles and Dubbing studios.
/// Supports the exact 18 languages powered by AssemblyAI Universal-3.5 Pro (+ Auto-Detect).
class SpokenLanguageSelectorCard extends StatelessWidget {
  final UploadController controller;
  final String title;
  final String subtitle;

  const SpokenLanguageSelectorCard({
    required this.controller,
    this.title = 'Spoken Video Language ("From")',
    this.subtitle = 'Speech recognition strictly supports 18 languages via AssemblyAI Universal-3.5 Pro',
    super.key,
  });

  static const List<Map<String, String>> popularLanguages = [
    {'code': 'auto', 'name': 'Auto-Detect', 'native': 'Auto'},
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
    {'code': 'es', 'name': 'Spanish', 'native': 'Español'},
    {'code': 'fr', 'name': 'French', 'native': 'Français'},
    {'code': 'de', 'name': 'German', 'native': 'Deutsch'},
    {'code': 'zh', 'name': 'Chinese', 'native': '中文'},
    {'code': 'ja', 'name': 'Japanese', 'native': '日本語'},
    {'code': 'ar', 'name': 'Arabic', 'native': 'العربية'},
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentPrimary = controller.primarySpokenLanguage.value.isEmpty
          ? 'auto'
          : controller.primarySpokenLanguage.value;
      final isMultilingual = controller.isMultilingualSpoken.value;
      final selectedSpoken = controller.spokenLanguages;
      final match = allSpokenLanguages.firstWhereOrNull((l) => l.code == currentPrimary);
      final displayName = match != null
          ? (match.code == 'auto' ? match.name : '${match.name} (${match.nativeName})')
          : currentPrimary.toUpperCase();

      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF14151B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.record_voice_over_rounded,
                    color: Color(0xFF38BDF8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 1. Country-Selection-Style Trigger Field (Channel Creation Style)
            GestureDetector(
              onTap: () => showSpokenLanguagePicker(
                context: context,
                controller: controller,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Row(
                  children: [
                    buildLanguageFlag(
                      match != null && match.code != 'auto' ? match.name : 'English',
                      width: 24,
                      height: 16,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 2. Quick Popular Language Shortcut Pills
            Builder(
              builder: (context) {
                final displayedChips = <Map<String, String>>[...popularLanguages];
                if (!displayedChips.any((l) => l['code'] == currentPrimary)) {
                  if (match != null) {
                    displayedChips.add({
                      'code': match.code,
                      'name': match.name,
                      'native': match.nativeName,
                    });
                  }
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ...displayedChips.map((lang) {
                      final code = lang['code']!;
                      final isSelected = currentPrimary == code;
                      final label = lang['native'] != lang['name'] && code != 'auto'
                          ? '${lang['name']} (${lang['native']})'
                          : lang['name']!;

                      return InkWell(
                        onTap: () {
                          controller.primarySpokenLanguage.value = code;
                          if (code != 'auto' && !controller.spokenLanguages.contains(code)) {
                            controller.spokenLanguages.insert(0, code);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0284C7).withValues(alpha: 0.25)
                                : const Color(0xFF1F2029),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFF2C2E3C),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8), size: 13),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                label,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    InkWell(
                      onTap: () => showSpokenLanguagePicker(
                        context: context,
                        controller: controller,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2029),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search, color: Color(0xFF38BDF8), size: 13),
                            SizedBox(width: 4),
                            Text(
                              'Browse (18 Languages)',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 14),

            // More than 1 spoken language (Code-Mixed / Multilingual) Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1C24),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.alt_route_rounded,
                    color: Color(0xFFA78BFA),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Video has more than 1 spoken language',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'e.g. Telugu speech code-mixed with English, or polyglot interviews',
                          style: TextStyle(
                            color: Color(0xFFA1A1AA),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isMultilingual,
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF7C3AED),
                    inactiveThumbColor: Colors.white38,
                    inactiveTrackColor: Colors.white10,
                    onChanged: (val) {
                      controller.isMultilingualSpoken.value = val;
                      if (val && selectedSpoken.isEmpty && currentPrimary != 'auto') {
                        selectedSpoken.add(currentPrimary);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
