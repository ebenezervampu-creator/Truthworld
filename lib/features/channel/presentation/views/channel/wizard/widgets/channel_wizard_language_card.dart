import 'package:flutter/material.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/language/channel_language_content.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/language/channel_languages_data.dart'
    as channel_lang_data;

export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/language/channel_invite_only_language_dialog.dart';
export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/language/channel_language_content.dart';
export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/language/channel_language_picker_sheet.dart';
export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/language/channel_languages_data.dart';

class ChannelWizardLanguageCard extends StatelessWidget {
  const ChannelWizardLanguageCard({
    required this.controller,
    required this.isDarkMode,
    this.contentOnly = false,
    super.key,
  });

  final ChannelController controller;
  final bool isDarkMode;
  final bool contentOnly;

  static const List<Map<String, dynamic>> worldLanguagesDescending =
      channel_lang_data.worldLanguagesDescending;

  @override
  Widget build(BuildContext context) {
    if (contentOnly) {
      return ChannelLanguageContent(
        controller: controller,
        isDarkMode: isDarkMode,
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '8. Language',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ChannelLanguageContent(
            controller: controller,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }
}
