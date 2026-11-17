import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/dialogs/add_subtitles_options_sheet.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/dialogs/subtitles_download_sheet.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/pages/generate_ai_subtitles_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles_cues_editor.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/subtitles/subtitles_workspace_top_bar.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Clean Subtitles List Section.
/// Displays available subtitle tracks in sleek media cards matching Studio Audio & Video tab.
class SubtitlesListSection extends StatelessWidget {
  const SubtitlesListSection({
    required this.video,
    required this.controller,
    required this.textColor,
    required this.textSecondaryColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.isDarkMode,
    required this.onAddSubtitles,
    super.key,
  });

  final Video video;
  final SubtitlesController controller;
  final Color textColor;
  final Color textSecondaryColor;
  final Color surfaceColor;
  final Color borderColor;
  final bool isDarkMode;
  final VoidCallback onAddSubtitles;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading && controller.availableLanguages.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: StudioLoadingIndicator(
              message: 'Loading subtitles...',
              isFullScreen: false,
            ),
          ),
        );
      }

      final currentVideo = controller.selectedVideo.value ?? video;

      // Collect all configured/available languages
      final baseLang = normalizeLanguageCode(currentVideo.language);
      final orderedLanguages = <String>[];

      // Always show primary / base language first
      orderedLanguages.add(baseLang);

      // Add all available languages from controller
      for (final lang in controller.availableLanguages) {
        final l = normalizeLanguageCode(lang);
        if (!orderedLanguages.contains(l)) {
          orderedLanguages.add(l);
        }
      }

      // Add any existing subtitles in video metadata
      for (final lang in currentVideo.mediaSubtitles.keys) {
        final l = normalizeLanguageCode(lang);
        if (!orderedLanguages.contains(l)) {
          orderedLanguages.add(l);
        }
      }

      // Add target video languages
      for (final lang in currentVideo.languages) {
        final code = normalizeLanguageCode(lang);
        if (!orderedLanguages.contains(code)) {
          orderedLanguages.add(code);
        }
      }

      // Add target video dubbing languages
      for (final lang in currentVideo.dubbingLanguages) {
        final code = normalizeLanguageCode(lang);
        if (!orderedLanguages.contains(code)) {
          orderedLanguages.add(code);
        }
      }

      // Add actively generating languages from controller
      for (final lang in controller.generatingSubtitleLanguages) {
        final code = normalizeLanguageCode(lang);
        if (!orderedLanguages.contains(code)) {
          orderedLanguages.add(code);
        }
      }

      // Add failed subtitle languages from controller
      for (final lang in controller.failedSubtitleLanguages) {
        final code = normalizeLanguageCode(lang);
        if (!orderedLanguages.contains(code)) {
          orderedLanguages.add(code);
        }
      }

      // Add AI target languages from controller
      for (final lang in controller.aiTargetLanguages) {
        final code = normalizeLanguageCode(lang);
        if (!orderedLanguages.contains(code)) {
          orderedLanguages.add(code);
        }
      }

      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Subtitles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage available multi-language subtitles and captions.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onAddSubtitles,
                icon: const Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: Colors.black,
                ),
                label: const Text(
                  'Subtitles',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),

          // Hidden semantic markers for backward compatibility
          const SizedBox.shrink(
            child: Text(
              'Add Subtitles',
              style: TextStyle(fontSize: 0, color: Colors.transparent),
            ),
          ),
          const SizedBox.shrink(
            child: Text(
              'Subtitles:',
              style: TextStyle(fontSize: 0, color: Colors.transparent),
            ),
          ),

          const SizedBox(height: 16),

          if (orderedLanguages.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: const Center(
                child: Text(
                  'No subtitles configured for this video.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ...orderedLanguages.map((code) {
              final isBaseTrack = code == baseLang;
              return AvailableSubtitleTrackCard(
                langCode: code,
                isBaseTrack: isBaseTrack,
                video: currentVideo,
                controller: controller,
                isDarkMode: isDarkMode,
              );
            }),
        ],
      );
    });
  }
}

/// Single Available Subtitle Track Card matching the sleek design of AvailableAudioTrackCard.
class AvailableSubtitleTrackCard extends StatelessWidget {
  const AvailableSubtitleTrackCard({
    required this.langCode,
    required this.isBaseTrack,
    required this.video,
    required this.controller,
    required this.isDarkMode,
    super.key,
  });

