import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Videos Tab List View for Studio Comments
/// Displays all creator videos in a list. When any video is tapped,
/// it selects that video and switches to the Published comments tab to show all its comments.
class DashboardCommentsVideosListView extends StatelessWidget {
  const DashboardCommentsVideosListView({
    required this.controller,
    required this.isMobile,
    super.key,
  });

  final DashboardCommentsController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingVideos.value && controller.videosWithComments.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: StudioLoadingIndicator(
              message: 'Loading videos...',
              isFullScreen: false,
            ),
          ),
        );
      }

      final videos = controller.videosWithComments;
      if (videos.isEmpty) {
        return _buildEmptyState();
      }

      final selectedId = controller.selectedVideoId.value;
      final totalChannelComments = controller.allComments.length;

      return ListView.separated(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24,
          vertical: 12,
        ),
        itemCount: videos.length + 1, // +1 for "All Videos" option at top
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          thickness: 1,
          color: AppColors.bgDivider,
        ),
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All Videos" option tile
            final isAllSelected = selectedId == null;
            return _buildAllVideosTile(isAllSelected, totalChannelComments, videos.length);
          }

          final video = videos[index - 1];
          final isSelected = selectedId == video.videoId;

          return _buildVideoTile(video, isSelected);
        },
      );
    });
  }

  Widget _buildAllVideosTile(
    bool isSelected,
    int totalComments,
    int totalVideos,
  ) {
    return InkWell(
      onTap: () => controller.onVideoSelectedFromList(null),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bgSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.brand : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: const Icon(
                Icons.video_library_rounded,
                size: 22,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'All Videos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$totalComments comments across $totalVideos videos',
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
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoTile(CreatorVideoWithComments video, bool isSelected) {
    return InkWell(
      onTap: () => controller.onVideoSelectedFromList(video.videoId),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bgSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.brand : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Video Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  if (video.thumbnail.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: video.thumbnail,
                      width: 68,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, err) => Container(
                        width: 68,
                        height: 48,
                        color: AppColors.bgSurface,
                        child: const Icon(
                          Icons.play_arrow,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 68,
                      height: 48,
                      color: AppColors.bgSurface,
                      child: const Icon(
                        Icons.ondemand_video_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  if (video.duration.isNotEmpty && video.duration != '0:00')
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          video.duration,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Video Info
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
                            fontFamily: TWTypography.uiFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SELECTED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.bgDivider),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 11,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  video.formattedCommentCount,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    fontFamilyFallback: TWTypography.fallbackFamilies,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${video.formattedViewCount} views • ${timeago.format(video.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontFamilyFallback: TWTypography.fallbackFamilies,
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
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_collection_outlined,
              size: 48,
              color: AppColors.textPrimary,
            ),
            SizedBox(height: 12),
            Text(
              'No videos found',
              style: TextStyle(
                fontFamily: TWTypography.brandFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Videos uploaded to your channel will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
