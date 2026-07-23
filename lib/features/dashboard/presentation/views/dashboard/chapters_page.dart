import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/chapters_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/theme/app_theme.dart';

class ChaptersPage extends StatefulWidget {

  const ChaptersPage({
    required this.channelId, required this.isDarkMode, super.key,
  });
  final String channelId;
  final bool isDarkMode;

  @override
  State<ChaptersPage> createState() => _ChaptersPageState();
}

class _ChaptersPageState extends State<ChaptersPage> {
  late final ChaptersController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(ChaptersController());
    controller.setChannelContext(widget.channelId);
  }

  @override
  void didUpdateWidget(ChaptersPage oldWidget) {
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
    final bgColor = widget.isDarkMode ? AppColors.bgPage : AppColors.bgPage;
    final surfaceColor = widget.isDarkMode ? AppColors.bgSurface : AppColors.textPrimary;
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
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
            ),
          );
        }

        if (controller.isError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  controller.errorMessage.isNotEmpty
                      ? controller.errorMessage
                      : 'An error occurred loading chapters',
                  style: TextStyle(
                    
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
                  Icons.bookmarks_outlined,
                  size: 80,
                  color: textSecondaryColor.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 20),
                Text(
                  'No Videos Found',
                  style: TextStyle(
                    
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload videos to your channel to manage chapters.',
                  style: TextStyle(
                    
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
  // DESKTOP SPLIT LAYOUT
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
        // Left Column: Video List
        Container(
          width: isDesktop ? 380 : 300,
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(right: BorderSide(color: borderColor)),
          ),
          child: Column(
            children: [
              _buildSearchHeader(surfaceColor, textColor, borderColor),
              _buildFilterChips(
                surfaceColor,
                textColor,
                textSecondaryColor,
                borderColor,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  itemCount: controller.filteredVideos.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
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

        // Right Column: Workspace
        Expanded(
          child: ColoredBox(
            color: widget.isDarkMode
                ? AppColors.bgPage
                : const Color(0xFFF1F5F9),
            child: controller.selectedVideo.value == null
                ? _buildEmptySelectionState(textColor, textSecondaryColor)
                : _buildChaptersWorkspace(
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
  // MOBILE SINGLE PAGE LAYOUT
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
              _buildFilterChips(
                surfaceColor,
                textColor,
                textSecondaryColor,
                borderColor,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: controller.filteredVideos.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
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
              // Back Button Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: surfaceColor,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.brand,
                      ),
                      onPressed: () => controller.selectVideo(null),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.selectedVideo.value?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          
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
                child: _buildChaptersWorkspace(
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
  // SEARCH & FILTER WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSearchHeader(
    Color surfaceColor,
    Color textColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmarks_rounded, color: AppColors.brand, size: 22),
              const SizedBox(width: 8),
              Text(
                'Video Chapters',
                style: TextStyle(
                  
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
              style: TextStyle(
                
                fontSize: 14,
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: 'Search videos...',
                hintStyle: TextStyle(
                  
                  fontSize: 14,
                  color: widget.isDarkMode
                      ? AppColors.textSecondary
                      : const Color(0xFF94A3B8),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: widget.isDarkMode
                      ? AppColors.textSecondary
                      : const Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
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

  Widget _buildFilterChips(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    return Container(
      width: double.infinity,
      color: surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Obx(() {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                'all',
                'All Videos',
                surfaceColor,
                textColor,
                textSecondaryColor,
                borderColor,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'has_chapters',
                'With Chapters',
                surfaceColor,
                textColor,
                textSecondaryColor,
                borderColor,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'no_chapters',
                'No Chapters',
                surfaceColor,
                textColor,
                textSecondaryColor,
                borderColor,
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildFilterChip(
    String type,
    String label,
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    final isSelected = controller.filterType.value == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) controller.setFilterType(type);
      },
      selectedColor: AppColors.brand,
      backgroundColor: surfaceColor,
      labelStyle: TextStyle(
        
        color: isSelected ? AppColors.textPrimary : textColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isSelected ? AppColors.brand : borderColor),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildVideoSelectorCard({
    required Video video,
    required bool isSelected,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
  }) {
    final chapterCount = video.chapters.length;

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
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: 100,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: widget.isDarkMode
                          ? const Color(0xFF2A2A2A)
                          : AppColors.bgDivider,
                    ),
                    errorWidget: (context, url, error) => ColoredBox(
                      color: widget.isDarkMode
                          ? const Color(0xFF2A2A2A)
                          : AppColors.bgDivider,
                      child: const Icon(
                        Icons.video_file_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
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
                      color: AppColors.bgPage.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
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
                        style: TextStyle(
                          
                          fontSize: 11,
                          color: textSecondaryColor,
                        ),
                      ),
                      const Spacer(),
                      // Chapters Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: chapterCount > 0
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : textSecondaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bookmarks_rounded,
                              size: 10,
                              color: chapterCount > 0
                                  ? const Color(0xFF10B981)
                                  : textSecondaryColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$chapterCount',
                              style: TextStyle(
                                
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: chapterCount > 0
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

  // ═══════════════════════════════════════════════════════════════════════════
  // EMPTY SELECTION STATE
  // ═══════════════════════════════════════════════════════════════════════════
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
            child: const Icon(
              Icons.bookmarks_outlined,
              size: 64,
              color: AppColors.brand,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIVE WORKSPACE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildChaptersWorkspace(
    Color surfaceColor,
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
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
                                  color: const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Text(
                                  'Unsaved',
                                  style: TextStyle(
                                    
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                        Text(
                          'Manage content chapters & segment timestamps',
                          style: TextStyle(
                            
                            fontSize: 12,
                            color: textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions row
                  if (!isMobile) ...[
                    IconButton(
                      icon: const Icon(
                        Icons.download_rounded,
                        color: AppColors.info,
                      ),
                      tooltip: 'Import from YouTube description',
                      onPressed: () => _showImportDialog(context),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.upload_rounded,
                        color: AppColors.success,
                      ),
                      tooltip: 'Export YouTube timestamps',
                      onPressed: () => controller.exportToClipboard(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.psychology, color: AppColors.brand),
                      tooltip: 'AI Auto-Detect Chapters',
                      onPressed: () => controller.autoDetectChapters(),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Save Button
                  Obx(() {
                    return ElevatedButton.icon(
                      onPressed: controller.isSaving.value
                          ? null
                          : () => controller.saveChapters(),
                      icon: controller.isSaving.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.textPrimary,
                                ),
                              ),
                            )
                          : const Icon(Icons.save_rounded, size: 18),
                      label: Text(
                        controller.isSaving.value
                            ? 'Saving...'
                            : 'Save Changes',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: AppColors.textPrimary,
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
                      onPressed: () => _showImportDialog(context),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Import'),
                    ),
                    const VerticalDivider(),
                    TextButton.icon(
                      onPressed: () => controller.exportToClipboard(),
                      icon: const Icon(Icons.upload_rounded, size: 16),
                      label: const Text('Export'),
                    ),
                    const VerticalDivider(),
                    TextButton.icon(
                      onPressed: () => controller.autoDetectChapters(),
                      icon: const Icon(Icons.psychology, size: 16),
                      label: const Text('AI Auto'),
                    ),
                  ],
                ),
              ),

            // Chapters List & Timeline Editor
            Expanded(
              child: Obx(() {
                if (controller.currentChapters.isEmpty) {
                  return _buildEmptyTimelineState(
                    textColor,
                    textSecondaryColor,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: controller.currentChapters.length + 1,
                  itemBuilder: (context, index) {
                    if (index == controller.currentChapters.length) {
                      // Add new chapter dotted button at the end
                      return _buildAddChapterButton(
                        textColor,
                        textSecondaryColor,
                        borderColor,
                      );
                    }

                    final chapter = controller.currentChapters[index];
                    return _buildTimelineRow(
                      index: index,
                      chapter: chapter,
                      total: controller.currentChapters.length,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                      borderColor: borderColor,
                      surfaceColor: surfaceColor,
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
                color: widget.isDarkMode ? AppColors.bgSurface : AppColors.textPrimary,
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

  Widget _buildEmptyTimelineState(Color textColor, Color textSecondaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.toc_rounded,
            size: 64,
            color: textSecondaryColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Timeline is Empty',
            style: TextStyle(
              
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create manual chapters or import YouTube description timestamps.',
            style: TextStyle(
              
              fontSize: 13,
              color: textSecondaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showEditChapterDialog(context, index: -1),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Intro at 00:00'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => controller.autoDetectChapters(),
                icon: const Icon(Icons.psychology),
                label: const Text('AI Auto-Detect'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow({
    required int index,
    required VideoChapter chapter,
    required int total,
    required Color textColor,
    required Color textSecondaryColor,
    required Color borderColor,
    required Color surfaceColor,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vertical Timeline Line & Circle Indicator
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.textPrimary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brand.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.textPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              if (index < total)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.brand.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),

          // Chapter content card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Card(
                color: surfaceColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor),
                ),
                child: InkWell(
                  onTap: () => _showEditChapterDialog(
                    context,
                    index: index,
                    chapter: chapter,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Timestamp block
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            chapter.formattedStartTime,
                            style: const TextStyle(
                              
                              color: AppColors.brand,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Title block
                        Expanded(
                          child: Text(
                            chapter.title,
                            style: TextStyle(
                              
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: textColor,
                            ),
                          ),
                        ),

                        // Quick action shift buttons
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            size: 18,
                          ),
                          tooltip: 'Shift back 5s',
                          onPressed: () =>
                              controller.shiftChapterTiming(index, -5000),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                          ),
                          tooltip: 'Shift forward 5s',
                          onPressed: () =>
                              controller.shiftChapterTiming(index, 5000),
                        ),
                        const VerticalDivider(),

                        // Delete button
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                          ),
                          onPressed: () {
                            Get.dialog(
                              AlertDialog(
                                backgroundColor: surfaceColor,
                                title: const Text('Delete Chapter'),
                                content: Text(
                                  'Are you sure you want to delete "${chapter.title}"?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: Get.back,
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      controller.deleteChapter(index);
                                      Get.back();
                                    },
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: AppColors.error),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddChapterButton(
    Color textColor,
    Color textSecondaryColor,
    Color borderColor,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline connector dot
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          Expanded(
            child: InkWell(
              onTap: () => _showEditChapterDialog(context, index: -1),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: borderColor,
                    style: BorderStyle.none,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Card(
                  elevation: 0,
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: borderColor.withValues(alpha: 0.8),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: AppColors.brand),
                        SizedBox(width: 8),
                        Text(
                          'Add New Milestone Chapter',
                          style: TextStyle(
                            
                            color: AppColors.brand,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // POPUPS / DIALOGS
  // ═══════════════════════════════════════════════════════════════════════════
  void _showImportDialog(BuildContext context) {
    final textController = TextEditingController();
    final surfaceColor = widget.isDarkMode ? AppColors.bgSurface : AppColors.textPrimary;
    final textColor = widget.isDarkMode
        ? AppColors.textPrimary
        : AppColors.textPrimary;
    final textSecondaryColor = widget.isDarkMode
        ? AppColors.textSecondary
        : AppColors.textSecondary;

    Get.dialog(
      AlertDialog(
        backgroundColor: surfaceColor,
        title: Row(
          children: [
            const Icon(Icons.download_rounded, color: AppColors.brand),
            const SizedBox(width: 12),
            Text(
              'Import YouTube Timestamps',
              style: TextStyle(
                
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste video chapters/timestamps directly. Any matching timestamps will be imported and merged.',
                style: TextStyle(
                  
                  fontSize: 13,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? const Color(0xFF141414)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isDarkMode ? AppColors.bgDivider : Colors.black12,
                  ),
                ),
                child: TextField(
                  controller: textController,
                  maxLines: 8,
                  style: TextStyle(
                    
                    fontSize: 14,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        '00:00 Introduction\n01:30 Foundational Rules\n04:15 Core Topic Details',
                    hintStyle: TextStyle(
                      
                      fontSize: 13,
                      color: textSecondaryColor.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              controller.importFromYouTubeFormat(textController.text);
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Import & Parse'),
          ),
        ],
      ),
    );
  }

  void _showEditChapterDialog(
    BuildContext context, {
    required int index,
    VideoChapter? chapter,
  }) {
    final titleController = TextEditingController(text: chapter?.title ?? '');

    // Convert duration to formatted HH:MM:SS or MM:SS
    var timeText = '';
    if (chapter != null) {
      timeText = chapter.formattedStartTime;
    } else {
      // Auto-compute time based on last chapter
      if (controller.currentChapters.isNotEmpty) {
        final last = controller.currentChapters.last.startTime;
        final next = last + const Duration(minutes: 1);

        String twoDigits(int n) => n.toString().padLeft(2, '0');
        final minutes = twoDigits(next.inMinutes.remainder(60));
        final seconds = twoDigits(next.inSeconds.remainder(60));
        if (next.inHours > 0) {
          timeText = '${twoDigits(next.inHours)}:$minutes:$seconds';
        } else {
          timeText = '$minutes:$seconds';
        }
      } else {
        timeText = '00:00';
      }
    }

    final timeController = TextEditingController(text: timeText);

    final surfaceColor = widget.isDarkMode ? AppColors.bgSurface : AppColors.textPrimary;
    final textColor = widget.isDarkMode
        ? AppColors.textPrimary
        : AppColors.textPrimary;
    final textSecondaryColor = widget.isDarkMode
        ? AppColors.textSecondary
        : AppColors.textSecondary;

    Get.dialog(
      AlertDialog(
        backgroundColor: surfaceColor,
        title: Row(
          children: [
            Icon(
              index == -1
                  ? Icons.add_circle_outline_rounded
                  : Icons.edit_note_rounded,
              color: AppColors.brand,
            ),
            const SizedBox(width: 12),
            Text(
              index == -1
                  ? 'Create Milestone Chapter'
                  : 'Edit Milestone Chapter',
              style: TextStyle(
                
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Provide the timestamp and content description for this milestone.',
                style: TextStyle(
                  
                  fontSize: 13,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(height: 16),

              // Timestamp Field
              Text(
                'Start Timestamp (MM:SS or HH:MM:SS)',
                style: TextStyle(
                  
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: timeController,
                style: TextStyle(
                  
                  fontSize: 14,
                  color: textColor,
                ),
                decoration: const InputDecoration(
                  hintText: 'e.g. 02:45',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Field
              Text(
                'Chapter Title',
                style: TextStyle(
                  
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: titleController,
                style: TextStyle(
                  
                  fontSize: 14,
                  color: textColor,
                ),
                decoration: const InputDecoration(
                  hintText: 'e.g. Introducing the core architecture',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              final timeVal = timeController.text.trim();

              if (title.isEmpty) {
                controller.showError('Chapter title cannot be empty.');
                return;
              }

              // Parse time string
              final parts = timeVal.split(':');
              Duration? duration;
              try {
                if (parts.length == 3) {
                  duration = Duration(
                    hours: int.parse(parts[0]),
                    minutes: int.parse(parts[1]),
                    seconds: int.parse(parts[2]),
                  );
                } else if (parts.length == 2) {
                  duration = Duration(
                    minutes: int.parse(parts[0]),
                    seconds: int.parse(parts[1]),
                  );
                } else if (parts.length == 1) {
                  duration = Duration(seconds: int.parse(parts[0]));
                }
              } catch (_) {}

              if (duration == null) {
                controller.showError(
                  'Invalid timestamp format. Use MM:SS or HH:MM:SS.',
                );
                return;
              }

              if (index == -1) {
                controller.addChapter(title, duration);
              } else {
                controller.updateChapter(
                  index,
                  title: title,
                  startTime: duration,
                );
              }

              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: AppColors.textPrimary,
            ),
            child: Text(index == -1 ? 'Create' : 'Apply Changes'),
          ),
        ],
      ),
    );
  }
}
