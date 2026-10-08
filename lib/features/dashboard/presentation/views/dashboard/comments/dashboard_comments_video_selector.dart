import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Desktop & Tablet Video Selector Sidebar Pane
/// Allows filtering comments by a specific video or all videos.
class DashboardCommentsVideoSelectorPane extends StatelessWidget {
  const DashboardCommentsVideoSelectorPane({
    required this.controller,
    super.key,
  });

  final DashboardCommentsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingVideos.value) {
        return Shimmer.fromColors(
          baseColor: const Color(0xFF1E1E1E),
          highlightColor: AppColors.bgSurfaceHover,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: 6,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, _) => Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final videos = controller.videosWithComments;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.video_collection_rounded,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Your Videos',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${videos.length}',
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.bgDivider),

          // "All Videos" Option
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => controller.selectVideo(null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: controller.selectedVideoId.value == null
                      ? AppColors.bgSurfaceHover
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.video_library_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All Videos',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontFamilyFallback: TWTypography.fallbackFamilies,
                              fontSize: 13,
                              fontWeight: controller.selectedVideoId.value == null
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${controller.allComments.length} comments',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontFamilyFallback: TWTypography.fallbackFamilies,
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.bgDivider),

          // Video list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: videos.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: AppColors.bgDivider),
              itemBuilder: (context, index) {
                final video = videos[index];
                final isSelected =
                    controller.selectedVideoId.value == video.videoId;

                return InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => controller.selectVideo(video.videoId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.bgSurfaceHover
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: video.thumbnail.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: video.thumbnail,
                                  width: 44,
                                  height: 32,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, err) => Container(
                                    width: 44,
                                    height: 32,
                                    color: AppColors.bgSurface,
                                    child: const Icon(
                                      Icons.play_arrow,
                                      size: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 44,
                                  height: 32,
                                  color: AppColors.bgSurface,
                                  child: const Icon(
                                    Icons.ondemand_video_rounded,
                                    size: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                video.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  fontFamilyFallback: TWTypography.fallbackFamilies,
                                  fontSize: 12.5,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${video.formattedCommentCount} • ${video.formattedViewCount} views',
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  fontFamilyFallback: TWTypography.fallbackFamilies,
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

/// Mobile Dropdown Chip for selecting video filter
class DashboardMobileVideoDropdownChip extends StatelessWidget {
  const DashboardMobileVideoDropdownChip({
    required this.controller,
    super.key,
  });

  final DashboardCommentsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selectedId = controller.selectedVideoId.value;
      final videos = controller.videosWithComments;
      final selectedVideo = videos.firstWhereOrNull(
        (v) => v.videoId == selectedId,
      );

      final labelText = selectedId == null
          ? 'All Videos (${controller.allComments.length})'
          : '${selectedVideo?.title ?? "Video"} (${selectedVideo?.commentCount ?? 0})';

      return PopupMenuButton<String?>(
        tooltip: 'Filter by video',
        color: const Color(0xFF1E1E1E),
        onSelected: controller.selectVideo,
        itemBuilder: (context) => [
          PopupMenuItem<String?>(
            child: Row(
              children: [
                const Icon(
                  Icons.video_library_rounded,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All Videos (${controller.allComments.length})',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontSize: 13,
                      fontWeight: selectedId == null
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
          ...videos.map((video) {
            return PopupMenuItem<String?>(
              value: video.videoId,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: video.thumbnail.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: video.thumbnail,
                            width: 24,
                            height: 18,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, err) => const Icon(
                              Icons.play_circle_outline,
                              size: 14,
                              color: AppColors.textPrimary,
                            ),
                          )
                        : const Icon(
                            Icons.ondemand_video_rounded,
                            size: 16,
                            color: AppColors.textPrimary,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${video.title} (${video.commentCount})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        fontSize: 12,
                        fontWeight: selectedId == video.videoId
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selectedId != null
                ? AppColors.bgSurfaceHover
                : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selectedId != null ? AppColors.textPrimary : AppColors.bgDivider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.video_collection_rounded,
                size: 14,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  labelText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down_rounded,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ],
          ),
        ),
      );
    });
  }
}
