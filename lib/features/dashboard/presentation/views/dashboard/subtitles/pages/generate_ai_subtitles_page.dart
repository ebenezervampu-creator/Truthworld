import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Dedicated, responsive page for selecting target languages and generating AI subtitles,
/// with real-time persistent background progress observation.
class GenerateAiSubtitlesPage extends StatelessWidget {
  const GenerateAiSubtitlesPage({
    required this.controller,
    required this.isDarkMode,
    this.initialTier = 'ultra',
    this.initialLanguage,
    this.initialLanguages,
    super.key,
  });

  final SubtitlesController controller;
  final bool isDarkMode;
  final String initialTier;
  final String? initialLanguage;
  final List<String>? initialLanguages;

  @override
  Widget build(BuildContext context) {
    controller.refreshSpendableBalance();
    final video = controller.selectedVideo.value;
    final surfaceColor =
        isDarkMode ? AppColors.bgPage : AppColors.bgSurface;
    const bgColor = AppColors.bgPage;
    final textColor =
        isDarkMode ? AppColors.textPrimary : AppColors.textPrimary;
    final textSecondaryColor =
        isDarkMode ? AppColors.textSecondary : AppColors.textSecondary;
    final borderColor =
        isDarkMode ? AppColors.bgSurface : AppColors.bgSurface;

    // Reactive state for the page (Zero setState policy)
    final selectedTier = initialTier.obs; // 'ultra'
    final initialSet = <String>{};
    if (initialLanguage != null && initialLanguage!.trim().isNotEmpty) {
      initialSet.add(normalizeLanguageCode(initialLanguage!.trim()));
    }
    if (initialLanguages != null) {
      initialSet.addAll(initialLanguages!.map((l) => normalizeLanguageCode(l.trim())));
    }
    final selectedLangs = initialSet.obs;
    final priorityMode = 'standard'.obs; // 'standard' | 'high'
    final searchQuery = ''.obs;

    // Detect languages that already have subtitles published for this video
    final existingSubs = <String>{
      ...?video?.mediaSubtitles.entries
          .where((e) => e.value.trim().isNotEmpty)
          .map((e) => normalizeLanguageCode(e.key)),
    };

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
              'Generate Subtitles',
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
        child: Obx(() {
          // If generation is active or in progress, show the Live Progress UI
          if (controller.isGeneratingAI.value) {
            return _buildLiveProgressView(
              context: context,
              video: video,
              existingSubs: existingSubs,
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
            );
          }

          // Otherwise show the Language Selection & Generation Setup
          return _buildLanguageSelectionView(
            context: context,
            video: video,
            selectedTier: selectedTier,
            selectedLangs: selectedLangs,
            priorityMode: priorityMode,
            searchQuery: searchQuery,
            existingSubs: existingSubs,
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            textColor: textColor,
            textSecondaryColor: textSecondaryColor,
          );
        }),
      ),
    );
  }

  // ===========================================================================
  // 1. LANGUAGE SELECTION VIEW (Styled like Category Selection in Channel Wizard)
  // ===========================================================================
  Widget _buildLanguageSelectionView({
    required BuildContext context,
    required Video? video,
    required RxString selectedTier,
    required RxSet<String> selectedLangs,
    required RxString priorityMode,
    required RxString searchQuery,
    required Set<String> existingSubs,
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
    final regionalIndian = [
      'te',
      'hi',
      'ta',
      'kn',
      'ml',
      'mr',
      'bn',
      'gu',
      'pa',
    ];

    return LayoutBuilder(
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
                vertical: 18,
              ),
              children: [
                // Video Summary Header Card
                if (video != null)
                  _buildVideoHeaderCard(
                    video: video,
                    existingSubs: existingSubs,
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    textSecondaryColor: textSecondaryColor,
                  ),
                const SizedBox(height: 18),

                // Subtitle Generation Plan (Ultra $0.50 / 10m)
                _buildTierSelectionSection(
                  selectedTier: selectedTier,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  textSecondaryColor: textSecondaryColor,
                ),
                const SizedBox(height: 18),

                // Category-styled Card for Target Languages Selection (ElevenLabs Studio Style)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.bgSurface),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.translate_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Obx(
                              () => Text(
                                'Target Languages (${selectedLangs.length} Selected)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Select the languages you want to transcribe and generate subtitles for.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search bar
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.bgPage,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.bgSurface),
                        ),
                        child: TextField(
                          style: TextStyle(fontSize: 13, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Search languages by name or code...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: textSecondaryColor,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: Colors.white70,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (q) =>
                              searchQuery.value = q.trim().toLowerCase(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ElevenLabs-inspired Minimalist Filter Row (Zero garish green)
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildSegmentFilterChip(
                                    label: 'Popular (${topPopular.length})',
                                    onTap: () => selectedLangs.addAll(
                                      topPopular.where((code) => !existingSubs.contains(code)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSegmentFilterChip(
                                    label: 'Indian Regional (${regionalIndian.length})',
                                    onTap: () => selectedLangs.addAll(
                                      regionalIndian.where((code) => !existingSubs.contains(code)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSegmentFilterChip(
                                    label: 'Select All Missing',
                                    onTap: () => selectedLangs.addAll(
                                      supportedLanguages
                                          .map((l) => l.code)
                                          .where((code) => !existingSubs.contains(code)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: selectedLangs.clear,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Clear', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Selected Languages Tags Wrap (Matching Channel Wizard Category Wrap)
                      Obx(() {
                        if (selectedLangs.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.bgInput,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.bgSurface),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Languages (${selectedLangs.length}):',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: selectedLangs.map((code) {
                                  final lang = supportedLanguages
                                      .firstWhereOrNull((l) => l.code == code);
                                  final name = lang?.name ?? code.toUpperCase();
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgSurface,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.bgElevated,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () =>
                                              selectedLangs.remove(code),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
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
                      }),

                      const Divider(color: AppColors.bgSurface, height: 1),
                      const SizedBox(height: 8),

                      // Vertical Language List with Checkboxes (Identical to Category List in Channel Creation)
                      Obx(() {
                        final query = searchQuery.value;
                        final filtered = supportedLanguages.where((l) {
                          if (query.isEmpty) return true;
                          return l.name.toLowerCase().contains(query) ||
                              l.nativeName.toLowerCase().contains(query) ||
                              l.code.toLowerCase().contains(query);
                        }).toList();

                        return Container(
                          constraints: const BoxConstraints(maxHeight: 360),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (ctx, i) => const Divider(
                              color: AppColors.bgSurface,
                              height: 1,
                            ),
                            itemBuilder: (ctx, i) {
                              final lang = filtered[i];
                              final isAlreadyAvailable =
                                  existingSubs.contains(lang.code.toLowerCase());
                              return Obx(() {
                                final isSelected =
                                    selectedLangs.contains(lang.code);
                                return Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    leading: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.brand
                                                .withValues(alpha: 0.15)
                                            : AppColors.bgSurface,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.brand
                                              : (isAlreadyAvailable
                                                  ? AppColors.bgElevated
                                                  : AppColors.bgSurface),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        lang.code.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : (isAlreadyAvailable
                                                  ? AppColors.textSecondary
                                                  : AppColors.textSecondary),
                                        ),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            lang.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? Colors.white
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        if (isAlreadyAvailable) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF202024),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: const Color(0xFF2E2E33),
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.check_rounded,
                                                  size: 10,
                                                  color: AppColors.textSecondary,
                                                ),
                                                SizedBox(width: 3),
                                                Text(
                                                  'In Studio',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Text(
                                      isAlreadyAvailable
                                          ? '${lang.nativeName} • ${lang.code} • Subtitle already available in studio'
                                          : '${lang.nativeName} • ${lang.code}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isAlreadyAvailable
                                            ? AppColors.textSecondary
                                            : AppColors.textTertiary,
                                      ),
                                    ),
                                    trailing: Checkbox(
                                      value: isSelected,
                                      activeColor: Colors.white,
                                      checkColor: Colors.black,
                                      side: const BorderSide(
                                        color: AppColors.textDisabled,
                                      ),
                                      onChanged: (val) {
                                        if (isSelected) {
                                          selectedLangs.remove(lang.code);
                                        } else {
                                          selectedLangs.add(lang.code);
                                        }
                                      },
                                    ),
                                    onTap: () {
                                      if (isSelected) {
                                        selectedLangs.remove(lang.code);
                                      } else {
                                        selectedLangs.add(lang.code);
                                      }
                                    },
                                  ),
                                );
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Cost Summary Card (Strict Zero-Charm Pricing)
                _buildCostSummaryCard(
                  context: context,
                  video: video,
                  selectedTier: selectedTier,
                  selectedLangs: selectedLangs,
                  controller: controller,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  textSecondaryColor: textSecondaryColor,
                ),
                const SizedBox(height: 24),

                // Generate Button (High Contrast White on Dark, Black Text on White)
                _buildGenerateActionCard(
                  context: context,
                  video: video,
                  selectedTier: selectedTier,
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
    );
  }

  // ===========================================================================
  // 2. LIVE PROGRESS VIEW (Continuous Background-Resilient State)
  // ===========================================================================
  Widget _buildLiveProgressView({
    required BuildContext context,
    required Video? video,
    required Set<String> existingSubs,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    return Obx(() {
      final progress = controller.aiJobProgress.value;
      final status = controller.aiJobStatus.value.isNotEmpty
          ? controller.aiJobStatus.value
          : 'Transcribing dialogue & preparing multilingual subtitles...';
      final isDone = progress >= 100;
      final isPaused = controller.isAiJobPaused.value;
      final elapsed = controller.aiElapsedSeconds.value;
      final elapsedMinutes = (elapsed ~/ 60).toString().padLeft(2, '0');
      final elapsedSeconds = (elapsed % 60).toString().padLeft(2, '0');
      final isStalledNotice = elapsed >= 75 && !isDone && !isPaused;

      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            children: [
              // Video Header
              if (video != null)
                _buildVideoHeaderCard(
                  video: video,
                  existingSubs: existingSubs,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  textSecondaryColor: textSecondaryColor,
                ),
              const SizedBox(height: 20),

              // Main Live Progress Box
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.appBarSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDone
                        ? AppColors.bgElevated
                        : (isPaused
                            ? AppColors.warning.withValues(alpha: 0.5)
                            : AppColors.brand.withValues(alpha: 0.3)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar with Status Icon, Live Badge & Telemetry
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDone
                                ? AppColors.bgSurface
                                : (isPaused
                                    ? AppColors.warning.withValues(alpha: 0.15)
                                    : AppColors.brand.withValues(alpha: 0.12)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isDone
                                ? Icons.check_circle_rounded
                                : (isPaused
                                    ? Icons.pause_circle_rounded
                                    : Icons.auto_awesome_rounded),
                            size: 26,
                            color: isDone
                                ? Colors.white
                                : (isPaused ? AppColors.warning : Colors.white),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isDone
                                    ? 'Subtitles Generated Successfully!'
                                    : (isPaused
                                        ? 'Subtitle Generation Paused'
                                        : 'Generating AI Subtitles...'),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                status,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Elapsed Timer Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.bgElevated,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$elapsedMinutes:$elapsedSeconds',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Cloud Queue & Pipeline Telemetry Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.bgSurface),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPaused
                                ? Icons.pause_circle_outline_rounded
                                : Icons.cloud_sync_rounded,
                            size: 16,
                            color: isPaused
                                ? AppColors.warning
                                : AppColors.brand,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              controller.aiQueueTotal.value > 1
                                  ? 'Cloud Queue: Position #${controller.aiQueuePosition.value} of ${controller.aiQueueTotal.value} active jobs'
                                  : 'TruthWorld Cloud: Direct High-Priority Worker',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isPaused
                                  ? AppColors.warning.withValues(alpha: 0.2)
                                  : (isDone
                                      ? AppColors.bgSurface
                                      : AppColors.bgSurface),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isPaused
                                  ? 'PAUSED'
                                  : (isDone ? 'COMPLETE' : 'PROCESSING'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isPaused
                                    ? AppColors.warning
                                    : (isDone ? Colors.white : Colors.white70),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Progress Bar & Percentage
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isDone
                              ? 'Pipeline Completed'
                              : controller.aiCurrentStageName.value,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '$progress%',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress > 0
                            ? (progress / 100.0).clamp(0.0, 1.0)
                            : null,
                        backgroundColor: AppColors.bgSurface,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDone
                              ? Colors.white
                              : (isPaused ? AppColors.warning : AppColors.brand),
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Pipeline Step Progress Indicators
                    _buildStepProgressRow(
                      stepNumber: '1',
                      title: 'Speech Extraction & Transcription',
                      isComplete: progress >= 35,
                      isActive: progress < 35 && !isDone && !isPaused,
                    ),
                    const SizedBox(height: 10),
                    _buildStepProgressRow(
                      stepNumber: '2',
                      title: 'Neural Multilingual Translation',
                      isComplete: progress >= 75,
                      isActive: progress >= 35 && progress < 75 && !isDone && !isPaused,
                    ),
                    const SizedBox(height: 10),
                    _buildStepProgressRow(
                      stepNumber: '3',
                      title: 'Precision Timestamp Alignment & VTT Export',
                      isComplete: progress >= 100,
                      isActive: progress >= 75 && !isDone && !isPaused,
                    ),
                    const SizedBox(height: 22),

                    // Target Languages Generation Breakdown
                    if (controller.aiTargetLanguages.isNotEmpty) ...[
                      const Divider(color: AppColors.bgSurface, height: 1),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Target Languages (${controller.aiTargetLanguages.length})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${controller.aiLanguageStatuses.values.where((s) => s == "completed").length}/${controller.aiTargetLanguages.length} Ready',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: controller.aiTargetLanguages.map((code) {
                          final status = controller.aiLanguageStatuses[code] ??
                              (isDone ? 'completed' : 'queued');
                          final lang = supportedLanguages
                              .firstWhereOrNull((l) => l.code == code);
                          final name = lang?.name ?? code.toUpperCase();
                          return _buildLanguageProgressChip(
                            code: code,
                            name: name,
                            status: status,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Stalled Job Notice & Recommendation
                    if (isStalledNotice) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2000),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF854D0E),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    controller.aiCurrentStageName.value == 'Speech Extraction & Transcription'
                                        ? 'Audio extraction and dialogue transcription for this video (${video?.duration ?? "extended duration"}) is processing in the cloud. You can Pause, Cancel, or Regenerate below if needed.'
                                        : (controller.aiCurrentStageName.value == 'Neural Multilingual Translation'
                                            ? 'Neural multilingual translation for ${controller.aiTargetLanguages.length} target languages is processing in the cloud. You can Pause, Cancel, or Regenerate below if needed.'
                                            : 'Precision timestamp alignment and standard VTT/SRT export is finalizing in the cloud. You can Pause, Cancel, or Regenerate below if needed.'),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFFEF08A),
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () => _confirmAndCancelAIJob(context),
                                    child: const Text(
                                      'Reset & Start Fresh',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Background Persistence Assurance Notice
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.bgSurface),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.cloud_done_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Runs safely in the cloud. You can leave this page or close the app anytime without stopping generation.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Controls Row: Pause / Resume, Cancel, Regenerate
                    if (!isDone) ...[
                      Row(
                        children: [
                          // Pause / Resume Button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: controller.isPausingAI.value
                                  ? null
                                  : controller.togglePauseAIJob,
                              icon: Icon(
                                isPaused
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: Text(
                                isPaused ? 'Resume' : 'Pause',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                side: const BorderSide(color: AppColors.bgElevated),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Regenerate / Restart Button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: controller.isRegeneratingAI.value
                                  ? null
                                  : controller.regenerateAIJob,
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Regenerate',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                side: const BorderSide(color: AppColors.bgElevated),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Cancel Button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: controller.isCancellingAI.value
                                  ? null
                                  : _confirmAndCancelAIJob,
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Colors.redAccent,
                              ),
                              label: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.redAccent,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                side: BorderSide(
                                  color: Colors.redAccent.withValues(alpha: 0.5),
                                ),
                                foregroundColor: Colors.redAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Action Button (Primary Navigation)
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Get.back<void>(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isDone ? 'Open Subtitle Editor' : 'Return to Studio',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
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
    });
  }

  Widget _buildLanguageProgressChip({
    required String code,
    required String name,
    required String status,
  }) {
    final (Color badgeColor, Color badgeTextColor, String statusLabel, IconData iconData) = switch (status) {
      'completed' => (
        AppColors.bgSurface,
        Colors.white,
        'Ready',
        Icons.check_circle_rounded,
      ),
      'translating' => (
        AppColors.info.withValues(alpha: 0.2),
        AppColors.textLink,
        'Translating',
        Icons.translate_rounded,
      ),
      'aligning' => (
        const Color(0xFF7C3AED).withValues(alpha: 0.2),
        const Color(0xFFA78BFA),
        'Aligning',
        Icons.av_timer_rounded,
      ),
      'transcribing' => (
        AppColors.bgSurface,
        Colors.white,
        'Transcribing',
        Icons.mic_rounded,
      ),
      _ => (
        AppColors.bgSurface,
        AppColors.textSecondary,
        'Queued',
        Icons.schedule_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgSurface),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconData, size: 10, color: badgeTextColor),
                const SizedBox(width: 4),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAndCancelAIJob([BuildContext? context]) {
    Get.dialog<void>(
      AlertDialog(
        backgroundColor: AppColors.bgPage,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.bgSurface),
        ),
        title: const Text(
          'Cancel Subtitle Generation?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: const Text(
          'Are you sure you want to stop subtitle generation for this video? The job will be cancelled in the cloud.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text(
              'Keep Running',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back<void>();
              controller.cancelAIJob();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Job'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepProgressRow({
    required String stepNumber,
    required String title,
    required bool isComplete,
    required bool isActive,
  }) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isComplete
                ? Colors.white
                : (isActive ? Colors.white : AppColors.bgSurface),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: isComplete
              ? const Icon(Icons.check, size: 14, color: Colors.black)
              : Text(
                  stepNumber,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.black : Colors.white70,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  isActive || isComplete ? FontWeight.bold : FontWeight.normal,
              color: isActive || isComplete
                  ? Colors.white
                  : AppColors.textSecondary,
            ),
          ),
        ),
        if (isActive)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
      ],
    );
  }

  // ===========================================================================
  // 3. TIER SECTION (Ultra Subtitles $0.50 / 10m)
  // ===========================================================================
  Widget _buildTierSelectionSection({
    required RxString selectedTier,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgSurface),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Subtitle Plan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Ultra',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black, // High contrast: black on white/brand
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Unified cinema-grade subtitles powered by Universal 3.5 Pro, Sarvam AI Indic, Google Chirp 2, and Gemini 2.5 Flash.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _buildTierCard(
            id: 'ultra',
            name: 'Ultra Subtitles',
            priceLabel: '\$0.50 / 10 min',
            addOnLabel: '+\$0.20 per additional language',
            badge: 'Cinema-Grade',
            badgeColor: AppColors.brand,
            badgeTextColor: Colors.black, // High contrast: black on brand
            modelsDescription:
                'Universal 3.5 Pro + Sarvam Indic + Google Cloud Chirp 2 • Gemini 2.5 Flash',
            featuresDescription:
                'Frontier reasoning, cultural transcreation, reading pacing & precision timing',
            isSelected: true,
            onTap: () => selectedTier.value = 'ultra',
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard({
    required String id,
    required String name,
    required String priceLabel,
    required String addOnLabel,
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
    required String modelsDescription,
    required String featuresDescription,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bgSurface : AppColors.bgPage,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : AppColors.bgSurface,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: badgeTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              priceLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              addOnLabel,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.bgSurface, height: 1),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: Colors.white70,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    modelsDescription,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 14,
                  color: Colors.white70,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    featuresDescription,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. COST SUMMARY (Strict Zero-Charm Pricing Policy)
  // ===========================================================================
  Widget _buildCostSummaryCard({
    required BuildContext context,
    required Video? video,
    required RxString selectedTier,
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
      final currentChan = controller.currentChannel.value;
      final rawCost = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'subtitles'},
        targetLanguages: selectedLangs.toList(),
        durationSeconds: durationSecs,
        channel: currentChan,
        subtitleTier: selectedTier.value,
      );

      // Enforce zero charm pricing / round transparent number display
      final roundedCost = rawCost > 0 ? rawCost : 0.0;
      final bal = controller.spendableBalance.value?.totalSpendableBalance ?? 0.0;
      final isInsufficient = controller.spendableBalance.value != null &&
          selectedLangs.isNotEmpty &&
          roundedCost > 0 &&
          bal < roundedCost;

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
                  Icons.payments_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Estimated Subtitle Generation Cost',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '\$${rawCost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tier: Ultra Subtitles (\$0.50 / 10m)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Gemini 2.5 Flash',
                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Languages: ${selectedLangs.length} selected',
                    style: TextStyle(fontSize: 12, color: textSecondaryColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Duration: ${durationSecs ~/ 60}m ${durationSecs % 60}s',
                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  size: 16,
                  color: isInsufficient ? AppColors.warning : textSecondaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Channel Revenue:',
                  style: TextStyle(
                    fontSize: 12,
                    color: isInsufficient ? AppColors.warning : textSecondaryColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '\$${bal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isInsufficient ? AppColors.warning : Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isInsufficient
                        ? AppColors.info.withValues(alpha: 0.15)
                        : AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isInsufficient ? 'Direct Pay Ready' : 'Deduct from Revenue',
                    style: TextStyle(
                      color: isInsufficient ? AppColors.info : AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (isInsufficient) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.info),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Channel revenue (\$${bal.toStringAsFixed(2)}) is insufficient for \$${roundedCost.toStringAsFixed(2)}. You can pay directly to proceed.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 13,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Zero charm pricing: 100% transparent round rates with no hidden fees.',
                    style: TextStyle(fontSize: 11, color: textSecondaryColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  // ===========================================================================
  // 5. GENERATE ACTION CARD
  // ===========================================================================
  Widget _buildGenerateActionCard({
    required BuildContext context,
    required Video? video,
    required RxString selectedTier,
    required RxSet<String> selectedLangs,
    required RxString priorityMode,
    required SubtitlesController controller,
  }) {
    return Obx(() {
      final isReady = selectedLangs.isNotEmpty;
      final durationSecs = video?.durationSeconds ??
          (controller.videoDuration.value.inSeconds > 0
              ? controller.videoDuration.value.inSeconds
              : 120);
      final currentChan = controller.currentChannel.value;
      final rawCost = ChannelWalletService.calculateAIFeatureCost(
        selectedFeatures: {'subtitles'},
        targetLanguages: selectedLangs.toList(),
        durationSeconds: durationSecs,
        channel: currentChan,
        subtitleTier: selectedTier.value,
      );
      final roundedCost = rawCost > 0 ? rawCost : 0.0;
      final bal = controller.spendableBalance.value?.totalSpendableBalance ?? 0.0;
      final isInsufficient = controller.spendableBalance.value != null &&
          isReady &&
          roundedCost > 0 &&
          bal < roundedCost;

      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: isReady
              ? () async {
                  if (isInsufficient) {
                    final chan = controller.currentChannel.value;
                    if (chan == null) {
                      AppSnackbar.error('Unable to verify channel. Please select a valid channel.');
                      return;
                    }
                    final paymentOk = await ChannelWalletService().payForSubtitlesWithCashfree(
                      channel: chan,
                      amountUSD: roundedCost,
                      targetLanguages: selectedLangs.toList(),
                      videoId: controller.selectedVideo.value?.id ?? '',
                    );
                    if (!paymentOk) {
                      AppSnackbar.error('Direct payment was not completed. Please try again.');
                      return;
                    }
                    controller.triggerSubtitlesGeneration(
                      targetLanguages: selectedLangs.toList(),
                      priorityMode: priorityMode.value,
                      subtitleTier: selectedTier.value,
                      isDirectlyPaid: true,
                    );
                    return;
                  }
                  controller.triggerSubtitlesGeneration(
                    targetLanguages: selectedLangs.toList(),
                    priorityMode: priorityMode.value,
                    subtitleTier: selectedTier.value,
                  );
                }
              : null,
          icon: Icon(
            isInsufficient
                ? Icons.payment_rounded
                : Icons.auto_awesome_rounded,
            size: 18,
            color: Colors.black,
          ),
          label: Text(
            isInsufficient
                ? 'Pay Directly (\$${roundedCost.toStringAsFixed(2)}) & Start AI'
                : (isReady
                    ? 'Generate Subtitles (${selectedLangs.length} Languages)'
                    : 'Generate Subtitles (Select Languages)'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            disabledBackgroundColor: AppColors.bgSurfaceHover,
            disabledForegroundColor: AppColors.textDisabled,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    });
  }

  // ===========================================================================
  // 5. VIDEO HEADER CARD (ElevenLabs Minimal Media Card)
  // ===========================================================================
  Widget _buildVideoHeaderCard({
    required Video video,
    required Set<String> existingSubs,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color textSecondaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgSurface),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              width: 88,
              height: 52,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Container(
                width: 88,
                height: 52,
                color: AppColors.bgSurface,
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF202024),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 11, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            video.duration,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (existingSubs.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF202024),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF2E2E33)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.subtitles_rounded, size: 11, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              'Active: ${existingSubs.map((c) => c.toUpperCase()).join(", ")}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentFilterChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2E2E33)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
