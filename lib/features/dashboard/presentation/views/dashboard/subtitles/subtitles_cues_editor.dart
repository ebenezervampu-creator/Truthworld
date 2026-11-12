import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/dialogs/find_replace_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/dialogs/shift_timings_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/pages/generate_ai_subtitles_page.dart';
import 'package:truthworld/theme/app_theme.dart';

class SubtitlesCuesEditor extends StatelessWidget {
  const SubtitlesCuesEditor({
    required this.controller,
    required this.surfaceColor,
    required this.textColor,
    required this.textSecondaryColor,
    required this.borderColor,
    required this.isDarkMode,
    required this.isMobile,
    super.key,
  });

  final SubtitlesController controller;
  final Color surfaceColor;
  final Color textColor;
  final Color textSecondaryColor;
  final Color borderColor;
  final bool isDarkMode;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasExtremelyConstrainedHeight = constraints.maxHeight < 140;

        final cuesContent = Column(
          children: [
            // Cues Toolbar (Search, Find & Replace, Shift Timings, Sort, Clear)
            SubtitlesCuesToolbar(
              controller: controller,
              surfaceColor: surfaceColor,
              textColor: textColor,
              borderColor: borderColor,
            ),

        // Cues Header Row (Responsive)
        if (!isMobile)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: surfaceColor.withValues(alpha: 0.4),
            child: Row(
              children: [
                SizedBox(
                  width: 180,
                  child: Text(
                    'Timing Interval',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textSecondaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Subtitle Text Cue',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textSecondaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 70),
              ],
            ),
          )
        else
          Obx(() {
            final count = controller.filteredCues.length;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: surfaceColor.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Text(
                    'Subtitles ($count segments)',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textSecondaryColor,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: controller.addCueAtCurrentTime,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: AppColors.brand,
                        ),
                        SizedBox(width: 2),
                        Text(
                          'Add Cue',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        Divider(height: 1, color: borderColor),

        // Cues List / Scrollable Empty State
        Expanded(
          child: Obx(() {
            final cues = controller.filteredCues;
            if (cues.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(
                              minHeight: constraints.maxHeight > 0
                                  ? constraints.maxHeight
                                  : 0.0),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.format_quote_rounded,
                                size: 44,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                controller.searchQueryInCues.value.isNotEmpty
                                    ? 'No subtitles match "${controller.searchQueryInCues.value}"'
                                    : 'No Subtitle Cues Defined',
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontSize: 15,
                                  color: textSecondaryColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => Get.to(() =>
                                        GenerateAiSubtitlesPage(
                                          controller: controller,
                                          isDarkMode: isDarkMode,
                                          initialLanguage: controller.selectedLanguage.value,
                                        )),
                                    icon: const Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Generate with AI',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.bgSurfaceHigh,
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: AppColors.brand
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),
                                  Builder(builder: (context) {
                                    final sourceLang = controller.availableLanguagesWithSubtitles.firstWhereOrNull(
                                      (l) => normalizeLanguageCode(l) != normalizeLanguageCode(controller.selectedLanguage.value),
                                    );
                                    if (sourceLang == null) return const SizedBox.shrink();
                                    return ElevatedButton.icon(
                                      onPressed: () => controller.copyCuesFromTrack(
                                        sourceLangCode: sourceLang,
                                        targetLangCode: controller.selectedLanguage.value,
                                      ),
                                      icon: const Icon(
                                        Icons.copy_all_rounded,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                      label: Text(
                                        'Copy Cues from ${controller.getLanguageName(sourceLang)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.bgSurfaceHigh,
                                        foregroundColor: Colors.white,
                                        side: BorderSide(
                                          color: AppColors.brand.withValues(alpha: 0.3),
                                        ),
                                      ),
                                    );
                                  }),
                                  ElevatedButton.icon(
                                    onPressed: controller.addCueAtCurrentTime,
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 16,
                                      color: Colors.black,
                                    ),
                                    label: const Text(
                                      'Add First Cue',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.brand,
                                      foregroundColor: Colors.black,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: controller.importSubtitleFile,
                                    icon: const Icon(
                                      Icons.upload_file_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      'Import File',
                                      style: TextStyle(color: textColor),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: textColor,
                                      side: BorderSide(color: borderColor),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: cues.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final cue = cues[index];
                return SubtitlesCueCardItem(
                  cue: cue,
                  index: index,
                  controller: controller,
                  surfaceColor: surfaceColor,
                  textColor: textColor,
                  textSecondaryColor: textSecondaryColor,
                  borderColor: borderColor,
                  isDarkMode: isDarkMode,
                  isMobile: isMobile,
                );
              },
            );
          }),
        ),
      ],
    );

    if (hasExtremelyConstrainedHeight) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: SizedBox(
          height: 220,
          child: cuesContent,
        ),
      );
    }

    return cuesContent;
  },
);
}
}

