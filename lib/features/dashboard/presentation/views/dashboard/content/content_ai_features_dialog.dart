import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/channel_wallet_topup_sheet.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

  void showGenerateAIFeaturesDialog(
    BuildContext context,
    Video video,
    VideoManagementController controller, {
    ChannelType? channelType,
  }) {
    final effectiveChannelType = channelType ??
        (Get.isRegistered<DashboardController>()
            ? (Get.find<DashboardController>().currentChannel.value?.channelType ??
                ChannelType.standard)
            : ChannelType.standard);
    final isCustom = effectiveChannelType == ChannelType.custom;
    final currentChannel = Get.isRegistered<DashboardController>()
        ? Get.find<DashboardController>().currentChannel.value
        : null;

    final videoDurationSec = video.durationValue.inSeconds;
    final flatDubbingRate = ChannelWalletService.getFlatDubbingPricePerLanguage(
      durationSeconds: videoDurationSec,
      channelType: effectiveChannelType,
    );
    final dubbingTier =
        ChannelWalletService.getDubbingDurationTier(videoDurationSec);
    final selectedLangs = <String>{'te', 'hi'}.obs;
    final selectedFeatures = <String>{
      'subtitles',
      'dubbing',
      'factcheck',
      'chapters',
    }.obs;
    final selectedFactCheckTier = 'standard'.obs;
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
                              fontFamily: TWTypography.brandFamily,
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
                      title:
                          'AI Audio Dubbing (Flat \$${flatDubbingRate.toStringAsFixed(2)}/lang • ${dubbingTier.label})',
                      subtitle: isCustom
                          ? 'Dubbing is NOT free: Flat rate for ${videoDurationSec > 0 ? VideoDurationUtils.formatDurationSeconds(videoDurationSec) : "detected duration"}. Includes Studio Vocal Identity & Voice Cloning.'
                          : 'Dubbing is NOT free: Predictable flat pricing for ${videoDurationSec > 0 ? VideoDurationUtils.formatDurationSeconds(videoDurationSec) : "detected duration"} across chosen languages.',
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
                      title: 'Fact-Checking & Truth Report (FREE • All Claims Verified)',
                      subtitle:
                          'Epistemic verification & claim analysis for ${videoDurationSec > 0 ? VideoDurationUtils.formatDurationSeconds(videoDurationSec) : "detected duration"}.',
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
                    if (selectedFeatures.contains('factcheck')) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 36, bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fact-Checking Verification Level:',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: ChannelWalletService.factCheckDepthPlans.map((plan) {
                                final isSelected = selectedFactCheckTier.value == plan.id;
                                return FilterChip(
                                  label: const Text('All Claims Ground Truth (FREE)'),
                                  selected: isSelected,
                                  selectedColor: AppColors.brand.withValues(alpha: 0.2),
                                  checkmarkColor: AppColors.brand,
                                  labelStyle: AppTextStyles.labelMedium.copyWith(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? AppColors.brand : AppColors.textSecondary,
                                  ),
                                  backgroundColor: AppColors.bgSurfaceHover,
                                  side: BorderSide(
                                    color: isSelected ? AppColors.brand : AppColors.bgDivider,
                                  ),
                                  onSelected: (_) {
                                    selectedFactCheckTier.value = plan.id;
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                              Row(
                                children: [
                                  Text(
                                    isCustom
                                        ? 'Channel Wallet & Revenue (Custom Channel)'
                                        : 'Channel Wallet & Revenue',
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: isCustom ? AppColors.info : AppColors.success,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (currentChannel != null) ...[
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        ChannelWalletTopupSheet.show(
                                          context,
                                          channel: currentChannel,
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.brand,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '+ Add Money',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
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
                                '\$${ChannelWalletService.calculateAIFeatureCost(
                                  selectedFeatures: selectedFeatures.toSet(),
                                  targetLanguages: selectedLangs.toList(),
                                  durationSeconds: videoDurationSec,
                                  channelType: effectiveChannelType,
                                  factCheckTier: selectedFactCheckTier.value,
                                ).toStringAsFixed(2)}',
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
                              color: Colors.black,
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
                                    durationSeconds: videoDurationSec,
                                    channel: currentChannel,
                                    priorityMode: isAccuracyMode.value
                                        ? 'accuracy'
                                        : 'speed',
                                    autoChapters: selectedFeatures.contains(
                                      'chapters',
                                    ),
                                    factCheckTier: selectedFactCheckTier.value,
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
      checkColor: Colors.black,
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

  void showBatchGenerateAIFeaturesDialog(
    BuildContext context,
    List<Video> videos,
    VideoManagementController controller,
  ) {
    if (videos.isEmpty) return;

    final selectedFeatures = <String>{
      'subtitles',
      'chapters',
      'factcheck',
    }.obs;

    final selectedLangs = <String>{'en', 'es'}.obs;

    final availableLangs = [
      {'code': 'en', 'name': 'English'},
      {'code': 'es', 'name': 'Spanish'},
      {'code': 'hi', 'name': 'Hindi'},
      {'code': 'te', 'name': 'Telugu'},
      {'code': 'ta', 'name': 'Tamil'},
      {'code': 'kn', 'name': 'Kannada'},
      {'code': 'ml', 'name': 'Malayalam'},
    ];

    Get.dialog<void>(
      Dialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 540),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch AI Pipeline',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontFamily: TWTypography.brandFamily,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Applying to ${videos.length} selected videos',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.bgDivider, height: 1),
              const SizedBox(height: 16),
              Text(
                'AI Features to Generate',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Obx(
                () => Column(
                  children: [
                    buildFeatureCheckbox(
                      title: 'Automatic Subtitles & Transcriptions',
                      subtitle: 'Generate synchronized multi-language captions',
                      icon: Icons.subtitles_rounded,
                      value: selectedFeatures.contains('subtitles'),
                      onChanged: (v) {
                        if (v == true) {
                          selectedFeatures.add('subtitles');
                        } else {
                          selectedFeatures.remove('subtitles');
                        }
                      },
                    ),
                    buildFeatureCheckbox(
                      title: 'Automatic Video Chapters',
                      subtitle: 'Extract thematic timestamps and scene boundaries',
                      icon: Icons.view_timeline_rounded,
                      value: selectedFeatures.contains('chapters'),
                      onChanged: (v) {
                        if (v == true) {
                          selectedFeatures.add('chapters');
                        } else {
                          selectedFeatures.remove('chapters');
                        }
                      },
                    ),
                    buildFeatureCheckbox(
                      title: 'Epistemic Truth & Fact-Check Audit',
                      subtitle: 'Automated claim detection and credibility scoring',
                      icon: Icons.verified_user_rounded,
                      value: selectedFeatures.contains('factcheck'),
                      onChanged: (v) {
                        if (v == true) {
                          selectedFeatures.add('factcheck');
                        } else {
                          selectedFeatures.remove('factcheck');
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Target Languages',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Obx(
                () => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableLangs.map((lang) {
                    final isSel = selectedLangs.contains(lang['code']);
                    return FilterChip(
                      label: Text(
                        lang['name']!,
                        style: TextStyle(
                          color: isSel ? Colors.black : AppColors.textPrimary,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: AppColors.brand,
                      checkmarkColor: Colors.black,
                      backgroundColor: AppColors.bgSurfaceHover,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSel ? AppColors.brand : AppColors.bgDivider,
                        ),
                      ),
                      onSelected: (val) {
                        final code = lang['code'];
                        if (code != null) {
                          if (val) {
                            selectedLangs.add(code);
                          } else if (selectedLangs.length > 1) {
                            selectedLangs.remove(code);
                          }
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
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
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      Get.back<void>();
                      for (final vid in videos) {
                        await controller.triggerAIFeatures(
                          videoId: vid.id,
                          features: selectedFeatures.toList(),
                          targetLanguages: selectedLangs.toList(),
                          durationSeconds: vid.durationValue.inSeconds,
                        );
                      }
                      AppSnackbar.success(
                        'Batch AI pipeline initiated for ${videos.length} videos.',
                      );
                    },
                    icon: const Icon(Icons.bolt_rounded, size: 18, color: Colors.black),
                    label: Text(
                      'Run Batch Pipeline (${videos.length})',
                      style: AppTextStyles.buttonText.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
