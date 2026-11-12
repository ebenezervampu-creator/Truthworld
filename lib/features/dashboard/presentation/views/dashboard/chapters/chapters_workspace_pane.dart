import 'dart:ui' show lerpDouble;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/chapters_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/chapters/chapter_dialogs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/chapters/chapters_timeline_view.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Workspace pane showing empty selection state or active chapters editor.
class ChaptersWorkspacePane extends StatelessWidget {
  const ChaptersWorkspacePane({
    required this.controller,
    required this.surfaceColor,
    required this.textColor,
    required this.textSecondaryColor,
    required this.borderColor,
    required this.isDarkMode,
    required this.isMobile,
    super.key,
  });

  final ChaptersController controller;
  final Color surfaceColor;
  final Color textColor;
  final Color textSecondaryColor;
  final Color borderColor;
  final bool isDarkMode;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.selectedVideo.value;
      if (selected == null) {
        return buildEmptySelectionState();
      }
      return _buildActiveWorkspace(context);
    });
  }

  Widget buildEmptySelectionState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bookmarks_outlined,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Select a video to edit chapters',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Select a video from the sidebar menu to view existing chapters, create new chronological chapters, or use AI auto-detection to partition your content.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: textSecondaryColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveWorkspace(BuildContext context) {
    final video = controller.selectedVideo.value!;

    return Stack(
      children: [
        Column(
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: video.thumbnailUrl,
                      width: 50,
                      height: 30,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                video.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                            Obx(() {
                              if (!controller.hasUnsavedChanges.value) {
                                return const SizedBox.shrink();
                              }
                              return Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.warning.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Unsaved',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.warning,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Duration: ${video.duration}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brand,
                                ),
                              ),
                            ),
                            if (!isMobile) ...[
                              const SizedBox(width: 8),
                              Text(
                                '•',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondaryColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Manage content chapters & segment timestamps',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions row (Desktop)
                  if (!isMobile) ...[
                    IconButton(
                      icon: Icon(
                        Icons.download_rounded,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      tooltip: 'Import from description',
                      onPressed: () => ChapterDialogs.showImportDialog(
                        context,
                        controller: controller,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.upload_rounded,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      tooltip: 'Export timestamps',
                      onPressed: controller.exportToClipboard,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.psychology,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      tooltip: 'AI Auto-Detect Chapters',
                      onPressed: controller.autoDetectChapters,
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Save Button
                  Obx(() {
                    return ElevatedButton.icon(
                      onPressed: controller.isSaving.value
                          ? null
                          : controller.saveChapters,
                      icon: controller.isSaving.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.save_rounded,
                              size: 18,
                              color: Colors.black,
                            ),
                      label: Text(
                        controller.isSaving.value
                            ? 'Saving...'
                            : (isMobile ? 'Save' : 'Save Changes'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Mobile specific visual ribbon for actions
            if (isMobile)
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () => ChapterDialogs.showImportDialog(
                        context,
                        controller: controller,
                        isDarkMode: isDarkMode,
                      ),
                      icon: Icon(
                        Icons.download_rounded,
                        size: 16,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      label: Text(
                        'Import',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const VerticalDivider(),
                    TextButton.icon(
                      onPressed: controller.exportToClipboard,
                      icon: Icon(
                        Icons.upload_rounded,
                        size: 16,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      label: Text(
                        'Export',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const VerticalDivider(),
                    TextButton.icon(
                      onPressed: controller.autoDetectChapters,
                      icon: Icon(
                        Icons.psychology,
                        size: 16,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      label: Text(
                        'AI Auto',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // YouTube-style Automatic Chapters Toggle Bar
            _buildAutoChaptersBar(context),

            // Chapters List & Timeline Editor
            Expanded(
              child: Obx(() {
                if (controller.currentChapters.isEmpty) {
                  return ChaptersTimelineView.buildEmptyTimelineState(
                    context,
                    controller: controller,
                    textColor: textColor,
                    textSecondaryColor: textSecondaryColor,
                    isDarkMode: isDarkMode,
                  );
                }

                return ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 24,
                    vertical: 16,
                  ),
                  itemCount: controller.currentChapters.length,
                  footer: ChaptersTimelineView.buildAddChapterButton(
                    context,
                    controller: controller,
                    borderColor: borderColor,
                    isDarkMode: isDarkMode,
                    isMobile: isMobile,
                  ),
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final animValue = Curves.easeInOut.transform(
                          animation.value,
                        );
                        final elevation = lerpDouble(0, 8, animValue)!;
                        final scale = lerpDouble(1, 1.02, animValue)!;
                        return Transform.scale(
                          scale: scale,
                          child: Material(
                            elevation: elevation,
                            color: Colors.transparent,
                            shadowColor: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.brand.withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                              ),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: child,
                    );
                  },
                  onReorder: controller.reorderChapter,
                  itemBuilder: (context, index) {
                    final chapter = controller.currentChapters[index];
                    return KeyedSubtree(
                      key: ValueKey(
                        'chapter_${chapter.startTime.inMilliseconds}_${chapter.title}_$index',
                      ),
                      child: ChaptersTimelineView.buildTimelineRow(
                        context,
                        controller: controller,
                        index: index,
                        chapter: chapter,
                        total: controller.currentChapters.length,
                        textColor: textColor,
                        textSecondaryColor: textSecondaryColor,
                        borderColor: borderColor,
                        surfaceColor: surfaceColor,
                        isDarkMode: isDarkMode,
                        isMobile: isMobile,
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),

        // AI Analyzing Overlay
        Obx(() {
          if (!controller.isAnalyzing.value) return const SizedBox.shrink();
          return ColoredBox(
            color: AppColors.bgPage.withValues(alpha: 0.6),
            child: Center(
              child: Card(
                color: isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.brand,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'AI Timeline Analysis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scanning audio track & computing semantic chapters...',
                        style: TextStyle(
                          fontSize: 14,
                          color: textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAutoChaptersBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppColors.bgSurface.withValues(alpha: 0.6)
            : Colors.grey.shade200,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            size: 18,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Automatic Chapters',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Obx(() {
                      final hasManual = controller.currentChapters.isNotEmpty;
                      final isAutoOn = controller.autoChaptersEnabled.value;

                      String badgeText;
                      Color badgeColor;
                      Color badgeTextColor;

                      if (hasManual) {
                        badgeText = 'Manual Override Active';
                        badgeColor = AppColors.success.withValues(alpha: 0.15);
                        badgeTextColor = AppColors.success;
                      } else if (!isAutoOn) {
                        badgeText = 'Auto-Chapters Off';
                        badgeColor = AppColors.error.withValues(alpha: 0.15);
                        badgeTextColor = AppColors.error;
                      } else {
                        badgeText = 'AI Auto Fallback';
                        badgeColor = AppColors.info.withValues(alpha: 0.15);
                        badgeTextColor = AppColors.info;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: badgeTextColor,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                Text(
                  'Manual description timestamps (0:00, 0:10, 0:20) always override auto-chapters. Turning off hides auto-chapters.',
                  style: TextStyle(
                    fontSize: 11,
                    color: textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Obx(
            () => Switch(
              value: controller.autoChaptersEnabled.value,
              onChanged: controller.toggleAutoChapters,
              activeColor: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}
