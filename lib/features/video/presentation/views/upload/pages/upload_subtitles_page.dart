import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/features/video/data/models/video/video_duration_utils.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_subtitles_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_multi_language_picker_sheet.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/spoken_language_selector_card.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/subtitles/subtitles_languages_grid.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Dedicated Subtitles Configuration & Pricing Page.
/// Provides comprehensive pricing transparency, duration tiers, language filters, and multi-selection.
class UploadSubtitlesPage extends StatelessWidget {
  const UploadSubtitlesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(UploadSubtitlesController());

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141418),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: Get.back,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Subtitles & Translation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '130+ languages supported via Google Cloud Translation',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          Obx(() {
            final count = controller.selectedLanguages.length;
            final isFilteredToSelected = controller.selectedCategoryFilter.value == 'selected';
            if (count == 0) {
              return TextButton(
                onPressed: controller.selectTopGlobal,
                child: const Text(
                  'Select Top 10',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              );
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    showSubtitlesMultiLanguagePicker(
                      context: context,
                      controller: controller.uploadController,
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFilteredToSelected ? Colors.white : Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isFilteredToSelected ? Colors.white : Colors.white30,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 13,
                          color: isFilteredToSelected ? Colors.black : Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$count Selected',
                          style: TextStyle(
                            color: isFilteredToSelected ? Colors.black : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: controller.clearAll,
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Video & Tier Context Card
                  _buildVideoTierHeader(context, controller),
                  const SizedBox(height: 16),

                  // 2. Source Spoken Language ("From") Selector Card (18 languages)
                  SpokenLanguageSelectorCard(
                    controller: controller.uploadController,
                    title: 'Source Spoken Video Language ("From")',
                    subtitle: 'Speech recognition strictly supports 18 languages via AssemblyAI Universal-3.5 Pro',
                  ),
                  const SizedBox(height: 16),

                  // 3. Subtitle Options Card
                  _buildSubtitleOptionsSection(controller),
                  const SizedBox(height: 16),

                  // 4. Comprehensive Pricing Breakdown Card
                  _buildPricingCard(context, controller),
                  const SizedBox(height: 16),

                  // 5. Target Subtitle Languages ("To") - Country Selection Style
                  SubtitlesLanguagesGrid(controller: controller),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // 6. Sticky Bottom Action Bar
          _buildBottomActionBar(context, controller),
        ],
      ),
    );
  }

  Widget _buildVideoTierHeader(
    BuildContext context,
    UploadSubtitlesController controller,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.subtitles_outlined,
                  color: Color(0xFF60A5FA),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.durationSeconds > 0
                          ? 'Video Duration: ${VideoDurationUtils.formatDurationSeconds(controller.durationSeconds)}'
                          : 'Standard Video Length',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Tier: ${controller.subtitleTier.name} (${controller.subtitleTier.durationLabel})',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: controller.isCustomChannel
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF27272A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  controller.isCustomChannel ? 'CUSTOM' : 'STANDARD',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Speech is transcribed using AssemblyAI Universal-3.5 Pro (18 source languages), followed by Google Cloud Translation API v3 for studio-grade subtitle timing and multilingual translation across 135+ languages.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleOptionsSection(UploadSubtitlesController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14151B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262834)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Subtitle Delivery & Track Options',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF101116),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF222430)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.layers_rounded,
                    color: Color(0xFF60A5FA),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Multi-Format Bundle (.SRT + .VTT + .JSON)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Full cross-platform closed-caption tracks for web, mobile, and video players',
                        style: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'INCLUDED',
                    style: TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF101116),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF222430)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFA78BFA),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Google Cloud Translation v3 Alignment',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Contextual idioms, slang, and cultural tone preserved across all 135+ languages',
                        style: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: Color(0xFFC4B5FD),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(
    BuildContext context,
    UploadSubtitlesController controller,
  ) {
    return Obx(() {
      final totalSelected = controller.selectedLanguages.length;
      final freeDubbed = controller.freeDubbedSubtitleCount;
      final billable = controller.billableLanguages.length;
      final cost = controller.calculatedCost;
      final flatRate = controller.flatSubtitleRatePerLang;
      final wallet = controller.walletBalance;
      final isInsufficient = controller.isInsufficientBalance;

      return Material(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isInsufficient
                  ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Live Pricing Breakdown',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '\$${flatRate.toStringAsFixed(2)} / lang',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metrics table
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _buildMetricRow('Selected Subtitle Languages:', '$totalSelected'),
                  if (freeDubbed > 0) ...[
                    const SizedBox(height: 6),
                    _buildMetricRow(
                      'Included in Dubbing (Zero extra cost):',
                      '-$freeDubbed (Free)',
                      highlightColor: const Color(0xFF34D399),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _buildMetricRow(
                    'Billable Languages:',
                    '$billable × \$${flatRate.toStringAsFixed(2)}',
                  ),
                  const Divider(color: Colors.white10, height: 16),
                  _buildMetricRow(
                    'Total Subtitle Cost:',
                    '\$${cost.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Channel Revenue & Payment
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isInsufficient
                    ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isInsufficient
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                      : Colors.white10,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        color: isInsufficient
                            ? const Color(0xFF60A5FA)
                            : Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Channel Revenue: \$${wallet.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isInsufficient
                              ? const Color(0xFF60A5FA)
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: isInsufficient
                          ? const Color(0xFF60A5FA).withValues(alpha: 0.15)
                          : const Color(0xFF34D399).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isInsufficient ? 'Direct Pay Ready' : 'Deduct from Revenue',
                      style: TextStyle(
                        color: isInsufficient ? const Color(0xFF60A5FA) : const Color(0xFF34D399),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (isInsufficient) ...[
              const SizedBox(height: 8),
              Text(
                'Channel revenue (\$${wallet.toStringAsFixed(2)}) is insufficient for this cost (\$${cost.toStringAsFixed(2)}). You can pay directly at upload submission.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            const SizedBox(height: 10),
            // Tiers expandable notice
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                collapsedIconColor: Colors.white60,
                iconColor: Colors.white,
                title: const Text(
                  'View Duration Pricing Tiers',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: ChannelWalletService.subtitleDurationTiers.map((tier) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${tier.name} (${tier.durationLabel})',
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        Text(
                          tier.standardFlatRatePerLanguage == tier.customFlatRatePerLanguage
                              ? '\$${tier.standardFlatRatePerLanguage.toStringAsFixed((tier.standardFlatRatePerLanguage * 100) % 1 != 0 ? 3 : 2)} / lang (At-Cost)'
                              : '\$${tier.standardFlatRatePerLanguage.toStringAsFixed(2)} Std / \$${tier.customFlatRatePerLanguage.toStringAsFixed(2)} Partner',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  });
  }

  Widget _buildMetricRow(
    String label,
    String value, {
    Color? highlightColor,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? Colors.white : Colors.white70,
            fontSize: isTotal ? 13 : 11.5,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlightColor ?? (isTotal ? Colors.white : Colors.white),
            fontSize: isTotal ? 14 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    UploadSubtitlesController controller,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sticky Active Selected Languages Strip
            Obx(() {
              final selectedItems = controller.selectedLanguagesList;
              if (selectedItems.isEmpty) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B22),
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Selected (${selectedItems.length}):',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: selectedItems.map((lang) {
                            return Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    lang.name,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => controller.removeLanguage(lang.name),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.all(1.5),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black12,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 11,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: controller.clearAll,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Action Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Obx(() {
                      final count = controller.selectedLanguages.length;
                      final cost = controller.calculatedCost;
                      final names = controller.selectedLanguageDisplayNames;
                      final summary = names.isEmpty
                          ? 'Estimated: \$${cost.toStringAsFixed(2)}'
                          : (names.length <= 3
                              ? '${names.join(", ")} • \$${cost.toStringAsFixed(2)}'
                              : '${names.take(2).join(", ")} +${names.length - 2} more • \$${cost.toStringAsFixed(2)}');

                      return InkWell(
                        onTap: count > 0
                            ? () {
                                controller.selectedCategoryFilter.value = 'selected';
                              }
                            : null,
                        borderRadius: BorderRadius.circular(6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '$count ${count == 1 ? "language" : "languages"} selected',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (count > 0) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.filter_list,
                                    size: 13,
                                    color: Colors.white70,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              summary,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  ElevatedButton(
                    onPressed: controller.applyAndSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Apply Subtitles',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
