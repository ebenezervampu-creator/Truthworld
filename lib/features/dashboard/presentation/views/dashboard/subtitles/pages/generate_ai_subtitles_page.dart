import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Dedicated, full-screen responsive page for generating multi-language AI subtitles
class GenerateAiSubtitlesPage extends StatelessWidget {
  const GenerateAiSubtitlesPage({
    required this.controller,
    required this.isDarkMode,
    super.key,
  });

  final SubtitlesController controller;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final video = controller.selectedVideo.value;
    final surfaceColor =
        isDarkMode ? const Color(0xFF1E1E1E) : AppColors.bgSurface;
    const bgColor = AppColors.bgPage;
    final textColor =
        isDarkMode ? AppColors.textPrimary : AppColors.textPrimary;
    final textSecondaryColor =
        isDarkMode ? AppColors.textSecondary : AppColors.textSecondary;
    final borderColor =
        isDarkMode ? AppColors.bgDivider : const Color(0xFF2A2A2A);

    // Reactive state for the page (Zero setState policy)
    final selectedLangs = <String>{'en', 'hi', 'te', 'es'}.obs;
    final priorityMode = 'standard'.obs; // 'standard' | 'high'
    final searchQuery = ''.obs;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Get.back<void>(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate with Truthworld AI',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (video != null)
              Text(
                video.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondaryColor,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            final isTablet =
                constraints.maxWidth >= 600 && constraints.maxWidth < 900;
            final horizontalPadding = isDesktop ? 48.0 : (isTablet ? 24.0 : 16.0);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 20,
                  ),
                  children: [
                    // Video Mini-Header Card
                    if (video != null)
                      _buildVideoHeaderCard(
                        video: video,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                    const SizedBox(height: 20),

                    // Feature Information Banner
                    _buildAiExplainerBanner(
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                    const SizedBox(height: 24),

                    // Section 1: Processing Priority Mode
                    _buildSectionTitle(
                      title: '1. Processing Priority Mode',
                      subtitle:
                          'Choose execution speed and pipeline throughput',
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                    const SizedBox(height: 12),
                    _buildPrioritySelector(
                      priorityMode: priorityMode,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                    const SizedBox(height: 24),

                    // Section 2: Target Languages Selection
                    _buildSectionTitle(
                      title: '2. Target Translation Languages',
                      subtitle:
                          'Select the languages to transcribe and generate subtitles for',
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                    const SizedBox(height: 12),
                    _buildLanguagesMultiPicker(
                      selectedLangs: selectedLangs,
                      searchQuery: searchQuery,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                    const SizedBox(height: 24),

                    // Section 3: Cost and Wallet Summary Card
                    _buildCostSummaryCard(
                      video: video,
                      selectedLangs: selectedLangs,
                      controller: controller,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                    const SizedBox(height: 32),

                    // Bottom Action Button
                    _buildActionButtons(
                      selectedLangs: selectedLangs,
                      priorityMode: priorityMode,
                      controller: controller,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // VIDEO HEADER CARD
  // ===========================================================================
  Widget _buildVideoHeaderCard({
    required Video video,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              width: 80,
              height: 48,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Container(
                width: 80,
                height: 48,
                color: Colors.black26,
                child: const Icon(
                  Icons.video_library_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  video.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Duration: ${video.duration}',
                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EXPLAINER BANNER
  // ===========================================================================
  Widget _buildAiExplainerBanner({
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 20,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Automated Speech-to-Text & Neural Translation',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Truthworld AI transcribes spoken dialogue from the video, aligns precision timestamps, and translates subtitles into all selected languages. Once finished, you can edit and fine-tune every cue directly in the studio.',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondaryColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION TITLE
  // ===========================================================================
  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: textSecondaryColor),
        ),
      ],
    );
  }

  // ===========================================================================
  // PRIORITY SELECTOR
  // ===========================================================================
  Widget _buildPrioritySelector({
    required RxString priorityMode,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    return Obx(() {
      final current = priorityMode.value;

      return Row(
        children: [
          Expanded(
            child: _buildPriorityCard(
              title: 'Standard Queue',
              subtitle: 'Cost-effective high-accuracy processing.',
              isSelected: current == 'standard',
              onTap: () => priorityMode.value = 'standard',
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildPriorityCard(
              title: 'Express Priority',
              subtitle: 'Low-latency priority processing in GPU queue.',
              isSelected: current == 'high',
              onTap: () => priorityMode.value = 'high',
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildPriorityCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand.withValues(alpha: 0.12)
              : surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.brand : borderColor,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.brand : textColor,
                  ),
                ),
                const Spacer(),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: isSelected ? AppColors.brand : Colors.white38,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: textSecondaryColor,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TARGET LANGUAGES MULTI-PICKER
  // ===========================================================================
  Widget _buildLanguagesMultiPicker({
    required RxSet<String> selectedLangs,
    required RxString searchQuery,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    final topPopular = [
      'en',
      'es',
      'hi',
      'te',
      'ta',
      'fr',
      'de',
      'ja',
      'ar',
      'pt',
      'ru',
      'zh',
      'ko',
    ];
    final regionalIndian = ['te', 'hi', 'ta', 'kn', 'ml', 'mr', 'bn', 'gu', 'pa'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar with Quick actions & Search
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: TextField(
                    style: TextStyle(fontSize: 13, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Search languages...',
                      hintStyle:
                          TextStyle(fontSize: 13, color: textSecondaryColor),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: Colors.white60,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (q) =>
                        searchQuery.value = q.trim().toLowerCase(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Obx(() {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${selectedLangs.length} Selected',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand,
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),

          // Quick selection preset buttons
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton(
                onPressed: () => selectedLangs.addAll(topPopular),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: BorderSide(color: borderColor),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Top Popular (13)',
                    style: TextStyle(fontSize: 11)),
              ),
              OutlinedButton(
                onPressed: () => selectedLangs.addAll(regionalIndian),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: BorderSide(color: borderColor),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Indian Regional (9)',
                    style: TextStyle(fontSize: 11)),
              ),
              OutlinedButton(
                onPressed: () => selectedLangs.clear(),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: BorderSide(color: borderColor),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Clear All', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 14),

          // Scrollable Wrap of Language Filter Chips
          Obx(() {
            final query = searchQuery.value;
            final filtered = supportedLanguages.where((l) {
              if (query.isEmpty) return true;
              return l.name.toLowerCase().contains(query) ||
                  l.nativeName.toLowerCase().contains(query) ||
                  l.code.toLowerCase().contains(query);
            }).toList();

            return Container(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: filtered.map((lang) {
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
                      selectedColor: AppColors.brand,
                      checkmarkColor: Colors.black,
                      backgroundColor: AppColors.bgPage,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: isSel ? Colors.black : textColor,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSel ? AppColors.brand : borderColor,
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // COST SUMMARY & WALLET CARD
  // ===========================================================================
  Widget _buildCostSummaryCard({
    required Video? video,
    required RxSet<String> selectedLangs,
    required SubtitlesController controller,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    return Obx(() {
      final durationSecs = video?.durationSeconds ??
          (controller.videoDuration.value.inSeconds > 0
              ? controller.videoDuration.value.inSeconds
              : 120);

      // Clean transparent pricing calculation
      final rawCost = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'subtitles'},
        targetLanguages: selectedLangs.toList(),
        durationSeconds: durationSecs,
      );

      // Enforce zero charm pricing / round transparent number display
      final roundedCost = rawCost > 0 ? rawCost.ceilToDouble() : 0.0;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Text(
                  'Estimated Subtitle Generation Cost',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${roundedCost.toInt()}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Languages: ${selectedLangs.length} selected',
                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                ),
                Text(
                  'Duration: ${durationSecs ~/ 60}m ${durationSecs % 60}s',
                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 13,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 5),
                Text(
                  'Zero charm pricing: 100% transparent round rates with no hidden fees.',
                  style: TextStyle(fontSize: 11, color: textSecondaryColor),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  // ===========================================================================
  // ACTION BUTTONS (CANCEL / LAUNCH)
  // ===========================================================================
  Widget _buildActionButtons({
    required RxSet<String> selectedLangs,
    required RxString priorityMode,
    required SubtitlesController controller,
  }) {
    return Obx(() {
      final isReady = selectedLangs.isNotEmpty;

      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Get.back<void>(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppColors.bgDivider),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 14),
          ElevatedButton.icon(
            onPressed: isReady
                ? () {
                    Get.back<void>();
                    controller.triggerSubtitlesGeneration(
                      targetLanguages: selectedLangs.toList(),
                      priorityMode: priorityMode.value,
                    );
                  }
            : null,
            icon: const Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: Colors.black,
            ),
            label: const Text(
              'Start AI Subtitle Pipeline',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              disabledBackgroundColor: AppColors.bgSurfaceHover,
              disabledForegroundColor: AppColors.textDisabled,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      );
    });
  }
}
