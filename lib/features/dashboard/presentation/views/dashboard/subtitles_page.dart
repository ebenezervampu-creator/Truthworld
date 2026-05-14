import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class SubtitlesPage extends StatefulWidget {
  final String channelId;
  final bool isDarkMode;

  const SubtitlesPage({
    super.key,
    required this.channelId,
    required this.isDarkMode,
  });

  @override
  State<SubtitlesPage> createState() => _SubtitlesPageState();
}

class _SubtitlesPageState extends State<SubtitlesPage> {
  late final SubtitlesController controller;

  @override
  void initState() {
    super.initState();
    // Use Get.put to instantiate and bind the controller
    controller = Get.put(SubtitlesController());
    controller.setChannelContext(widget.channelId);
  }

  @override
  void didUpdateWidget(SubtitlesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId != widget.channelId) {
      controller.setChannelContext(widget.channelId);
    }
  }

  bool get isMobile => MediaQuery.of(context).size.width < 600;
  bool get isTablet =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;
  bool get isDesktop => MediaQuery.of(context).size.width >= 1024;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode
        ? AppColors.bgPage
        : AppColors.bgPage;
    final surfaceColor = widget.isDarkMode
        ? AppColors.bgSurface
        : Colors.white;
    final textColor = widget.isDarkMode
        ? AppColors.textPrimary
        : AppColors.textPrimary;
    final textSecondaryColor = widget.isDarkMode
        ? AppColors.textSecondary
        : AppColors.textSecondary;
    final borderColor = widget.isDarkMode
        ? AppColors.bgDivider
        : AppColors.bgDivider;

    return Scaffold(
      backgroundColor: bgColor,
      body: Obx(() {
        if (controller.isLoading) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.brand,
              ),
            ),
          );
        }

        if (controller.isError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage.isNotEmpty
                      ? controller.errorMessage
                      : 'An error occurred loading subtitles',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => controller.onInit(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (controller.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.subtitles_off_rounded,
                  size: 80,
                  color: textSecondaryColor.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 20),
                Text(
                  'No Videos Found',
                  style: GoogleFonts.roboto(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload videos to your channel to manage subtitles.',
                  style: GoogleFonts.roboto(
                    fontSize: 15,
                    color: textSecondaryColor,
                  ),
                ),
              ],
            ),
          );
        }

        return isDesktop || isTablet
            ? _buildDesktopLayout(
                surfaceColor,
                textColor,
                textSecondaryColor,
                borderColor,
              )
            : _buildMobileLayout(
                surfaceColor,
                textColor,
                textSecondaryColor,
                borderColor,
              );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP & TABLET SPLIT-SCREEN LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopLayout(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Video List Selector
        Container(
          width: isDesktop ? 380 : 300,
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(right: BorderSide(color: borderColor)),
          ),
          child: Column(
            children: [
              _buildSearchHeader(surfaceColor, textColor, borderColor),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  itemCount: controller.filteredVideos.length,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final video = controller.filteredVideos[index];
                    final isSelected =
                        controller.selectedVideo.value?.id == video.id;
                    return _buildVideoSelectorCard(
                      video: video,
                      isSelected: isSelected,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                      borderColor: borderColor,
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Right Column: Active Video Subtitle Editor
        Expanded(
          child: Container(
            color: widget.isDarkMode
                ? AppColors.bgPage
                : const Color(0xFFF1F5F9),
            child: controller.selectedVideo.value == null
                ? _buildEmptySelectionState(textColor, textSecondaryColor)
                : _buildSubtitleWorkspace(
                    surfaceColor,
                    textColor,
                    textSecondaryColor,
                    borderColor,
                  ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOBILE SINGLE-VIEW LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileLayout(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    return controller.selectedVideo.value == null
        ? Column(
            children: [
              _buildSearchHeader(surfaceColor, textColor, borderColor),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: controller.filteredVideos.length,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final video = controller.filteredVideos[index];
                    return _buildVideoSelectorCard(
                      video: video,
                      isSelected: false,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                      borderColor: borderColor,
                    );
                  },
                ),
              ),
            ],
          )
        : Column(
            children: [
              // Back banner to return to video list
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: surfaceColor,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.brand,
                      ),
                      onPressed: () => controller.selectVideo(null),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.selectedVideo.value?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: borderColor),
              Expanded(
                child: _buildSubtitleWorkspace(
                  surfaceColor,
                  textColor,
                  textSecondaryColor,
                  borderColor,
                ),
              ),
            ],
          );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPONENTS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSearchHeader(
    Color surfaceColor,
    Color textColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.subtitles_rounded,
                color: AppColors.brand,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Select Video',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? const Color(0xFF242424)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              style: GoogleFonts.roboto(fontSize: 14, color: textColor),
              decoration: InputDecoration(
                hintText: 'Search videos...',
                hintStyle: GoogleFonts.roboto(
                  fontSize: 14,
                  color: widget.isDarkMode
                      ? Colors.white54
                      : const Color(0xFF94A3B8),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: widget.isDarkMode
                      ? Colors.white54
                      : const Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onChanged: (value) => controller.setSearchQuery(value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSelectorCard({
    required Video video,
    required bool isSelected,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
  }) {
    final trackCount = video.mediaSubtitles.length;

    return InkWell(
      onTap: () => controller.selectVideo(video),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.brand.withValues(alpha: 0.5)
                : borderColor.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with Duration overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: 100,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Container(
                          color: widget.isDarkMode
                              ? const Color(0xFF2A2A2A)
                              : AppColors.bgDivider,
                        ),
                    errorWidget:
                        (context, url, error) => Container(
                          color: widget.isDarkMode
                              ? const Color(0xFF2A2A2A)
                              : AppColors.bgDivider,
                          child: const Icon(
                            Icons.video_file_rounded,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Video Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.brand : textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        DateFormat(
                          'MMM d, yyyy',
                        ).format(video.uploadedAt.toDate()),
                        style: GoogleFonts.roboto(
                          fontSize: 11,
                          color: textSecondaryColor,
                        ),
                      ),
                      const Spacer(),
                      // Subtitle Tracks Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: trackCount > 0
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : textSecondaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.translate_rounded,
                              size: 10,
                              color: trackCount > 0
                                  ? const Color(0xFF10B981)
                                  : textSecondaryColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$trackCount',
                              style: GoogleFonts.roboto(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: trackCount > 0
                                    ? const Color(0xFF10B981)
                                    : textSecondaryColor,
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
      ),
    );
  }

  Widget _buildEmptySelectionState(Color textColor, Color textSecondaryColor) {
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
            child: Icon(
              Icons.touch_app_rounded,
              size: 64,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Select a video to edit subtitles',
            style: GoogleFonts.roboto(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Choose a video from the sidebar menu to view existing translation tracks, add new localized cue timings, and sync directly to your video streams.',
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
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

  Widget _buildSubtitleWorkspace(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    final video = controller.selectedVideo.value!;

    return Column(
      children: [
        // Workspace Top Bar: Video Context & Actions
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
                            style: GoogleFonts.roboto(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        Obx(() {
                          if (!controller.hasUnsavedChanges.value) return const SizedBox.shrink();
                          return Container(
                            margin: const EdgeInsets.only(left: 8, right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'Unsaved',
                              style: GoogleFonts.roboto(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    Text(
                      'Subtitles & Multi-Language Audio Tracks',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Export CTA Button
              OutlinedButton.icon(
                onPressed: () => controller.exportCurrentTrack(),
                icon: const Icon(Icons.copy_all_rounded, size: 16),
                label: const Text('Export VTT'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                ),
              ),
              const SizedBox(width: 8),

              // Save CTA Button
              Obx(() {
                return ElevatedButton.icon(
                  onPressed: controller.isSaving.value
                      ? null
                      : () => controller.saveCurrentSubtitles(),
                  icon: controller.isSaving.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(
                    controller.isSaving.value ? 'Saving...' : 'Save Changes',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                  ),
                );
              }),
            ],
          ),
        ),

        // Language Track Selector Ribbon
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: widget.isDarkMode
                ? const Color(0xFF141414)
                : AppColors.bgDivider,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Text(
                'Tracks:',
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(() {
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.availableLanguages.length,
                    itemBuilder: (context, index) {
                      final code = controller.availableLanguages[index];
                      final isSelected =
                          controller.selectedLanguage.value == code;
                      final langName = controller.getLanguageName(code);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                        child: ChoiceChip(
                          label: Text(langName),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) controller.switchLanguage(code);
                          },
                          selectedColor: AppColors.brand,
                          backgroundColor: surfaceColor,
                          labelStyle: GoogleFonts.roboto(
                            color: isSelected ? Colors.white : textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.brand
                                  : borderColor,
                            ),
                          ),
                          showCheckmark: false,
                        ),
                      );
                    },
                  );
                }),
              ),

              // Add Track Dropdown/Action
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: AppColors.brand,
                tooltip: 'Add Language Track',
                onPressed: () => _showAddLanguageDialog(),
              ),
            ],
          ),
        ),

        // Main Editor Timeline & Rows
        Expanded(
          child: Obx(() {
            if (controller.currentCues.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 48,
                      color: textSecondaryColor.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No Subtitle Cues Defined',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        color: textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => controller.addNewCue(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add First Cue'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Header Table column row
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: surfaceColor.withValues(alpha: 0.4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 180,
                        child: Text(
                          'Timing Interval',
                          style: GoogleFonts.roboto(
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
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textSecondaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Spacing for delete action
                    ],
                  ),
                ),
                Divider(height: 1, color: borderColor),

                // Cues List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: controller.currentCues.length,
                    separatorBuilder:
                        (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final cue = controller.currentCues[index];

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timing display badge with industry-standard adjustment steppers
                            Container(
                              width: 200,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: widget.isDarkMode
                                    ? const Color(0xFF242424)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      InkWell(
                                        onTap: () => controller.shiftCueTiming(index, isStart: true, shiftMilliseconds: -500),
                                        child: Icon(Icons.remove_circle_outline, size: 14, color: textSecondaryColor),
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.timer_outlined,
                                            size: 12,
                                            color: AppColors.brand,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            cue.startTime.split('.').first,
                                            style: GoogleFonts.robotoMono(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      InkWell(
                                        onTap: () => controller.shiftCueTiming(index, isStart: true, shiftMilliseconds: 500),
                                        child: Icon(Icons.add_circle_outline, size: 14, color: textSecondaryColor),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 12,
                                    color: textSecondaryColor,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      InkWell(
                                        onTap: () => controller.shiftCueTiming(index, isStart: false, shiftMilliseconds: -500),
                                        child: Icon(Icons.remove_circle_outline, size: 14, color: textSecondaryColor),
                                      ),
                                      Text(
                                        cue.endTime.split('.').first,
                                        style: GoogleFonts.robotoMono(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: textSecondaryColor,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => controller.shiftCueTiming(index, isStart: false, shiftMilliseconds: 500),
                                        child: Icon(Icons.add_circle_outline, size: 14, color: textSecondaryColor),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Editable Text Cue input
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('${controller.selectedLanguage.value}_${cue.id}_$index'),
                                initialValue: cue.text,
                                maxLines: null,
                                style: GoogleFonts.roboto(
                                  fontSize: 14,
                                  color: textColor,
                                  height: 1.3,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter subtitle text...',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  fillColor: Colors.transparent,
                                ),
                                onChanged:
                                    (val) => controller.updateCueText(
                                      index,
                                      val,
                                    ),
                              ),
                            ),

                            // Delete Cue Action
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              color: textSecondaryColor.withValues(alpha: 0.6),
                              hoverColor: AppColors.error.withValues(
                                alpha: 0.1,
                              ),
                              onPressed: () => controller.deleteCue(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Workspace Bottom Actions
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => controller.addNewCue(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Subtitle Segment'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brand,
                          side: BorderSide(color: AppColors.brand),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  void _showAddLanguageDialog() {
    final availableToAdd =
        supportedLanguages
            .where(
              (lang) =>
                  !controller.availableLanguages.contains(lang.code),
            )
            .toList();

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Subtitle Track',
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a target language to prepare multi-language subtitles or voiceover mapping.',
                style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableToAdd.length,
                  itemBuilder: (context, index) {
                    final lang = availableToAdd[index];
                    return ListTile(
                      title: Text(lang.name),
                      subtitle: Text(lang.nativeName),
                      trailing: const Icon(Icons.add_circle_outline_rounded),
                      onTap: () {
                        Get.back();
                        controller.addLanguageTrack(lang.code);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}






