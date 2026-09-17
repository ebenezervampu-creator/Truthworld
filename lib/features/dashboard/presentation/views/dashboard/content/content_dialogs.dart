import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_content_details_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

  void showVideoActionOptionsModal(BuildContext context, Video video, {required bool isDarkMode, required VideoManagementController controller}) {
    Get.bottomSheet<void>(
      Material(
        color: AppColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.bgDivider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 56,
                      height: 32,
                      child: CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, err) => const ColoredBox(
                          color: AppColors.bgInput,
                          child: Icon(
                            Icons.movie_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
                title: Text(
                  'Watch Video',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Navigate to player and watch this video',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: () {
                  Get.back<void>();
                  MiniplayerNavigationHelper.navigateToVideoScreen(video: video);
                },
              ),
              const Divider(height: 16, color: AppColors.bgDivider),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_open_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                title: Text(
                  'Change Visibility / Access',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Convert to Public, Private, Members Only, Subscribers Only, or Unlisted',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: () {
                  Get.back<void>();
                  showChangeVisibilityDialog(context, video, controller);
                },
              ),
              const Divider(height: 16, color: AppColors.bgDivider),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                title: Text(
                  'Video Content Details',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Moderation, Thumbnail Safety, AI Metadata & Pipeline Stages',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: () {
                  Get
                    ..back<void>()
                    ..to<dynamic>(
                      () => VideoContentDetailsScreen(
                        video: video,
                        isDarkMode: isDarkMode,
                      ),
                    );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
  }


  void showVideoReactionsSettingsDialog(
    BuildContext context,
    Video video,
    VideoManagementController controller,
  ) {
    final showLikeCount = video.showLikeCount.obs;
    final showDislikeCount = video.showDislikeCount.obs;

    Get.dialog<void>(
      Dialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.thumbs_up_down_outlined,
                      color: AppColors.textPrimary,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Like & Dislike Counts',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(
                    'Show Like Count',
                    style: AppTextStyles.bodyMedium,
                  ),
                  subtitle: Text(
                    'Display how many viewers liked this video',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  value: showLikeCount.value,
                  onChanged: (v) => showLikeCount.value = v,
                  activeTrackColor: AppColors.brand,
                  tileColor: AppColors.bgSurface,
                ),
                SwitchListTile(
                  title: Text(
                    'Show Dislike Count',
                    style: AppTextStyles.bodyMedium,
                  ),
                  subtitle: Text(
                    'Display how many viewers disliked this video',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  value: showDislikeCount.value,
                  onChanged: (v) => showDislikeCount.value = v,
                  activeTrackColor: AppColors.brand,
                  tileColor: AppColors.bgSurface,
                ),
                const SizedBox(height: 20),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        controller.updateVideo(video.id, {
                          'showLikeCount': showLikeCount.value,
                          'showDislikeCount': showDislikeCount.value,
                        });
                        Get.back<void>();
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void showChangeVisibilityDialog(
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
        color: const Color(0xFF10B981),
      ),
      (
        value: 'private',
        title: 'Private',
        subtitle: 'Only you can view this video in your channel studio',
        icon: Icons.lock_outline_rounded,
        color: const Color(0xFFEF4444),
      ),
      (
        value: 'members_only',
        title: 'Members Only',
        subtitle: 'Exclusive access for paid channel members with an active tier',
        icon: Icons.card_membership_rounded,
        color: const Color(0xFF8B5CF6),
      ),
      (
        value: 'subscribers_only',
        title: 'Subscribers Only',
        subtitle: 'Exclusive access for users subscribed to your channel',
        icon: Icons.subscriptions_rounded,
        color: const Color(0xFF3B82F6),
      ),
      (
        value: 'unlisted',
        title: 'Unlisted',
        subtitle: 'Anyone with the video link can watch (hidden from search & feed)',
        icon: Icons.link_rounded,
        color: const Color(0xFF94A3B8),
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
                      color: AppColors.brand.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.lock_open_rounded,
                      color: Colors.white,
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
                                color: color.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                size: 18,
                                color: Colors.white,
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
                      foregroundColor: AppColors.textPrimary,
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
                    child: const Text('Save Visibility'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  void showDeleteVideoDialog(
    BuildContext context,
    Video video,
    VideoManagementController controller,
  ) {
    Get.dialog<void>(
      Dialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete Video?',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Are you sure you want to delete '${video.title}'? This action cannot be undone.",
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
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
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      controller.deleteVideo(video);
                      Get.back<void>();
                    },
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
