import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/ai_languages.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

  void showGenerateAIFeaturesDialog(
    BuildContext context,
    Video video,
    VideoManagementController controller, {
    ChannelType? channelType,
    Set<String>? initialFeatures,
    Set<String>? initialLangs,
    String? initialDubbingTier,
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
    final isSubtitlesPreselected = initialFeatures != null &&
        initialFeatures.contains('subtitles') &&
        !initialFeatures.contains('dubbing');
    final isDubbingPreselected = initialFeatures != null &&
        initialFeatures.contains('dubbing');
    final isFactCheckPreselected = initialFeatures != null &&
        initialFeatures.contains('factcheck') &&
        !initialFeatures.contains('dubbing');
    final isChaptersPreselected = initialFeatures != null &&
        initialFeatures.contains('chapters') &&
        !initialFeatures.contains('dubbing');

    final dialogTitle = isDubbingPreselected
        ? 'Multilingual Audio Dubbing Studio'
        : (isSubtitlesPreselected
            ? 'Generate Subtitles & Captions'
            : (isFactCheckPreselected
                ? 'Run Credibility & Fact-Check'
                : (isChaptersPreselected
                    ? 'Generate Auto-Chapters'
                    : 'AI Features & Advanced Settings')));

    final dialogSubtitle = isDubbingPreselected
        ? 'Select target languages to generate voice-matched multilingual audio dubbing with vocal identity.'
        : (isSubtitlesPreselected
            ? 'Select target languages to generate synchronized native closed captions (SRT/VTT).'
            : (isFactCheckPreselected
                ? 'Extract spoken claims from speech transcripts and evaluate authenticity against verified sources.'
                : (isChaptersPreselected
                    ? 'Detect semantic topic shifts across your video to generate timestamped chapters.'
                    : 'Generate subtitles, dubbed audio tracks, fact-checking, AI summaries, and chapters anytime on demand.')));

    final selectedLangs = (initialLangs ?? <String>{'te', 'hi'}).toSet().obs;
    final selectedFeatures = (initialFeatures ?? <String>{
      'subtitles',
      'dubbing',
      'factcheck',
      'chapters',
    }).toSet().obs;
    final selectedFactCheckTier = 'standard'.obs;
    final selectedDubbingTier = (initialDubbingTier ?? 'audio_track').obs;
    final isAccuracyMode = true.obs;
    final showAdvanced = false.obs;

    final initialFilter = isDubbingPreselected ? 'dubbing' : 'all';
    final searchQuery = ''.obs;
    final regionFilter = initialFilter.obs; // 'all', 'dubbing', 'Indian', 'Global'
    final filteredLanguages = RxList<AILanguage>(
      isDubbingPreselected ? kElevenLabsDubbingLanguages : kAllAILanguages,
    );

    void applyFilter() {
      final q = searchQuery.value.toLowerCase().trim();
      final r = regionFilter.value;
      filteredLanguages.value = kAllAILanguages.where((lang) {
        final matchesCategory = r == 'all' ||
            (r == 'dubbing' && lang.supportsDubbing) ||
            lang.region == r;
        final matchesQuery = q.isEmpty ||
            lang.name.toLowerCase().contains(q) ||
            lang.native.toLowerCase().contains(q) ||
            lang.code.toLowerCase().contains(q);
        return matchesCategory && matchesQuery;
      }).toList();
    }

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
                () {
                  final isDubbingSelected = selectedFeatures.contains('dubbing');
                  final dubbingLangsSelected = selectedLangs
                      .where(isDubbingSupported)
                      .toList();
                  final currentTierPerLangRate = ChannelWalletService.calculateProductionTierCost(
                    tierId: selectedDubbingTier.value,
                    languageCount: 1,
                    durationSeconds: videoDurationSec,
                    channel: currentChannel,
                  );
                  final dubbingSubtotal = isDubbingSelected
                      ? (dubbingLangsSelected.length * currentTierPerLangRate)
                      : 0.0;
                  final nonDubbingFeatures = selectedFeatures.where((f) => f != 'dubbing').toSet();
                  final nonDubbingCost = nonDubbingFeatures.isEmpty
                      ? 0.0
                      : ChannelWalletService.calculateAIFeatureCost(
                          selectedFeatures: nonDubbingFeatures,
                          targetLanguages: selectedLangs.toList(),
                          durationSeconds: videoDurationSec,
                          channelType: effectiveChannelType,
                          factCheckTier: selectedFactCheckTier.value,
                          channel: currentChannel,
                        );
                  final totalEstimatedCost = double.parse(
                    (nonDubbingCost + dubbingSubtotal).toStringAsFixed(2),
                  );
                  final walletBalance =
                      currentChannel?.walletBalanceUSD ?? 0.0;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Row(
                      children: [
                        Icon(
                          isSubtitlesPreselected
                              ? Icons.subtitles_rounded
                              : (isDubbingPreselected
                                  ? Icons.record_voice_over_rounded
                                  : (isFactCheckPreselected
                                      ? Icons.fact_check_rounded
                                      : (isChaptersPreselected
                                          ? Icons.view_timeline_rounded
                                          : Icons.auto_awesome_rounded))),
                          color: AppColors.textPrimary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            dialogTitle,
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
                      dialogSubtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const Divider(height: 24),

                    // Section 1: Target Languages
                    Row(
                      children: [
                        Text(
                          'Target Languages',
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Obx(
                          () => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.brand.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              '${selectedLangs.length} selected',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.brand,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            selectedLangs.addAll(kAllAILanguages.map((l) => l.code));
                          },
                          child: const Text('Select All', style: TextStyle(fontSize: 11.5)),
                        ),
                        const SizedBox(width: 6),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            selectedLangs.clear();
                            selectedLangs.add('te');
                          },
                          child: const Text('Clear', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Search bar
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.bgInput,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.bgDivider),
                      ),
                      child: TextField(
                        maxLength: 100,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        inputFormatters: TruthworldTextInputFormatters.withLimit(100),
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search 135+ languages (e.g. Telugu, Spanish, Japanese)...',
                          hintStyle: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: (val) {
                          searchQuery.value = val;
                          applyFilter();
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Region Filter Chips
                    Obx(
                      () => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildLanguageRegionChip('All Subtitles (${kGoogleCloudTranslationLanguages.length})', 'all', regionFilter, applyFilter),
                            const SizedBox(width: 6),
                            _buildLanguageRegionChip('ElevenLabs Dubbing (${kElevenLabsDubbingLanguages.length})', 'dubbing', regionFilter, applyFilter),
                            const SizedBox(width: 6),
                            _buildLanguageRegionChip('Indian (23)', 'Indian', regionFilter, applyFilter),
                            const SizedBox(width: 6),
                            _buildLanguageRegionChip('Global (115)', 'Global', regionFilter, applyFilter),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Scrollable Language Chips
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: SingleChildScrollView(
                        child: Obx(
                          () => Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: filteredLanguages.map((lang) {
                              final isSelected = selectedLangs.contains(lang.code);
                              final isDubbingMode = selectedFeatures.contains('dubbing');
                              final labelText = (isDubbingMode && !lang.supportsDubbing)
                                  ? '${lang.name} (${lang.native} • Subs only)'
                                  : '${lang.name} (${lang.native})';
                              return FilterChip(
                                label: Text(labelText),
                                selected: isSelected,
                                selectedColor: AppColors.brand.withValues(alpha: 0.2),
                                checkmarkColor: Colors.white,
                                labelStyle: AppTextStyles.labelMedium.copyWith(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    selectedLangs.add(lang.code);
                                  } else {
                                    if (selectedLangs.length > 1) {
                                      selectedLangs.remove(lang.code);
                                    }
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
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
                          'AI Audio Dubbing (${DubbingProductionTier.fromId(selectedDubbingTier.value).name} • \$${currentTierPerLangRate.toStringAsFixed(2)}/lang)',
                      subtitle:
                          'Clean localized speech narration with studio vocal identity, cadence locking, and 100% background score preservation.',
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
                    if (selectedFeatures.contains('dubbing')) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 36, bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dubbing Production Tier:',
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
                              children: DubbingProductionTier.allTiers.map((tier) {
                                final isSelected = selectedDubbingTier.value == tier.id;
                                return FilterChip(
                                  label: Text('${tier.name} (${tier.tenMinuteRateFormatted})'),
                                  selected: isSelected,
                                  selectedColor: AppColors.brand,
                                  checkmarkColor: Colors.black,
                                  labelStyle: AppTextStyles.labelMedium.copyWith(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.black : AppColors.textPrimary,
                                  ),
                                  backgroundColor: AppColors.bgSurfaceHover,
                                  side: BorderSide(
                                    color: isSelected ? AppColors.brand : AppColors.bgDivider,
                                  ),
                                  onSelected: (_) {
                                    selectedDubbingTier.value = tier.id;
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.music_note_rounded, size: 14, color: AppColors.success),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '100% Studio Preservation: Discrete stems (Vocals, Drums, Bass, Foley) with zero phase loss & dynamic BGM ducking.',
                                      style: TextStyle(fontSize: 10.5, color: AppColors.success, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

                    // Dubbing Flat Cost Breakdown Card
                    if (isDubbingSelected) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurfaceHover,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.brand.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.receipt_long_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'AI Dubbing Flat Rate Estimation',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.brand.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    dubbingTier.label,
                                    style: AppTextStyles.caption.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.brand,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Rate per Language:',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '\$${flatDubbingRate.toStringAsFixed(2)} flat',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ElevenLabs Dubbing Languages (${dubbingLangsSelected.length}):',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${dubbingLangsSelected.length} × \$${flatDubbingRate.toStringAsFixed(2)} = \$${dubbingSubtotal.toStringAsFixed(2)}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (selectedLangs.length > dubbingLangsSelected.length) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Subtitles-Only Languages (${selectedLangs.length - dubbingLangsSelected.length}):',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    r'FREE ($0.00)',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Available Channel Revenue:',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '\$${walletBalance.toStringAsFixed(2)}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: walletBalance >= dubbingSubtotal
                                        ? AppColors.success
                                        : AppColors.warning,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else if (selectedFeatures.contains('subtitles')) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 16,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Subtitles & Closed Captions are 100% Free across all ${selectedLangs.length} target languages.',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
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
                                        ? 'Channel Revenue (Pro Channel)'
                                        : 'Channel Revenue / Direct Pay',
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: isCustom ? AppColors.info : AppColors.success,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Estimated Total:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '\$${totalEstimatedCost.toStringAsFixed(2)}',
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
                            totalEstimatedCost > 0
                                ? 'Generate & Pay \$${totalEstimatedCost.toStringAsFixed(2)}'
                                : 'Generate AI Features (Free)',
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
                                    dubbingTier: selectedDubbingTier.value,
                                  );
                                },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageRegionChip(
    String label,
    String regionKey,
    RxString currentFilter,
    VoidCallback onSelected,
  ) {
    final isSelected = currentFilter.value == regionKey;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.brand,
      checkmarkColor: Colors.black,
      backgroundColor: AppColors.bgSurfaceHover,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.brand : AppColors.bgDivider,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onSelected: (_) {
        currentFilter.value = regionKey;
        onSelected();
      },
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

    final selectedLangs = <String>{'en', 'es', 'te', 'hi'}.obs;

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
              Row(
                children: [
                  Text(
                    'Target Languages',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      selectedLangs.addAll(kAllAILanguages.map((l) => l.code));
                    },
                    child: const Text('Select All', style: TextStyle(fontSize: 11.5)),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      selectedLangs.clear();
                      selectedLangs.add('en');
                    },
                    child: const Text(
                      'Clear',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Obx(
                    () => Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: kAllAILanguages.map((lang) {
                        final isSel = selectedLangs.contains(lang.code);
                        return FilterChip(
                          label: Text('${lang.name} (${lang.native})'),
                          selected: isSel,
                          selectedColor: AppColors.brand,
                          checkmarkColor: Colors.black,
                          backgroundColor: AppColors.bgSurfaceHover,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.black : AppColors.textPrimary,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 11,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSel ? AppColors.brand : AppColors.bgDivider,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          onSelected: (val) {
                            if (val) {
                              selectedLangs.add(lang.code);
                            } else if (selectedLangs.length > 1) {
                              selectedLangs.remove(lang.code);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
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