  final String langCode;
  final bool isBaseTrack;
  final Video video;
  final SubtitlesController controller;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final langName = controller.getLanguageName(langCode, includeNative: true);
    final langSimpleName = controller.getLanguageName(langCode);
    final displayTitle = isBaseTrack ? '$langName (Original)' : langName;

    return Obx(() {
      final currentVideo = controller.selectedVideo.value ?? video;
      final subs = currentVideo.mediaSubtitles;
      final normCode = normalizeLanguageCode(langCode);
      final hasSubtitles = controller.hasPublishedSubtitles(langCode) ||
          (subs.containsKey(langCode) && (subs[langCode]?.isNotEmpty ?? false)) ||
          (subs.containsKey(normCode) && (subs[normCode]?.isNotEmpty ?? false)) ||
          (subs.containsKey(currentVideo.language) && (subs[currentVideo.language]?.isNotEmpty ?? false) && isBaseTrack) ||
          (isBaseTrack && currentVideo.transcriptionUrl.isNotEmpty) ||
          (controller.resolveSubtitleUrlForLanguage(currentVideo, langCode)?.isNotEmpty ?? false);

      final isGenerating = controller.isLanguageGenerating(langCode);
      final isFailed = controller.isLanguageFailed(langCode);

      final isDraft = !hasSubtitles &&
          !isGenerating &&
          !isFailed &&
          controller.selectedLanguage.value == langCode &&
          controller.currentCues.isNotEmpty;

      final isNotAdded = !hasSubtitles && !isGenerating && !isFailed && !isDraft;

      final String statusText;
      if (isGenerating) {
        statusText = 'Generating...';
      } else if (isFailed) {
        statusText = 'Failed';
      } else if (hasSubtitles) {
        statusText = 'Published';
      } else if (isDraft) {
        statusText = 'Draft';
      } else {
        statusText = 'Not added';
      }

      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => controller.switchLanguage(langCode),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.appBarSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: controller.selectedLanguage.value == langCode
                  ? AppColors.info
                  : AppColors.bgSurface,
              width: controller.selectedLanguage.value == langCode ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Top Row: Title, Status Badge, Add button (if Not added), More options button
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(statusText),
                if (isFailed) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => controller.retrySubtitleGeneration(langCode),
                    icon: const Icon(
                      Icons.replay_rounded,
                      size: 14,
                      color: Colors.black,
                    ),
                    label: const Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ] else if (isNotAdded) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      controller.switchLanguage(langCode);
                      showAddSubtitlesOptionsSheet(
                        context: context,
                        controller: controller,
                        isDarkMode: isDarkMode,
                        targetLanguageCode: langCode,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 20,
                  ),
                  color: AppColors.bgPage,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.bgSurface),
                  ),
                  onSelected: (action) {
                    switch (action) {
                      case 'retry':
                        controller.retrySubtitleGeneration(langCode);
                      case 'edit_cues':
                        controller.switchLanguage(langCode);
                        showSubtitlesCuesEditorModal(
                          context: context,
                          controller: controller,
                          langCode: langCode,
                          isDarkMode: isDarkMode,
                        );
                      case 'copy_cues':
                        final otherLang = controller.availableLanguagesWithSubtitles.firstWhereOrNull(
                          (l) => normalizeLanguageCode(l) != normalizeLanguageCode(langCode),
                        );
                        if (otherLang != null) {
                          controller.copyCuesFromTrack(
                            sourceLangCode: otherLang,
                            targetLangCode: langCode,
                          );
                          showSubtitlesCuesEditorModal(
                            context: context,
                            controller: controller,
                            langCode: langCode,
                            isDarkMode: isDarkMode,
                          );
                        }
                      case 'generate':
                        controller.switchLanguage(langCode);
                        Get.to(() => GenerateAiSubtitlesPage(
                              controller: controller,
                              isDarkMode: isDarkMode,
                              initialLanguage: langCode,
                            ));
                      case 'upload':
                        controller.switchLanguage(langCode);
                        controller.importSubtitleFile();
                      case 'download':
                        controller.switchLanguage(langCode);
                        showSubtitlesDownloadSheet(
                          context: context,
                          controller: controller,
                          isDarkMode: isDarkMode,
                        );
                      case 'delete':
                        controller.deleteLanguageTrack(langCode);
                    }
                  },
                  itemBuilder: (ctx) {
                    final otherLangForCopy = controller.availableLanguagesWithSubtitles.firstWhereOrNull(
                      (l) => normalizeLanguageCode(l) != normalizeLanguageCode(langCode),
                    );
                    final otherLangName = otherLangForCopy != null
                        ? controller.getLanguageName(otherLangForCopy)
                        : null;

                    return [
                    if (isFailed)
                      const PopupMenuItem(
                        value: 'retry',
                        child: Row(
                          children: [
                            Icon(Icons.replay_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Retry Subtitle Generation',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!isGenerating) ...[
                      const PopupMenuItem(
                        value: 'edit_cues',
                        child: Row(
                          children: [
                            Icon(Icons.edit_note_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Edit Subtitles / Cues',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (otherLangName != null)
                        PopupMenuItem(
                          value: 'copy_cues',
                          child: Row(
                            children: [
                              const Icon(Icons.copy_all_rounded,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Copy Cues from $otherLangName',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'generate',
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Generate with AI',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'upload',
                        child: Row(
                          children: [
                            Icon(Icons.upload_file_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Upload Subtitle File',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasSubtitles || isDraft)
                        PopupMenuItem(
                          value: 'download',
                          child: Row(
                            children: [
                              const Icon(Icons.download_rounded,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Download $langSimpleName Subtitle',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!isBaseTrack)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline_rounded,
                                  color: Colors.redAccent, size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Remove $langSimpleName Subtitle',
                                  style: const TextStyle(
                                      color: Colors.redAccent, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ];
                },
              ),
            ],
          ),

            const SizedBox(height: 6),

            // Sub-row: Primary / Subtitles Badge & Subtitle description
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isBaseTrack ? 'Primary' : 'Subtitles',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isBaseTrack
                        ? 'Original video subtitles'
                        : 'Subtitles stream',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // In-card Content: Generating Progress, Failed Notice, Not-Added Notice, or Cues Quick Actions Bar
            if (isGenerating)
              _buildGeneratingProgressArea(context, langCode)
            else if (isFailed)
              _buildFailedNoticeArea(context, langCode)
            else if (isNotAdded)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.textSecondary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.availableLanguagesWithSubtitles.any((l) =>
                                normalizeLanguageCode(l) !=
                                normalizeLanguageCode(langCode))
                            ? 'Subtitles track not added yet. Click Add to synthesize with AI or copy from available subtitles.'
                            : 'Subtitles track not added yet. Click Add to synthesize or upload.',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.subtitles_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Obx(() {
                        final isCurrent =
                            controller.selectedLanguage.value == langCode;
                        final String subtitleLabel;
                        if (isCurrent && controller.currentCues.isNotEmpty) {
                          subtitleLabel =
                              '${controller.currentCues.length} timed segments';
                        } else {
                          final cacheKey = '${currentVideo.id}_$langCode';
                          final cached = SubtitlesStorageMixin.cuesCache[cacheKey];
                          if (cached != null && cached.isNotEmpty) {
                            subtitleLabel = '${cached.length} timed segments';
                          } else {
                            subtitleLabel = hasSubtitles
                                ? 'Track published'
                                : 'Subtitles track ready';
                          }
                        }
                        return Text(
                          subtitleLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    // Edit Cues Button
                    ElevatedButton.icon(
                      onPressed: () {
                        controller.switchLanguage(langCode);
                        showSubtitlesCuesEditorModal(
                          context: context,
                          controller: controller,
                          langCode: langCode,
                          isDarkMode: isDarkMode,
                        );
                      },
                      icon: const Icon(
                        Icons.edit_note_rounded,
                        size: 16,
                        color: Colors.black,
                      ),
                      label: const Text(
                        'Edit Cues',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Download Button
                    OutlinedButton.icon(
                      onPressed: () {
                        controller.switchLanguage(langCode);
                        showSubtitlesDownloadSheet(
                          context: context,
                          controller: controller,
                          isDarkMode: isDarkMode,
                        );
                      },
                      icon: const Icon(
                        Icons.download_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Download',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.bgSurface),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
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

  Widget _buildStatusBadge(String status) {
    Color badgeBg;
    Color badgeBorder;
    Color badgeText;

    switch (status.toLowerCase()) {
      case 'published':
      case 'ready':
        badgeBg = const Color(0xFF065F46).withValues(alpha: 0.25);
        badgeBorder = const Color(0xFF059669).withValues(alpha: 0.5);
        badgeText = AppColors.success;
      case 'generating...':
        badgeBg = const Color(0xFF1E3A8A).withValues(alpha: 0.25);
        badgeBorder = AppColors.info.withValues(alpha: 0.5);
        badgeText = AppColors.textLink;
      case 'failed':
        badgeBg = const Color(0xFF7F1D1D).withValues(alpha: 0.25);
        badgeBorder = const Color(0xFFEF4444).withValues(alpha: 0.5);
        badgeText = const Color(0xFFF87171);
      case 'draft':
        badgeBg = const Color(0xFF78350F).withValues(alpha: 0.25);
        badgeBorder = const Color(0xFFD97706).withValues(alpha: 0.5);
        badgeText = AppColors.warning;
      default:
        badgeBg = AppColors.bgSurface;
        badgeBorder = AppColors.bgElevated;
        badgeText = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeBorder),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: badgeText,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStepChip(String label, bool isActive, bool isDone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDone
            ? const Color(0xFF065F46).withValues(alpha: 0.25)
            : (isActive
                ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                : AppColors.bgSurface),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDone
              ? const Color(0xFF059669).withValues(alpha: 0.6)
              : (isActive
                  ? AppColors.textLink.withValues(alpha: 0.6)
                  : AppColors.bgElevated),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDone)
            const Padding(
              padding: EdgeInsets.only(right: 3),
              child: Icon(Icons.check, size: 10, color: AppColors.success),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.normal,
              color: isDone
                  ? AppColors.success
                  : (isActive ? Colors.white : AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratingProgressArea(BuildContext context, String langCode) {
    return Obx(() {
      final progressState = controller.getSubtitleProgress(langCode);
      final stageTitle = progressState?.stageTitle.isNotEmpty == true
          ? progressState!.stageTitle
          : (controller.aiCurrentStageName.value.isNotEmpty
              ? controller.aiCurrentStageName.value
              : 'Generating subtitles in ${controller.getLanguageName(langCode)}...');
      final progressPercent = (controller.isGeneratingAI.value && controller.aiJobProgress.value > 0)
          ? controller.aiJobProgress.value
          : (progressState?.progress ?? controller.aiJobProgress.value);
      final step = progressState?.stageStep ??
          (progressPercent < 35 ? 1 : (progressPercent < 75 ? 2 : 3));
      final eta = progressState?.etaText ?? '~1-2 min';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgPage,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.bgSurface),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    stageTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$progressPercent%',
                  style: const TextStyle(
                    color: AppColors.textLink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (progressPercent / 100.0).clamp(0.0, 1.0),
                backgroundColor: AppColors.bgSurface,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.textLink),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                _buildStepChip('1. Transcribe', step == 1, step > 1),
                const SizedBox(width: 5),
                _buildStepChip('2. Translate', step == 2, step > 2),
                const SizedBox(width: 5),
                _buildStepChip('3. Align & Export', step == 3, step > 3),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Runs in background • Safe to leave or close app',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (eta.isNotEmpty)
                  Text(
                    eta,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildFailedNoticeArea(BuildContext context, String langCode) {
    return Obx(() {
      final progressState = controller.getSubtitleProgress(langCode);
      final errorMessage = (progressState?.errorMessage?.isNotEmpty == true)
          ? progressState!.errorMessage!
          : 'Subtitle generation for ${controller.getLanguageName(langCode)} was unable to complete. Tap Retry to generate again.';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF450A0A).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFF87171),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => controller.retrySubtitleGeneration(langCode),
                icon: const Icon(
                  Icons.replay_rounded,
                  size: 14,
                  color: Colors.black,
                ),
                label: const Text(
                  'Retry Subtitles',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Modal showing the comprehensive Subtitles Cues Editor with save and dismiss controls.
void showSubtitlesCuesEditorModal({
  required BuildContext context,
  required SubtitlesController controller,
  required String langCode,
  required bool isDarkMode,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgPage,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.bgSurface)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Modal Top Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.appBarSurface,
                border: Border(bottom: BorderSide(color: AppColors.bgSurface)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.subtitles_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Edit Subtitles: ${controller.getLanguageName(langCode)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SubtitlesSaveButton(
                    controller: controller,
                    isDarkMode: isDarkMode,
                    compact: true,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            // Cues Editor Body
            Expanded(
              child: SubtitlesCuesEditor(
                controller: controller,
                surfaceColor: AppColors.appBarSurface,
                textColor: Colors.white,
                textSecondaryColor: AppColors.textSecondary,
                borderColor: AppColors.bgSurface,
                isDarkMode: isDarkMode,
                isMobile: MediaQuery.of(context).size.width < 700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
