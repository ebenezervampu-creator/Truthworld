import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/language/channel_language_picker_sheet.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/language/channel_languages_data.dart';
import 'package:truthworld/theme/app_theme.dart';

class ChannelLanguageContent extends StatelessWidget {
  const ChannelLanguageContent({
    required this.controller,
    required this.isDarkMode,
    super.key,
  });

  final ChannelController controller;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select your channel language.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () {
            final selectedCode = controller.language.value.trim().toLowerCase();
            final langData = worldLanguagesDescending.firstWhere(
              (l) =>
                  (l['code'] as String? ?? '').toLowerCase() == selectedCode ||
                  (l['name'] as String? ?? '').toLowerCase() == selectedCode,
              orElse: () => {
                'name': controller.language.value.isNotEmpty
                    ? controller.language.value
                    : 'Select Language',
                'native': '',
                'code': selectedCode,
              },
            );

            final name = langData['name'] as String? ?? 'English';
            final native = langData['native'] as String? ?? '';
            final displayText = (native.isNotEmpty && native != name)
                ? '$name ($native)'
                : name;

            return GestureDetector(
              onTap: () => showLanguagePicker(context, controller),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.language,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
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
            );
          },
        ),
      ],
    );
  }
}
