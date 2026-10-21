import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/ai_languages.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Full-width trigger button to open the On-Demand AI Features modal.
class PipelineGenerateAIButton extends StatelessWidget {
  const PipelineGenerateAIButton({
    required this.video,
    super.key,
  });

  final Video video;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<VideoManagementController>()
        ? Get.find<VideoManagementController>()
        : Get.put(VideoManagementController());

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          side: const BorderSide(color: AppColors.brand, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: const Icon(
          Icons.auto_awesome_rounded,
          size: 18,
          color: Colors.white,
        ),
        label: Text(
          'Generate / Add AI Features (Telugu, Hindi, Dubbing, Factcheck...)',
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.brand,
          ),
        ),
        onPressed: () {
          showGenerateAIFeaturesQuickModal(context, video, controller);
        },
      ),
    );
  }
}

/// Displays quick configuration dialog to trigger AI pipeline operations.
void showGenerateAIFeaturesQuickModal(
  BuildContext context,
  Video video,
  VideoManagementController controller, {
  Set<String>? initialFeatures,
  Set<String>? initialLangs,
}) {
  final currentChannel = Get.isRegistered<DashboardController>()
      ? Get.find<DashboardController>().currentChannel.value
      : null;
  final effectiveChannelType =
      currentChannel?.channelType ?? ChannelType.standard;
  final videoDurationSec = video.durationValue.inSeconds;
  final flatDubbingRate = ChannelWalletService.getFlatDubbingPricePerLanguage(
    durationSeconds: videoDurationSec,
    channelType: effectiveChannelType,
  );
  final dubbingTier =
      ChannelWalletService.getDubbingDurationTier(videoDurationSec);

  final selectedLangs = (initialLangs ?? <String>{'te', 'hi'}).toSet().obs;
  final selectedFeatures = (initialFeatures ?? <String>{
    'subtitles',
    'dubbing',
    'factcheck',
    'chapters',
  }).toSet().obs;
  final isAccuracyMode = true.obs;
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

  final initialFilter = isDubbingPreselected ? 'dubbing' : 'all';
  final searchQuery = ''.obs;
  final regionFilter = initialFilter.obs;
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

  final modalTitle = isSubtitlesPreselected
      ? 'Generate Subtitles & Captions'
      : (isDubbingPreselected
          ? 'Multilingual AI Dubbing Studio'
          : (isFactCheckPreselected
              ? 'Run Credibility & Fact-Check'
              : (isChaptersPreselected
                  ? 'Generate Auto-Chapters'
                  : 'On-Demand AI Features')));

  final modalSubtitle = isSubtitlesPreselected
      ? 'Generate native subtitles and closed captions across your selected target languages.'
      : (isDubbingPreselected
          ? 'AI vocal localization and multi-track audio dubbing with flat predictable channel pricing.'
          : (isFactCheckPreselected
              ? 'Claim detection and epistemic credibility verification against authoritative sources.'
              : (isChaptersPreselected
                  ? 'Timestamped semantic section detection and topic extraction.'
                  : 'Generate subtitles, audio dubbing, fact-checking, and auto-chapters anytime on demand.')));

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
                final dubbingSubtotal = isDubbingSelected
                    ? (dubbingLangsSelected.length * flatDubbingRate)
                    : 0.0;
                final totalEstimatedCost = ChannelWalletService.calculateAIFeatureCost(
                  selectedFeatures: selectedFeatures.toSet(),
                  targetLanguages: isDubbingSelected
                      ? dubbingLangsSelected
                      : selectedLangs.toList(),
                  durationSeconds: videoDurationSec,
                  channelType: effectiveChannelType,
                );
                final walletBalance = currentChannel?.walletBalanceUSD ?? 0.0;

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
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            modalTitle,
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
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: Get.back<void>,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      modalSubtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const Divider(height: 20, color: AppColors.bgDivider),

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
                        Container(
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
                          child: const Text(
                            'Clear',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Search input
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

                    // Region tabs
                    Obx(
                      () => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildQuickModalRegionChip(
                              'All Subtitles (${kGoogleCloudTranslationLanguages.length})',
                              'all',
                              regionFilter,
                              applyFilter,
                            ),
                            const SizedBox(width: 6),
                            _buildQuickModalRegionChip(
                              'ElevenLabs Dubbing (${kElevenLabsDubbingLanguages.length})',
                              'dubbing',
                              regionFilter,
                              applyFilter,
                            ),
                            const SizedBox(width: 6),
                            _buildQuickModalRegionChip(
                              'Indian (23)',
                              'Indian',
                              regionFilter,
                              applyFilter,
                            ),
                            const SizedBox(width: 6),
                            _buildQuickModalRegionChip(
                              'Global (115)',
                              'Global',
                              regionFilter,
                              applyFilter,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Language chips scroll container
                    Container(
                      constraints: const BoxConstraints(maxHeight: 130),
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
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
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
                    const SizedBox(height: 16),

                    // Section 2: AI Features
                    Text(
                      'AI Features',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      value: selectedFeatures.contains('subtitles'),
                      activeColor: AppColors.brand,
                      checkColor: Colors.black,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Subtitles & Captions (SRT/VTT)',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Generate captions in selected target languages (FREE)',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onChanged: (val) => (val ?? false)
                          ? selectedFeatures.add('subtitles')
                          : selectedFeatures.remove('subtitles'),
                    ),
                    CheckboxListTile(
                      value: selectedFeatures.contains('dubbing'),
                      activeColor: AppColors.brand,
                      checkColor: Colors.black,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Audio Dubbing (Flat \$${flatDubbingRate.toStringAsFixed(2)}/lang • ${dubbingTier.label})',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Dubbing is NOT free: Flat rate for ${videoDurationSec > 0 ? VideoDurationUtils.formatDurationSeconds(videoDurationSec) : "detected duration"}. Charged per target language.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onChanged: (val) => (val ?? false)
                          ? selectedFeatures.add('dubbing')
                          : selectedFeatures.remove('dubbing'),
                    ),
                    CheckboxListTile(
                      value: selectedFeatures.contains('factcheck'),
                      activeColor: AppColors.brand,
                      checkColor: Colors.black,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Fact-Checking Report (FREE)',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Extract claims and truth credibility score',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onChanged: (val) => (val ?? false)
                          ? selectedFeatures.add('factcheck')
                          : selectedFeatures.remove('factcheck'),
                    ),
                    CheckboxListTile(
                      value: selectedFeatures.contains('chapters'),
                      activeColor: AppColors.brand,
                      checkColor: Colors.black,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Auto-Chapters',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Generate timestamped section breaks',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onChanged: (val) => (val ?? false)
                          ? selectedFeatures.add('chapters')
                          : selectedFeatures.remove('chapters'),
                    ),

                    // Dubbing Flat Cost Breakdown
                    if (isDubbingSelected) ...[
                      const SizedBox(height: 12),
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
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
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
                                  'Channel Wallet Balance:',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurfaceHover,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.bgDivider),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Estimated Total Cost:',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '\$${totalEstimatedCost.toStringAsFixed(2)}',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.black,
                          ),
                          icon: const Icon(
                            Icons.bolt_rounded,
                            size: 16,
                            color: Colors.black,
                          ),
                          label: Text(
                            totalEstimatedCost > 0
                                ? 'Generate & Pay \$${totalEstimatedCost.toStringAsFixed(2)}'
                                : 'Generate AI Features (Free)',
                            style: AppTextStyles.buttonText.copyWith(
                              color: Colors.black,
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
                                    durationSeconds: videoDurationSec,
                                    channel: currentChannel,
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
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildQuickModalRegionChip(
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
