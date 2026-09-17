import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/chapters_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Video list panel for browsing and selecting channel videos for chapter editing.
class ChaptersVideoListPane extends StatelessWidget {
  const ChaptersVideoListPane({
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
    return Column(
      children: [
        _buildSearchHeader(context),
        _buildFilterChips(),
        Expanded(
          child: Obx(() {
            return ListView.separated(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 12,
                vertical: 12,
              ),
              itemCount: controller.filteredVideos.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final video = controller.filteredVideos[index];
                final isSelected =
                    controller.selectedVideo.value?.id == video.id;
                return _buildVideoSelectorCard(
                  video: video,
                  isSelected: isSelected,
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (Navigator.canPop(context)) ...[
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(
                Icons.bookmarks_rounded,
                color: Colors.white,
                size: 22,
              ),
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
              color: isDarkMode
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
              decoration: const InputDecoration(
                hintText: 'Search videos...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onChanged: controller.setSearchQuery,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      width: double.infinity,
      color: surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Obx(() {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('all', 'All Videos'),
              const SizedBox(width: 8),
              _buildFilterChip('has_chapters', 'With Chapters'),
              const SizedBox(width: 8),
              _buildFilterChip('no_chapters', 'No Chapters'),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildFilterChip(String type, String label) {
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
        color: isSelected ? Colors.black : textColor,
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
                      color: isDarkMode
                          ? const Color(0xFF2A2A2A)
                          : AppColors.bgDivider,
                    ),
                    errorWidget: (context, url, error) => ColoredBox(
                      color: isDarkMode
                          ? const Color(0xFF2A2A2A)
                          : AppColors.bgDivider,
                      child: const Icon(
                        Icons.video_file_rounded,
                        size: 20,
                        color: Colors.white,
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
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.brand : textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        DateFormat('MMM d, yyyy')
                            .format(video.uploadedAt.toDate()),
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
}
