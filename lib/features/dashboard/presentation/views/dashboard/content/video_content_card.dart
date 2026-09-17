import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/utils/watch_time_formatter.dart';
import 'package:truthworld/features/analytics/presentation/pages/watch_time_page.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/chapters_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/chapters_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content/content_ai_features_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content/content_dialogs.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/dashboard_screen.dart' show DashboardController;
import 'package:truthworld/features/dashboard/presentation/views/dashboard/edit_videoscreen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_content_details_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class VideoContentCard extends StatelessWidget {
  const VideoContentCard({
    required this.video,
    required this.controller,
    required this.isDarkMode,
    super.key,
  });

  final Video video;
  final VideoManagementController controller;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showVideoActionOptionsModal(context, video, isDarkMode: isDarkMode, controller: controller),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail container with 16:9 ratio (Compact 96x54)
              // Thumbnail container with 16:9 ratio (Compact 96x54)
              InkWell(
                onTap: () => showVideoActionOptionsModal(context, video, isDarkMode: isDarkMode, controller: controller),
                child: Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.bgInput,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: video.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const Icon(
                            Icons.movie_outlined,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (video.status == VideoStatus.rejected || video.visibility == 'rejected')
                      Container(
                        width: 96,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.block_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
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
                      style: AppTextStyles.videoTitleMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (video.status == VideoStatus.rejected || video.visibility == 'rejected') ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.block_rounded, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'REJECTED by Moderation',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Metadata wrap row with visibility badge and flexible text
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        VisibilityBadge(video: video, controller: controller),
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
                            Flexible(
                              child: Text(
                                DateFormat(
                                  'MMM d, yyyy',
                                ).format(video.uploadedAt.toDate()),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action Menu
              PopupMenuButton<String>(
                color: AppColors.bgSurface,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.bgDivider),
                ),
                onSelected: (value) {
                  if (value == 'watch') {
                    MiniplayerNavigationHelper.navigateToVideoScreen(
                      video: video,
                    );
                  } else if (value == 'analytics') {
                    Get.to<dynamic>(
                      () => const WatchTimePage(),
                      arguments: {
                        'channelId': video.channelId,
                        'videoId': video.id,
                        'videoTitle': video.title,
                      },
                    );
                  } else if (value == 'content_details') {
                    Get.to<dynamic>(
                      () => VideoContentDetailsScreen(
                        video: video,
                        isDarkMode: isDarkMode,
                      ),
                    );
                  } else if (value == 'chapters') {
                    final chaptersCtrl = Get.isRegistered<ChaptersController>()
                        ? Get.find<ChaptersController>()
                        : Get.put(ChaptersController());
                    chaptersCtrl.setChannelContext(video.channelId);
                    chaptersCtrl.selectVideo(video);
                    if (Get.isRegistered<DashboardController>()) {
                      Get.find<DashboardController>().setSelectedIndex(11);
                    } else {
                      Get.to<dynamic>(
                        () => ChaptersPage(
                          channelId: video.channelId,
                          isDarkMode: isDarkMode,
                        ),
                      );
                    }
                  } else if (value == 'visibility') {
                    showChangeVisibilityDialog(context, video, controller);
                  } else if (value == 'edit') {
                    Get.to<dynamic>(() => EditVideoScreen(video: video));
                  } else if (value == 'reactions_settings') {
                    showVideoReactionsSettingsDialog(context, video, controller);
                  } else if (value == 'ai_features') {
                    showGenerateAIFeaturesDialog(context, video, controller);
                  } else if (value == 'delete') {
                    showDeleteVideoDialog(context, video, controller);
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'watch',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.play_circle_outline_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Watch Video',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'analytics',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.analytics_outlined,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Watch Time & Analytics',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'content_details',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Video Content Details',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'chapters',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.view_timeline_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Chapters',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'visibility',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_open_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Visibility / Access',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text('Edit Video', style: AppTextStyles.bodyMedium),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'reactions_settings',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.thumbs_up_down_outlined,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Like / Dislike Counts',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'ai_features',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Generate AI Features',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Delete',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}

class VisibilityBadge extends StatelessWidget {
  const VisibilityBadge({
    required this.video,
    required this.controller,
    super.key,
  });

  final Video video;
  final VideoManagementController controller;

  @override
  Widget build(BuildContext context) {
    final info = _getVisibilityBadgeInfo(video.visibility);
    final label = info.$1;
    final icon = info.$2;
    final color = info.$3;
    final bg = info.$4;

    return InkWell(
      onTap: () => showChangeVisibilityDialog(context, video, controller),
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
            Icon(icon, size: 10, color: Colors.white),
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
          const Color(0xFF10B981),
          const Color(0xFF10B981).withValues(alpha: 0.15),
        );
      case 'private':
        return (
          'PRIVATE',
          Icons.lock_outline_rounded,
          const Color(0xFFEF4444),
          const Color(0xFFEF4444).withValues(alpha: 0.15),
        );
      case 'members':
      case 'members_only':
        return (
          'MEMBERS ONLY',
          Icons.card_membership_rounded,
          const Color(0xFF8B5CF6),
          const Color(0xFF8B5CF6).withValues(alpha: 0.15),
        );
      case 'subscribers':
      case 'subscribers_only':
        return (
          'SUBSCRIBERS ONLY',
          Icons.subscriptions_rounded,
          const Color(0xFF3B82F6),
          const Color(0xFF3B82F6).withValues(alpha: 0.15),
        );
      case 'unlisted':
        return (
          'UNLISTED',
          Icons.link_rounded,
          const Color(0xFF94A3B8),
          const Color(0xFF94A3B8).withValues(alpha: 0.15),
        );
      default:
        return (
          visibility.toUpperCase(),
          Icons.visibility_rounded,
          const Color(0xFF10B981),
          const Color(0xFF10B981).withValues(alpha: 0.15),
        );
    }
  }


}
