import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/utils/watch_time_formatter.dart';
import 'package:truthworld/features/analytics/presentation/pages/watch_time_page.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/chapters_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/chapters_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/edit_videoscreen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/video_pipeline_status.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class VideoContentDetailsScreen extends StatelessWidget {
  const VideoContentDetailsScreen({
    required this.video,
    required this.isDarkMode,
    super.key,
  });

  final Video video;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<VideoManagementController>()
        ? Get.find<VideoManagementController>()
        : Get.put(VideoManagementController());

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: AppColors.bgDivider),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Get.back<void>(),
        ),
        title: Text(
          'Video Content Details',
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: TWTypography.brandFamily,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Change Visibility',
            icon: const Icon(Icons.lock_open_rounded, color: AppColors.textPrimary),
            onPressed: () => _showChangeVisibilityDialog(context, video, controller),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Thumbnail with Hero flight
                  Hero(
                    tag: 'video-thumb-${video.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 120,
                        height: 68,
                        child: video.thumbnailUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: video.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    const ColoredBox(
                                      color: AppColors.bgInput,
                                      child: Icon(
                                        Icons.movie_outlined,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                              )
                            : const ColoredBox(
                                color: AppColors.bgInput,
                                child: Icon(
                                  Icons.movie_outlined,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Title & Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.videoTitleMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildVisibilityBadge(context, video, controller),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.visibility_outlined,
                                  size: 13,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${video.views} views',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  size: 13,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  WatchTimeFormatter.format(video.totalWatchTimeSeconds),
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 13,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat(
                                    'MMM d, yyyy',
                                  ).format(video.uploadedAt.toDate()),
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Row: Watch Video, Analytics, Chapters & Edit Video
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.black),
                  label: Text(
                    'Watch',
                    style: AppTextStyles.buttonText.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  onPressed: () {
                    MiniplayerNavigationHelper.navigateToVideoScreen(
                      video: video,
                    );
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.bgSurfaceHover,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.bgDivider),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.analytics_outlined, size: 18, color: AppColors.textPrimary),
                  label: Text(
                    'Analytics',
                    style: AppTextStyles.buttonText.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () {
                    Get.to<dynamic>(
                      () => const WatchTimePage(),
                      arguments: {
                        'channelId': video.channelId,
                        'videoId': video.id,
                        'videoTitle': video.title,
                      },
                    );
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.bgSurfaceHover,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.bgDivider),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.view_timeline_rounded, size: 18, color: AppColors.textPrimary),
                  label: Text(
                    'Chapters',
                    style: AppTextStyles.buttonText.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () {
                    final chaptersCtrl = Get.isRegistered<ChaptersController>()
                        ? Get.find<ChaptersController>()
                        : Get.put(ChaptersController());
                    chaptersCtrl.setChannelContext(video.channelId);
                    chaptersCtrl.selectVideo(video);
                    Get.to<dynamic>(
                      () => ChaptersPage(
                        channelId: video.channelId,
                        isDarkMode: isDarkMode,
                      ),
                    );
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.bgSurfaceHover,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.bgDivider),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                  label: Text(
                    'Edit',
                    style: AppTextStyles.buttonText.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onPressed: () {
                    Get.to<dynamic>(() => EditVideoScreen(video: video));
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section Header
            Text(
              'Content Pipeline & Safety Intelligence',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontFamily: TWTypography.brandFamily,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Includes Video Content Moderation, Thumbnail Safety, AI Metadata, & Transcoding Pipeline Stages',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),

            // Detailed Pipeline Status Widget
            VideoPipelineStatusWidget(
              video: video,
              isDarkMode: isDarkMode,
              initiallyExpanded: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityBadge(
    BuildContext context,
    Video video,
    VideoManagementController controller,
  ) {
    final info = _getVisibilityBadgeInfo(video.visibility);
    final label = info.$1;
    final icon = info.$2;
    final color = info.$3;
    final bg = info.$4;

    return InkWell(
      onTap: () => _showChangeVisibilityDialog(context, video, controller),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 9.5,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down_rounded, size: 12, color: color),
          ],
        ),
      ),
    );
  }

  (String, IconData, Color, Color) _getVisibilityBadgeInfo(String visibility) {
    switch (visibility.toLowerCase()) {
      case 'public':
        return (
          'PUBLIC',
          Icons.public_rounded,
          AppColors.success,
          AppColors.successContainer,
        );
      case 'private':
        return (
          'PRIVATE',
          Icons.lock_outline_rounded,
          AppColors.error,
          AppColors.errorContainer,
        );
      case 'members':
      case 'members_only':
        return (
          'MEMBERS ONLY',
          Icons.card_membership_rounded,
          AppColors.info,
          AppColors.infoContainer,
        );
      case 'subscribers':
      case 'subscribers_only':
        return (
          'SUBSCRIBERS ONLY',
          Icons.subscriptions_rounded,
          AppColors.info,
          AppColors.infoContainer,
        );
      case 'unlisted':
        return (
          'UNLISTED',
          Icons.link_rounded,
          AppColors.textSecondary,
          AppColors.bgSurfaceHover,
        );
      default:
        return (
          visibility.toUpperCase(),
          Icons.visibility_rounded,
          AppColors.success,
          AppColors.successContainer,
        );
    }
  }

  void _showChangeVisibilityDialog(
    BuildContext context,
    Video video,
    VideoManagementController controller,
  ) {
    var initial = video.visibility.toLowerCase();
    if (initial == 'members') initial = 'members_only';
    if (initial == 'subscribers') initial = 'subscribers_only';
    final selected = initial.obs;

    final options = <({String value, String title, String subtitle, IconData icon, Color color})>[
      (
        value: 'public',
        title: 'Public',
        subtitle: 'Everyone can search for and watch this video on Truthworld',
        icon: Icons.public_rounded,
        color: AppColors.success,
      ),
      (
        value: 'private',
        title: 'Private',
        subtitle: 'Only you can view this video in your channel studio',
        icon: Icons.lock_outline_rounded,
        color: AppColors.error,
      ),
      (
        value: 'members_only',
        title: 'Members Only',
        subtitle: 'Exclusive access for paid channel members with an active tier',
        icon: Icons.card_membership_rounded,
        color: AppColors.info,
      ),
      (
        value: 'subscribers_only',
        title: 'Subscribers Only',
        subtitle: 'Exclusive access for users subscribed to your channel',
        icon: Icons.subscriptions_rounded,
        color: AppColors.info,
      ),
      (
        value: 'unlisted',
        title: 'Unlisted',
        subtitle: 'Anyone with the video link can watch (hidden from search & feed)',
        icon: Icons.link_rounded,
        color: AppColors.textSecondary,
      ),
    ];

    Get.dialog<void>(
      Dialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurfaceHover,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.lock_open_rounded,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change Visibility & Access',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontFamily: TWTypography.brandFamily,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.bgDivider, height: 1),
              const SizedBox(height: 12),
              ...options.map((opt) {
                final val = opt.value;
                final title = opt.title;
                final subtitle = opt.subtitle;
                final icon = opt.icon;
                final color = opt.color;

                return Obx(() {
                  final isSelected = selected.value == val;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        selected.value = val;
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.12)
                              : AppColors.bgInput.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? color
                                : AppColors.bgDivider.withValues(alpha: 0.5),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                size: 18,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Radio<String>(
                              value: val,
                              groupValue: selected.value,
                              onChanged: (v) {
                                if (v != null) selected.value = v;
                              },
                              activeColor: color,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                });
              }),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: Get.back<void>,
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.buttonText.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      controller.changeVideoVisibility(video.id, selected.value);
                      Get.back<void>();
                    },
                    child: const Text(
                      'Save Visibility',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
