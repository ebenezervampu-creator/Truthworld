import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

  void showGenerateAIFeaturesDialog(
    BuildContext context,
    Video video,
    VideoManagementController controller,
  ) {
    final selectedLangs = <String>{'te', 'hi'}.obs;
    final selectedFeatures = <String>{
      'subtitles',
      'dubbing',
      'factcheck',
      'summary',
      'chapters',
    }.obs;
    final isAccuracyMode = true.obs;
    final showAdvanced = false.obs;

    final availableLangs = [
      {'code': 'te', 'name': 'Telugu (తెలుగు)'},
      {'code': 'hi', 'name': 'Hindi (हिन्दी)'},
      {'code': 'en', 'name': 'English'},
      {'code': 'ta', 'name': 'Tamil (தமிழ்)'},
      {'code': 'kn', 'name': 'Kannada (ಕನ್ನಡ)'},
      {'code': 'ml', 'name': 'Malayalam (മലയാളം)'},
      {'code': 'es', 'name': 'Spanish'},
    ];

    Get.dialog<void>(
      Dialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Obx(
                () => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.textPrimary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'AI Features & Advanced Settings',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: Get.back<void>,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Generate subtitles, dubbed audio tracks, fact-checking, AI summaries, and chapters anytime on demand.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const Divider(height: 24),

                    // Section 1: Target Languages
                    Text(
                      'Select Target Languages',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableLangs.map((lang) {
                        final code = lang['code']!;
                        final name = lang['name']!;
                        final isSelected = selectedLangs.contains(code);
                        return FilterChip(
                          label: Text(name),
                          selected: isSelected,
                          selectedColor: AppColors.brand.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.brand,
                          labelStyle: AppTextStyles.labelMedium.copyWith(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.brand
                                : AppColors.textPrimary,
                          ),
                          onSelected: (val) {
                            if (val) {
                              selectedLangs.add(code);
                            } else {
                              if (selectedLangs.length > 1) {
                                selectedLangs.remove(code);
                              }
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Section 2: AI Capabilities
                    Text(
                      'Select AI Features to Generate',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    buildFeatureCheckbox(
                      title: 'Subtitles & Closed Captions (SRT/VTT)',
                      subtitle:
                          'Generate native subtitles in selected target languages',
                      icon: Icons.subtitles_outlined,
                      value: selectedFeatures.contains('subtitles'),
                      onChanged: (val) {
                        if (val ?? false) {
                          selectedFeatures.add('subtitles');
                        } else {
                          selectedFeatures.remove('subtitles');
                        }
                      },
                    ),
                    buildFeatureCheckbox(
                      title: 'AI Audio Dubbing Tracks',
                      subtitle:
                          'Generate natural AI voice tracks in Telugu, Hindi, etc.',
                      icon: Icons.record_voice_over_outlined,
                      value: selectedFeatures.contains('dubbing'),
                      onChanged: (val) {
                        if (val ?? false) {
                          selectedFeatures.add('dubbing');
                        } else {
                          selectedFeatures.remove('dubbing');
                        }
                      },
                    ),
                    buildFeatureCheckbox(
                      title: 'Fact-Checking & Truth Score Report',
                      subtitle:
                          'Extract claims & verify truthfulness with citations',
                      icon: Icons.fact_check_outlined,
                      value: selectedFeatures.contains('factcheck'),
                      onChanged: (val) {
                        if (val ?? false) {
                          selectedFeatures.add('factcheck');
                        } else {
                          selectedFeatures.remove('factcheck');
                        }
                      },
                    ),
                    buildFeatureCheckbox(
                      title: 'AI Video Summary & Key Takeaways',
                      subtitle: 'Generate concise summary of video content',
                      icon: Icons.auto_stories_outlined,
                      value: selectedFeatures.contains('summary'),
                      onChanged: (val) {
                        if (val ?? false) {
                          selectedFeatures.add('summary');
                        } else {
                          selectedFeatures.remove('summary');
                        }
                      },
                    ),
                    buildFeatureCheckbox(
                      title: 'Timestamped Auto-Chapters',
                      subtitle: 'Detect topics and create chapter timestamps',
                      icon: Icons.bookmarks_outlined,
                      value: selectedFeatures.contains('chapters'),
                      onChanged: (val) {
                        if (val ?? false) {
                          selectedFeatures.add('chapters');
                        } else {
                          selectedFeatures.remove('chapters');
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Section 3: Advanced Settings Accordion
                    InkWell(
                      onTap: () => showAdvanced.value = !showAdvanced.value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.settings_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Advanced Settings',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              showAdvanced.value
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showAdvanced.value) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurfaceHover,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Priority Mode',
                                      style: AppTextStyles.labelMedium.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      isAccuracyMode.value
                                          ? 'Accuracy Mode (Universal-3 Pro + Grounding)'
                                          : 'Fast Mode (Draft)',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: isAccuracyMode.value,
                                  activeTrackColor: AppColors.brand,
                                  onChanged: (val) =>
                                      isAccuracyMode.value = val,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurfaceHover,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.bgDivider),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Funding Source:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                r'Channel Revenue & $10 Trial Credit',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Estimated Cost:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '\$${ChannelWalletService.calculateAIFeatureCost(selectedFeatures: selectedFeatures.toSet(), targetLanguages: selectedLangs.toList()).toStringAsFixed(2)}',
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: Get.back<void>,
                          child: Text(
                            'Cancel',
                            style: AppTextStyles.buttonText.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.black,
                            size: 18,
                          ),
                          label: Text(
                            'Generate & Pay from Balance',
                            style: AppTextStyles.buttonText.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: selectedFeatures.isEmpty
                              ? null
                              : () {
                                  Get.back<void>();
                                  controller.triggerAIFeatures(
                                    videoId: video.id,
                                    features: selectedFeatures.toList(),
                                    targetLanguages: selectedLangs.toList(),
                                    priorityMode: isAccuracyMode.value
                                        ? 'accuracy'
                                        : 'speed',
                                    autoChapters: selectedFeatures.contains(
                                      'chapters',
                                    ),
                                  );
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildFeatureCheckbox({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.brand,
      dense: true,
      contentPadding: EdgeInsets.zero,
      secondary: Icon(
        icon,
        color: Colors.white,
        size: 22,
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }
