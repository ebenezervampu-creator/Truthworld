import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/theme/app_theme.dart';

class GenerateAiSubtitlesModal {
  static void show(
    BuildContext context,
    SubtitlesController controller, {
    required bool isDarkMode,
  }) {
    final textColor = isDarkMode ? AppColors.textPrimary : Colors.black;
    final selectedLangs = <String>{'en', 'hi', 'te', 'es'}.obs;
    final priorityMode = 'standard'.obs;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Obx(() {
            final durationSecs = controller.selectedVideo.value?.durationSeconds ??
                controller.videoDuration.value.inSeconds;
            final cost = ChannelWalletService.calculateAIFeatureCost(
              selectedFeatures: {'subtitles'},
              targetLanguages: selectedLangs.toList(),
              durationSeconds: durationSecs > 0 ? durationSecs : 120,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 24,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Generate Subtitles with Truthworld AI',
                      style: AppTextStyles.pageTitle.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Transcribe spoken dialogue with speech recognition and automatically translate into 130+ languages.',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Priority Mode Selector
                Text(
                  'Processing Priority Mode',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Standard (Queue)'),
                        selected: priorityMode.value == 'standard',
                        onSelected: (s) {
                          if (s) priorityMode.value = 'standard';
                        },
                        selectedColor: const Color(0xFF8B5CF6),
                        labelStyle: TextStyle(
                          color: priorityMode.value == 'standard'
                              ? Colors.white
                              : textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('High Priority (Express)'),
                        selected: priorityMode.value == 'high',
                        onSelected: (s) {
                          if (s) priorityMode.value = 'high';
                        },
                        selectedColor: const Color(0xFF8B5CF6),
                        labelStyle: TextStyle(
                          color: priorityMode.value == 'high'
                              ? Colors.white
                              : textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quick Select / Target Languages Selection
                Row(
                  children: [
                    Text(
                      'Target Languages (${selectedLangs.length})',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        selectedLangs.addAll(['en', 'hi', 'te', 'ta', 'es', 'fr', 'de', 'ja']);
                      },
                      child: const Text('Select Popular', style: TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: selectedLangs.clear,
                      child: const Text('Clear', style: TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Multi-select Chips
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: supportedLanguages.map((lang) {
                        final isSel = selectedLangs.contains(lang.code);
                        return FilterChip(
                          label: Text('${lang.name} (${lang.nativeName})'),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) {
                              selectedLangs.add(lang.code);
                            } else {
                              selectedLangs.remove(lang.code);
                            }
                          },
                          selectedColor: const Color(0xFF8B5CF6),
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : textColor,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Cost summary & Action
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wallet_rounded, size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Estimated Wallet Cost:',
                        style: AppTextStyles.caption.copyWith(fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        '\$${cost.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: selectedLangs.isEmpty
                        ? null
                        : () {
                            Navigator.pop(context);
                            controller.triggerSubtitlesGeneration(
                              targetLanguages: selectedLangs.toList(),
                              priorityMode: priorityMode.value,
                            );
                          },
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Start AI Subtitle Pipeline',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          }),
        );
      },
    );
  }
}
