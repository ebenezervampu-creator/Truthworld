import 'package:truthworld/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_options_state.dart';

/// Clean, minimal ElevenLabs-style Target Language selector.
class DubbingLanguageBar extends StatelessWidget {
  const DubbingLanguageBar({
    required this.state,
    super.key,
  });

  final DubbingOptionsState state;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 440;
        final dropdownContent = Obx(() {
          final isVoiceCloned = state.voiceType.value == 'cloned';
          // Filter to only Cloud Chirp 3: HD supported languages when not using voice cloning
          final availableOptions = isVoiceCloned
              ? state.controller.supportedLanguages
              : state.controller.chirp3HdSupportedLanguages;

          final currentCode = state.selectedLangCode.value;
          final effectiveCode = availableOptions.any((l) => l.code == currentCode)
              ? currentCode
              : (availableOptions.isNotEmpty ? availableOptions.first.code : 'en');

          if (effectiveCode != currentCode) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              state.selectedLangCode.value = effectiveCode;
            });
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF18181C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A2A30)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: effectiveCode,
                dropdownColor: AppColors.appBarSurface,
                isDense: true,
                isExpanded: true,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 18),
                items: availableOptions.map((lang) {
                  return DropdownMenuItem<String>(
                    value: lang.code,
                    child: Text(
                      '${lang.name} (${lang.code.toUpperCase()})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: state.allowLanguageSwitch
                    ? (val) {
                        if (val != null) {
                          state.selectedLangCode.value = val;
                        }
                      }
                    : null,
              ),
            ),
          );
        });

        if (isNarrow) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.bgSurface),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.translate_rounded,
                      size: 16,
                      color: AppColors.textLink,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Target Language:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Obx(() {
                      if (state.voiceType.value != 'cloned') {
                        return Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: const Text(
                            'Chirp 3: HD',
                            style: TextStyle(
                              color: AppColors.textLink,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                dropdownContent,
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgPage,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.bgSurface),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.translate_rounded,
                size: 16,
                color: AppColors.textLink,
              ),
              const SizedBox(width: 8),
              const Text(
                'Target Language:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Obx(() {
                if (state.voiceType.value != 'cloned') {
                  return Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Text(
                      'Chirp 3: HD',
                      style: TextStyle(
                        color: AppColors.textLink,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
              const SizedBox(width: 12),
              Expanded(child: dropdownContent),
            ],
          ),
        );
      },
    );
  }
}
