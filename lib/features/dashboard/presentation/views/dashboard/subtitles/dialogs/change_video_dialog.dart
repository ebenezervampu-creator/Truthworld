import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class ChangeVideoDialog extends StatelessWidget {
  const ChangeVideoDialog({
    required this.controller,
    required this.isDarkMode,
    super.key,
  });

  final SubtitlesController controller;
  final bool isDarkMode;

  static Future<void> show(
    BuildContext context, {
    required SubtitlesController controller,
    required bool isDarkMode,
  }) async {
    final isMobile = MediaQuery.of(context).size.width < 700;
    if (isMobile) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.85,
          child: ChangeVideoDialog(
            controller: controller,
            isDarkMode: isDarkMode,
          ),
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
            child: ChangeVideoDialog(
              controller: controller,
              isDarkMode: isDarkMode,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryText = AppColors.textPrimary;
    const secondaryText = AppColors.textSecondary;
    const cardColor = AppColors.bgSurface;
    const borderColor = AppColors.bgDivider;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.video_library_rounded,
                  color: primaryText,
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Select Video for Subtitles',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: secondaryText),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: borderColor),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                maxLength: 100,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: TruthworldTextInputFormatters.withLimit(100),
                style: const TextStyle(
                  fontSize: 14,
                  color: primaryText,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search channel videos...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: secondaryText,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: secondaryText,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onChanged: controller.setSearchQuery,
              ),
            ),
          ),

          // Videos List
          Expanded(
            child: Obx(() {
              final list = controller.filteredVideos;
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: secondaryText,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No videos found',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Try a different title or search keyword.',
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final selectedId = controller.selectedVideo.value?.id;

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                itemCount: list.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final video = list[index];
                  final isSelected = video.id == selectedId;

                  final dateStr = DateFormat('MMM d, yyyy').format(video.createdAt.toDate());
                  final tracksCount = video.mediaSubtitles.length;

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      controller.selectVideo(video);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF282828) : cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.textLink
                              : borderColor.withValues(alpha: 0.6),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Thumbnail
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: video.thumbnailUrl,
                                  width: 104,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 104,
                                    height: 60,
                                    color: AppColors.bgSurfaceHover,
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    width: 104,
                                    height: 60,
                                    color: AppColors.bgSurfaceHover,
                                    child: const Icon(
                                      Icons.videocam_off_rounded,
                                      size: 20,
                                      color: secondaryText,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgPage.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    video.duration.isNotEmpty ? video.duration : '00:00',
                                    style: const TextStyle(
                                      color: primaryText,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  video.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: primaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Published • $dateStr • ${video.views} ${video.views == 1 ? 'view' : 'views'}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$tracksCount subtitle track${tracksCount == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLink,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.textLink,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.black,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
