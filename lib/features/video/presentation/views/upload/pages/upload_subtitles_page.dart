import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/channel_wallet_topup_sheet.dart';
import 'package:truthworld/features/video/data/models/video/video_duration_utils.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_subtitles_controller.dart';
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
                    if (isFilteredToSelected) {
                      controller.selectedCategoryFilter.value = 'all';
                    } else {
                      controller.selectedCategoryFilter.value = 'selected';
                    }
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

                  // 2. Comprehensive Pricing Breakdown Card
                  _buildPricingCard(context, controller),
                  const SizedBox(height: 16),

                  // 2.5 Active Selected Languages Section
                  _buildSelectedLanguagesSection(controller),

                  // 3. Search & Category Filters
                  _buildSearchAndFilters(controller),
                  const SizedBox(height: 14),

                  // 4. Presets Row
                  _buildPresetsRow(controller),
                  const SizedBox(height: 16),

                  // 5. Languages Grid
                  _buildLanguagesGrid(controller),
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
            'Subtitles are computed using Whisper speech-to-text followed by Google Cloud Translation neural engines for studio-grade subtitle timing and multilingual translation.',
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

            // Wallet Balance & Topup
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isInsufficient
                    ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isInsufficient
                      ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                      : Colors.white10,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: isInsufficient
                            ? const Color(0xFFF87171)
                            : Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Wallet Balance: \$${wallet.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isInsufficient
                              ? const Color(0xFFF87171)
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (controller.channel != null)
                    GestureDetector(
                      onTap: () {
                        ChannelWalletTopupSheet.show(
                          context,
                          channel: controller.channel!,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '+ Add Money',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (isInsufficient) ...[
              const SizedBox(height: 8),
              Text(
                '⚠️ Insufficient wallet balance (\$${wallet.toStringAsFixed(2)} available vs \$${cost.toStringAsFixed(2)} required). Please top up channel wallet or reduce selected languages.',
                style: const TextStyle(
                  color: Color(0xFFFCA5A5),
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

  Widget _buildSelectedLanguagesSection(UploadSubtitlesController controller) {
    return Obx(() {
      final selectedItems = controller.selectedLanguagesList;
      if (selectedItems.isEmpty) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF16161A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Selected Languages (${selectedItems.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: controller.clearAll,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'Clear All',
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedItems.map((lang) {
                final isDubbed = controller.isLanguageDubbed(lang);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lang.name,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (lang.nativeName.isNotEmpty && lang.nativeName != lang.name) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${lang.nativeName})',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (isDubbed) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'FREE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => controller.removeLanguage(lang.name),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black12,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSearchAndFilters(UploadSubtitlesController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (val) => controller.searchQuery.value = val,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search 130+ languages (e.g. Spanish, Hindi, Japanese)...',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 12.5,
            ),
            prefixIcon: const Icon(Icons.search, color: Colors.white, size: 18),
            fillColor: const Color(0xFF141418),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Horizontal Category Filters
        Obx(() {
          final current = controller.selectedCategoryFilter.value;
          final selectedCount = controller.selectedLanguages.length;
          final categories = [
            {'id': 'all', 'label': 'All (130+)'},
            if (selectedCount > 0)
              {'id': 'selected', 'label': 'Selected ($selectedCount)'},
            {'id': 'popular', 'label': 'Popular'},
            {'id': 'indian', 'label': 'Indian (Indic)'},
            {'id': 'european', 'label': 'European'},
            {'id': 'asian', 'label': 'Asian & Pacific'},
            {'id': 'middle_eastern', 'label': 'Middle East & Africa'},
          ];

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = current == cat['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: FilterChip(
                    label: Text(
                      cat['label']!,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      controller.selectedCategoryFilter.value = cat['id']!;
                    },
                    selectedColor: Colors.white,
                    backgroundColor: const Color(0xFF141418),
                    checkmarkColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPresetsRow(UploadSubtitlesController controller) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _buildPresetButton(
          title: '+ Top 10 Global',
          onTap: controller.selectTopGlobal,
        ),
        _buildPresetButton(
          title: '+ Top Indic',
          onTap: controller.selectTopIndic,
        ),
        _buildPresetButton(
          title: '+ UN 6 Official',
          onTap: controller.selectUNOfficial,
        ),
        _buildPresetButton(
          title: '+ Select All Filtered',
          onTap: controller.selectAllFiltered,
        ),
      ],
    );
  }

  Widget _buildPresetButton({
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F24),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLanguagesGrid(UploadSubtitlesController controller) {
    return Obx(() {
      final langs = controller.filteredLanguages;

      if (langs.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32.0),
            child: Text(
              'No matching languages found.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        );
      }

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 68,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: langs.length,
        itemBuilder: (context, index) {
          final lang = langs[index];
          final isSelected = controller.isLanguageSelected(lang);
          final isDubbed = controller.isLanguageDubbed(lang);

          return InkWell(
            onTap: () => controller.toggleLanguage(lang),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF27272E) : const Color(0xFF141418),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.08),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          lang.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                lang.nativeName.isNotEmpty ? lang.nativeName : lang.code.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 10.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isDubbed) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'DUBBED (FREE)',
                                  style: TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? Colors.white : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white30,
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 13,
                            color: Colors.black,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
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