class SubtitlesCuesToolbar extends StatelessWidget {
  const SubtitlesCuesToolbar({
    required this.controller,
    required this.surfaceColor,
    required this.textColor,
    required this.borderColor,
    super.key,
  });

  final SubtitlesController controller;
  final Color surfaceColor;
  final Color textColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          // Filter Search Bar
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                maxLength: ContentValidator.defaultMaxSearchLength,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: TruthworldTextInputFormatters.withLimit(
                  ContentValidator.defaultMaxSearchLength,
                ),
                style: TextStyle(fontSize: 13, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search within subtitles...',
                  hintStyle: const TextStyle(fontSize: 12, color: Colors.white54),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: borderColor),
                  ),
                ),
                onChanged: controller.setCueSearchQuery,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Find & Replace
          IconButton(
            icon: const Icon(Icons.find_replace_rounded, size: 18, color: Colors.white),
            tooltip: 'Find & Replace Text',
            onPressed: () => FindReplaceDialog.show(context, controller),
          ),

          // Shift Timings
          IconButton(
            icon: const Icon(Icons.timelapse_rounded, size: 18, color: Colors.white),
            tooltip: 'Shift All Timings',
            onPressed: () => ShiftTimingsDialog.show(context, controller),
          ),

          // Sort Chronologically
          IconButton(
            icon: const Icon(Icons.sort_rounded, size: 18, color: Colors.white),
            tooltip: 'Sort Chronologically',
            onPressed: controller.sortCuesChronologically,
          ),

          // Clear Cues
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.white),
            tooltip: 'Clear All Cues in Current Track',
            onPressed: () {
              Get.dialog<void>(
                AlertDialog(
                  title: const Text('Clear All Subtitles?'),
                  content: const Text(
                    'Are you sure you want to clear all subtitle segments in this language track? This action cannot be undone unless you reload without saving.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back<void>(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Get.back<void>();
                        controller.clearAllCues();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class SubtitlesCueCardItem extends StatelessWidget {
  const SubtitlesCueCardItem({
    required this.cue,
    required this.index,
    required this.controller,
    required this.surfaceColor,
    required this.textColor,
    required this.textSecondaryColor,
    required this.borderColor,
    required this.isDarkMode,
    required this.isMobile,
    super.key,
  });

  final SubtitleCue cue;
  final int index;
  final SubtitlesController controller;
  final Color surfaceColor;
  final Color textColor;
  final Color textSecondaryColor;
  final Color borderColor;
  final bool isDarkMode;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isActive = controller.activeCueIndex.value == index;

      if (isMobile) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.brand.withValues(alpha: 0.12)
                : surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? AppColors.brand : borderColor,
              width: isActive ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header: #Index | Clickable Timing Span | Actions
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          isActive ? AppColors.brand : AppColors.bgSurfaceHigh,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Timing interval pill (Clickable to seek video!)
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: InkWell(
                        onTap: () => controller.seekToCue(index),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgPage,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_circle_fill_rounded,
                                size: 13,
                                color: AppColors.brand,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${cue.startTime.split('.').first} ➔ ${cue.endTime.split('.').first}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Duplicate Cue
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.content_copy_rounded, size: 16),
                    color: Colors.white,
                    tooltip: 'Duplicate Cue',
                    onPressed: () => controller.duplicateCue(index),
                  ),
                  const SizedBox(width: 8),

                  // Delete Cue
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    color: Colors.white,
                    tooltip: 'Delete Cue',
                    onPressed: () => controller.deleteCue(index),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Subtitle Text Box (Full width on mobile!)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: borderColor.withValues(alpha: 0.5)),
                ),
                child: TextFormField(
                  key: ValueKey(
                    '${controller.selectedLanguage.value}_${cue.id}_$index',
                  ),
                  initialValue: cue.text,
                  maxLength: 1000,
                  buildCounter: (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) =>
                      null,
                  maxLines: null,
                  inputFormatters: controller.selectedLanguage.value == 'en'
                      ? TruthworldTextInputFormatters.standard
                      : [TruthworldTextInputFormatters.profanityFilter],
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 14,
                    color: textColor,
                    height: 1.3,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter subtitle segment text...',
                    hintStyle: AppTextStyles.bodySmall.copyWith(
                      color: textSecondaryColor,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    fillColor: Colors.transparent,
                  ),
                  onChanged: (val) => controller.updateCueText(index, val),
                ),
              ),
              const SizedBox(height: 8),

              // Timing Steppers Toolbar (Nudge Start & End)
              Row(
                children: [
                  // Start Nudge
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: borderColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Start',
                                style: TextStyle(
                                    fontSize: 10, color: textSecondaryColor)),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => controller.shiftCueTiming(
                                index,
                                shiftMilliseconds: -500,
                              ),
                              child: const Icon(Icons.remove_circle_outline,
                                  size: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => controller.shiftCueTiming(index),
                              child: const Icon(Icons.add_circle_outline,
                                  size: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 4),
                            Tooltip(
                              message: 'Set Start to Video Playhead',
                              child: InkWell(
                                onTap: () =>
                                    controller.setStartToCurrentTime(index),
                                child: const Icon(Icons.my_location_rounded,
                                    size: 13, color: AppColors.brand),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // End Nudge
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: borderColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('End',
                                style: TextStyle(
                                    fontSize: 10, color: textSecondaryColor)),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => controller.shiftCueTiming(
                                index,
                                isStart: false,
                                shiftMilliseconds: -500,
                              ),
                              child: const Icon(Icons.remove_circle_outline,
                                  size: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => controller.shiftCueTiming(
                                index,
                                isStart: false,
                              ),
                              child: const Icon(Icons.add_circle_outline,
                                  size: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 4),
                            Tooltip(
                              message: 'Set End to Video Playhead',
                              child: InkWell(
                                onTap: () =>
                                    controller.setEndToCurrentTime(index),
                                child: const Icon(Icons.my_location_rounded,
                                    size: 13, color: AppColors.brand),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }

      // Desktop & Tablet (Side-by-side with matched 180px timing badge)
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.brand.withValues(alpha: 0.12)
              : surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.brand : borderColor,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timing Steppers & Playhead sync
            SubtitlesTimingBadge(
              cue: cue,
              index: index,
              controller: controller,
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(width: 12),

            // Subtitle Text Field
            Expanded(
              child: TextFormField(
                key: ValueKey(
                  '${controller.selectedLanguage.value}_${cue.id}_$index',
                ),
                initialValue: cue.text,
                maxLength: 1000,
                buildCounter: (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) =>
                    null,
                maxLines: null,
                inputFormatters: controller.selectedLanguage.value == 'en'
                    ? TruthworldTextInputFormatters.standard
                    : [TruthworldTextInputFormatters.profanityFilter],
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 14,
                  color: textColor,
                  height: 1.3,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter subtitle segment text...',
                  hintStyle: AppTextStyles.bodySmall.copyWith(
                    color: textSecondaryColor,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  fillColor: Colors.transparent,
                ),
                onChanged: (val) => controller.updateCueText(index, val),
              ),
            ),
            const SizedBox(width: 8),

            // Actions: Duplicate & Delete
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.content_copy_rounded, size: 16),
                  color: Colors.white,
                  tooltip: 'Duplicate Cue',
                  onPressed: () => controller.duplicateCue(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  color: Colors.white,
                  tooltip: 'Delete Cue',
                  onPressed: () => controller.deleteCue(index),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class SubtitlesTimingBadge extends StatelessWidget {
  const SubtitlesTimingBadge({
    required this.cue,
    required this.index,
    required this.controller,
    required this.textColor,
    required this.textSecondaryColor,
    required this.isDarkMode,
    super.key,
  });

  final SubtitleCue cue;
  final int index;
  final SubtitlesController controller;
  final Color textColor;
  final Color textSecondaryColor;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        children: [
          // Start Time row
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () =>
                      controller.shiftCueTiming(index, shiftMilliseconds: -500),
                  child: const Icon(
                    Icons.remove_circle_outline,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Seek Video to Cue',
                  child: InkWell(
                    onTap: () => controller.seekToCue(index),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 11,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          cue.startTime.split('.').first,
                          style: AppTextStyles.labelMedium.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => controller.shiftCueTiming(index),
                  child: const Icon(
                    Icons.add_circle_outline,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.my_location_rounded, size: 12),
                  color: Colors.white,
                  tooltip: 'Set Start to Video Playhead',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => controller.setStartToCurrentTime(index),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          const Icon(
            Icons.arrow_downward_rounded,
            size: 10,
            color: Colors.white,
          ),
          const SizedBox(height: 2),
          // End Time row
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => controller.shiftCueTiming(
                    index,
                    isStart: false,
                    shiftMilliseconds: -500,
                  ),
                  child: const Icon(
                    Icons.remove_circle_outline,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Seek Video to Cue End',
                  child: InkWell(
                    onTap: () => controller.seekToCue(index),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 11,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          cue.endTime.split('.').first,
                          style: AppTextStyles.labelMedium.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => controller.shiftCueTiming(
                    index,
                    isStart: false,
                  ),
                  child: const Icon(
                    Icons.add_circle_outline,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.my_location_rounded, size: 12),
                  color: Colors.white,
                  tooltip: 'Set End to Video Playhead',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => controller.setEndToCurrentTime(index),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
