import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/dialogs/find_replace_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/dialogs/generate_ai_subtitles_modal.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/dialogs/shift_timings_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

class SubtitlesCuesTable extends StatelessWidget {
  const SubtitlesCuesTable({
    required this.controller,
    required this.isDarkMode,
    super.key,
  });

  final SubtitlesController controller;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    const primaryText = AppColors.textPrimary;
    const secondaryText = AppColors.textSecondary;
    const cardColor = AppColors.bgSurface;
    const borderColor = AppColors.bgDivider;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Row: "Edit subtitles: English (Original)" + 3-dots menu
          _buildHeaderRow(context, primaryText, secondaryText),
          const SizedBox(height: 12),

          // Action Toolbar: + Add caption, ✨ Generate with AI, 📄 Import file, Search, Undo, Redo
          _buildActionToolbar(context, primaryText, secondaryText),
          const SizedBox(height: 10),

          // Search Field (if expanded)
          Obx(() {
            if (!controller.isCuesSearchExpanded.value) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: TextField(
                  maxLength: 100,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: TruthworldTextInputFormatters.withLimit(100),
                  style: const TextStyle(fontSize: 13, color: primaryText),
                  decoration: InputDecoration(
                    hintText: 'Search captions by text or time...',
                    hintStyle: const TextStyle(fontSize: 13, color: secondaryText),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: secondaryText),
                    suffixIcon: controller.searchQueryInCues.value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: secondaryText),
                            onPressed: () => controller.setCueSearchQuery(''),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: controller.setCueSearchQuery,
                ),
              ),
            );
          }),

          // Cues List / Table
          Expanded(
            child: Obx(() {
              final cues = controller.filteredCues;
              final isMobile = MediaQuery.of(context).size.width < 600;

              if (cues.isEmpty) {
                return _buildEmptyState(context, primaryText, secondaryText);
              }

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Table Header
                    if (!isMobile) _buildTableHeader(secondaryText, borderColor),

                    // Cues Rows
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: cues.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          color: AppColors.bgSurface,
                        ),
                        itemBuilder: (context, index) {
                          final cue = cues[index];
                          final isActive = controller.activeCueIndex.value == index;
                          final isSelected = controller.selectedCueIds.contains(cue.id);

                          return isMobile
                              ? _buildMobileCueRow(cue, index, isActive, isSelected, primaryText, secondaryText)
                              : _buildDesktopCueRow(cue, index, isActive, isSelected, primaryText, secondaryText);
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          // Bottom Cue Control Bar: Timecode pill, Undo, Redo, Zoom slider
          _buildBottomControlBar(primaryText, secondaryText, borderColor),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, Color primaryText, Color secondaryText) {
    return Obx(() {
      final code = controller.selectedLanguage.value;
      var langName = controller.getLanguageName(code);
      if (code == 'en') {
        langName = 'English (Original)';
      }

      return Row(
        children: [
          Expanded(
            child: Text(
              'Edit subtitles: $langName',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: secondaryText,
              size: 20,
            ),
            color: AppColors.bgSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'shift',
                child: Row(
                  children: [
                    Icon(Icons.timelapse_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Shift timings', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'find_replace',
                child: Row(
                  children: [
                    Icon(Icons.find_replace_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Find & replace', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Clear all captions', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    Icon(Icons.save_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Save track changes', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ],
            onSelected: (val) {
              if (val == 'shift') {
                ShiftTimingsDialog.show(context, controller);
              } else if (val == 'find_replace') {
                FindReplaceDialog.show(context, controller);
              } else if (val == 'clear') {
                controller.clearAllCues();
              } else if (val == 'save') {
                controller.saveCurrentSubtitles();
              }
            },
          ),
        ],
      );
    });
  }

  Widget _buildActionToolbar(BuildContext context, Color primaryText, Color secondaryText) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // + Add caption
          ElevatedButton.icon(
            onPressed: controller.addCueAtCurrentTime,
            icon: const Icon(Icons.add, size: 16, color: AppColors.textLink),
            label: const Text(
              'Add caption',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textLink,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.infoContainer,
              foregroundColor: AppColors.textLink,
              side: const BorderSide(color: AppColors.info),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
          const SizedBox(width: 8),

          // ✨ Generate with AI
          ElevatedButton.icon(
            onPressed: () {
              GenerateAiSubtitlesModal.show(
                context,
                controller,
                isDarkMode: isDarkMode,
              );
            },
            icon: const Icon(
              Icons.auto_awesome_rounded,
              size: 15,
              color: Colors.white,
            ),
            label: const Text(
              'Generate with AI',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bgSurface,
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppColors.bgDivider),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
          const SizedBox(width: 8),

          // 📄 Import file
          ElevatedButton.icon(
            onPressed: controller.importSubtitleFile,
            icon: const Icon(
              Icons.upload_file_outlined,
              size: 16,
              color: Colors.white,
            ),
            label: const Text(
              'Import file',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bgSurface,
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppColors.bgDivider),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
          const SizedBox(width: 16),

          // Search icon toggle
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 20, color: Colors.white),
            tooltip: 'Search captions',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: controller.toggleCuesSearch,
          ),
          const SizedBox(width: 12),

          // Undo icon
          Obx(() {
            final canUndo = controller.canUndo;
            return IconButton(
              icon: Icon(
                Icons.undo_rounded,
                size: 20,
                color: canUndo ? Colors.white : Colors.white30,
              ),
              tooltip: 'Undo',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: canUndo ? controller.undo : null,
            );
          }),
          const SizedBox(width: 12),

          // Redo icon
          Obx(() {
            final canRedo = controller.canRedo;
            return IconButton(
              icon: Icon(
                Icons.redo_rounded,
                size: 20,
                color: canRedo ? Colors.white : Colors.white30,
              ),
              tooltip: 'Redo',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: canRedo ? controller.redo : null,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableHeader(Color secondaryText, Color borderColor) {
    return Obx(() {
      final isAllSelected = controller.selectedCueIds.length == controller.currentCues.length &&
          controller.currentCues.isNotEmpty;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: AppColors.bgSurface,
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isAllSelected,
                onChanged: (_) => controller.toggleSelectAllCues(),
                activeColor: AppColors.textLink,
                checkColor: Colors.black,
                side: const BorderSide(color: AppColors.textDisabled),
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 80,
              child: Text(
                'Start time',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: secondaryText,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: Text(
                'End time',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: secondaryText,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Subtitle text',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: secondaryText,
                ),
              ),
            ),
            const SizedBox(width: 32),
          ],
        ),
      );
    });
  }

  Widget _buildDesktopCueRow(
    SubtitleCue cue,
    int index,
    bool isActive,
    bool isSelected,
    Color primaryText,
    Color secondaryText,
  ) {
    final startDisplay = _formatShortTime(cue.startTime);
    final endDisplay = _formatShortTime(cue.endTime);

    return Obx(() {
      final zoom = controller.cueZoomScale.value;
      final verticalPadding = (6 * zoom).clamp(4.0, 14.0);

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: verticalPadding),
        child: Row(
          children: [
            // Checkbox
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => controller.toggleSelectCue(cue.id),
                activeColor: AppColors.textLink,
                checkColor: Colors.black,
                side: const BorderSide(color: AppColors.textDisabled),
              ),
            ),
            const SizedBox(width: 14),

            // Start time
            SizedBox(
              width: 80,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => controller.seekToCue(index),
                child: Text(
                  startDisplay,
                  style: TextStyle(
                    fontSize: 13,
                    color: primaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // End time
            SizedBox(
              width: 80,
              child: Text(
                endDisplay,
                style: TextStyle(
                  fontSize: 13,
                  color: primaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Subtitle text field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isActive ? AppColors.textLink : AppColors.bgDivider,
                    width: isActive ? 1.5 : 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: TextFormField(
                  initialValue: cue.text,
                  key: ValueKey('${cue.id}_${cue.text}'),
                  style: TextStyle(
                    fontSize: 13,
                    color: primaryText,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (newText) => controller.updateCueText(index, newText),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 3-dots row menu
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: secondaryText,
              ),
              color: AppColors.bgSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'seek',
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Seek to caption', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'set_start',
                  child: Row(
                    children: [
                      Icon(Icons.first_page_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Set start to current time', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'set_end',
                  child: Row(
                    children: [
                      Icon(Icons.last_page_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Set end to current time', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Duplicate caption', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Delete caption', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ],
                  ),
                ),
              ],
              onSelected: (val) {
                if (val == 'seek') {
                  controller.seekToCue(index);
                } else if (val == 'set_start') {
                  controller.setStartToCurrentTime(index);
                } else if (val == 'set_end') {
                  controller.setEndToCurrentTime(index);
                } else if (val == 'duplicate') {
                  controller.duplicateCue(index);
                } else if (val == 'delete') {
                  controller.deleteCue(index);
                }
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildMobileCueRow(
    SubtitleCue cue,
    int index,
    bool isActive,
    bool isSelected,
    Color primaryText,
    Color secondaryText,
  ) {
    final startDisplay = _formatShortTime(cue.startTime);
    final endDisplay = _formatShortTime(cue.endTime);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => controller.seekToCue(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$startDisplay → $endDisplay',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textLink,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white60),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => controller.deleteCue(index),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isActive ? AppColors.textLink : AppColors.bgDivider,
                width: isActive ? 1.5 : 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: TextFormField(
              initialValue: cue.text,
              key: ValueKey('${cue.id}_${cue.text}'),
              style: TextStyle(fontSize: 13, color: primaryText),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (newText) => controller.updateCueText(index, newText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControlBar(Color primaryText, Color secondaryText, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Obx(() {
        final currentPos = controller.currentVideoPosition.value;
        final formattedPos = _formatShortTime(
          SubtitlesControllerBase.formatDurationToTimecode(currentPos),
        );
        final zoom = controller.cueZoomScale.value;

        return Row(
          children: [
            // Current position timecode badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Text(
                formattedPos,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Undo
            OutlinedButton.icon(
              onPressed: controller.canUndo ? controller.undo : null,
              icon: Icon(
                Icons.undo_rounded,
                size: 14,
                color: controller.canUndo ? Colors.white : Colors.white24,
              ),
              label: Text(
                'Undo',
                style: TextStyle(
                  fontSize: 12,
                  color: controller.canUndo ? Colors.white : Colors.white24,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.bgDivider),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(width: 8),

            // Redo
            OutlinedButton.icon(
              onPressed: controller.canRedo ? controller.redo : null,
              icon: Icon(
                Icons.redo_rounded,
                size: 14,
                color: controller.canRedo ? Colors.white : Colors.white24,
              ),
              label: Text(
                'Redo',
                style: TextStyle(
                  fontSize: 12,
                  color: controller.canRedo ? Colors.white : Colors.white24,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.bgDivider),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const Spacer(),

            // Zoom Controls
            IconButton(
              icon: const Icon(Icons.remove, size: 16, color: Colors.white70),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: controller.zoomOut,
            ),
            SizedBox(
              width: 100,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2.5,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  activeTrackColor: Colors.white70,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                ),
                child: Slider(
                  value: zoom,
                  min: 0.7,
                  max: 1.5,
                  onChanged: controller.setZoomScale,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 16, color: Colors.white70),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: controller.zoomIn,
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.search_rounded,
              size: 18,
              color: Colors.white70,
            ),
          ],
        );
      }),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color primaryText, Color secondaryText) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.subtitles_off_rounded,
              size: 44,
              color: Colors.white54,
            ),
            const SizedBox(height: 12),
            Text(
              'No captions in this track yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Click "+ Add caption" or "Generate with AI" to get started.',
              style: TextStyle(fontSize: 13, color: secondaryText),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: controller.addCueAtCurrentTime,
                  icon: const Icon(Icons.add, size: 16, color: Colors.black),
                  label: const Text(
                    'Add First Caption',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    GenerateAiSubtitlesModal.show(
                      context,
                      controller,
                      isDarkMode: isDarkMode,
                    );
                  },
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                  label: const Text('Generate with AI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bgSurfaceHigh,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatShortTime(String timecode) {
    final parts = timecode.split(':');
    if (parts.length >= 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts[1];
      final s = parts[2];
      final dotIdx = s.indexOf('.');
      final sFormatted = dotIdx != -1 ? s.substring(0, dotIdx + 2) : s;
      if (h > 0) {
        return '$h:$m:$sFormatted';
      }
      final mInt = int.tryParse(m) ?? 0;
      return '$mInt:$sFormatted';
    }
    return timecode;
  }
}
