import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content/content_ai_features_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/edit_videoscreen.dart';
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
              if (video.isRejected) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: video.resubmitCount < 2
                          ? AppColors.brand.withValues(alpha: 0.15)
                          : AppColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      video.resubmitCount < 2
                          ? Icons.refresh_rounded
                          : Icons.block_rounded,
                      color: video.resubmitCount < 2
                          ? AppColors.brand
                          : AppColors.error,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    video.resubmitCount < 2
                        ? 'Resubmit for Moderation'
                        : 'Resubmission Limit Reached (2/2)',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: video.resubmitCount < 2
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  subtitle: Text(
                    video.resubmitCount < 2
                        ? 'Resubmission attempt ${video.resubmitCount + 1} of 2 (${2 - video.resubmitCount} remaining)'
                        : 'Maximum of 2 resubmissions have been used for this video.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onTap: () {
                    Get.back<void>();
                    showResubmitModerationDialog(context, video, controller);
                  },
                ),
                const Divider(height: 16, color: AppColors.bgDivider),
              ],
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
                    color: AppColors.bgSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.record_voice_over_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                title: Text(
                  'Video Dubbing & Neural Lip-Sync',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Video Pro (\$4) & Video Ultra (\$5) with LatentSync 1080p & Voice Cloning',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: () {
                  Get.back<void>();
                  showGenerateAIFeaturesDialog(
                    context,
                    video,
                    controller,
                    initialFeatures: {'dubbing'},
                    initialDubbingTier: 'video_pro',
                  );
                },
              ),
              const Divider(height: 16, color: AppColors.bgDivider),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                title: Text(
                  'Audio Dubbing Studio',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Starter (\$1), Pro (\$2), & Ultra (\$3) with Chirp HD & ElevenLabs v4',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: () {
                  Get.back<void>();
                  showGenerateAIFeaturesDialog(
                    context,
                    video,
                    controller,
                    initialFeatures: {'dubbing'},
                    initialDubbingTier: 'audio_starter',
                  );
                },
              ),
              const Divider(height: 16, color: AppColors.bgDivider),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                title: Text(
                  'AI Features & Fact-Checking',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Auto-Chapters, summaries, fact-checks, captions & pipeline tools',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: () {
                  Get.back<void>();
                  showGenerateAIFeaturesDialog(
                    context,
                    video,
                    controller,
                  );
                },
              ),
              const Divider(height: 16, color: AppColors.bgDivider),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lock_open_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Change Visibility / Access',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: TWTypography.brandFamily,
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
                  decoration: const BoxDecoration(
                    color: AppColors.infoContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: AppColors.textPrimary,
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
              const Divider(height: 16, color: AppColors.bgDivider),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 22,
                  ),
                ),
                title: Text(
                  'Move to Trash',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                subtitle: Text(
                  'Retained in Trash for 30 days before permanent deletion',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: () {
                  Get.back<void>();
                  showDeleteVideoDialog(context, video, controller);
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

    final mediaQuery = MediaQuery.maybeOf(context);
    final isMobile = (mediaQuery?.size.width ?? 800) < 600;

    if (isMobile) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => ChangeVisibilityModalContent(
          video: video,
          controller: controller,
          selected: selected,
          isBottomSheet: true,
        ),
      );
    } else {
      Get.dialog<void>(
        Dialog(
          backgroundColor: AppColors.bgPage,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.bgSurface),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ChangeVisibilityModalContent(
              video: video,
              controller: controller,
              selected: selected,
              isBottomSheet: false,
            ),
          ),
        ),
      );
    }
  }

class ChangeVisibilityModalContent extends StatelessWidget {
  const ChangeVisibilityModalContent({
    required this.video,
    required this.controller,
    required this.selected,
    required this.isBottomSheet,
    super.key,
  });

  final Video video;
  final VideoManagementController controller;
  final RxString selected;
  final bool isBottomSheet;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final screenHeight = mediaQuery?.size.height ?? 800.0;
    final maxHeight = screenHeight * (isBottomSheet ? 0.88 : 0.85);

    const options = [
      (
        value: 'public',
        title: 'Public',
        subtitle: 'Everyone can search for and watch this video on Truthworld',
        icon: Icons.public_rounded,
      ),
      (
        value: 'private',
        title: 'Private',
        subtitle: 'Only you can view this video in your channel studio',
        icon: Icons.lock_outline_rounded,
      ),
      (
        value: 'members_only',
        title: 'Members Only',
        subtitle: 'Exclusive access for paid channel members with an active tier',
        icon: Icons.card_membership_rounded,
      ),
      (
        value: 'subscribers_only',
        title: 'Subscribers Only',
        subtitle: 'Exclusive access for users subscribed to your channel',
        icon: Icons.subscriptions_rounded,
      ),
      (
        value: 'unlisted',
        title: 'Unlisted',
        subtitle: 'Anyone with the video link can watch (hidden from search & feed)',
        icon: Icons.link_rounded,
      ),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
        maxWidth: 480,
      ),
      child: Material(
        color: AppColors.bgPage,
        borderRadius: isBottomSheet
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              isBottomSheet ? 12 : 20,
              20,
              20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isBottomSheet)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.bgElevated,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.lock_open_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Change Visibility & Access',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.3,
                              fontFamily: TWTypography.uiFamily,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            video.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontFamily: TWTypography.uiFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      tooltip: 'Close',
                      splashRadius: 18,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: AppColors.bgSurface, height: 1, thickness: 1),
                const SizedBox(height: 12),
                const Text(
                  'Choose who can discover and watch this video.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: TWTypography.uiFamily,
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: options.map((opt) {
                        return Obx(() {
                          final isSelected = selected.value == opt.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : AppColors.bgInput,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.bgSurface,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                selected.value = opt.value;
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.bgSurface,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        opt.icon,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            opt.title,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              color: Colors.white,
                                              fontFamily: TWTypography.uiFamily,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            opt.subtitle,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              fontFamily: TWTypography.uiFamily,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 20,
                                      )
                                    else
                                      const Icon(
                                        Icons.radio_button_unchecked,
                                        color: AppColors.textDisabled,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        });
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: AppColors.bgSurface, height: 1, thickness: 1),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: TWTypography.uiFamily,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        controller.changeVideoVisibility(video.id, selected.value);
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Save Visibility',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: TWTypography.uiFamily,
                        ),
                      ),
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
                'Move to Trash?',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontFamily: TWTypography.brandFamily,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Are you sure you want to move '${video.title}' to Trash? Deleted items are retained for 30 days before permanent deletion.",
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
                    child: const Text(
                      'Move to Trash',
                      style: TextStyle(
                        color: Colors.white,
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

  /// Displays modal dialog to resubmit a rejected video for automated moderation and verification.
  /// Enforces strict maximum 2-times limit policy with clear feedback.
  void showResubmitModerationDialog(
    BuildContext context,
    Video video,
    VideoManagementController controller, {
    VoidCallback? onResubmitted,
  }) {
    final currentCount = video.resubmitCount;
    final isMaxReached = currentCount >= 2;
    final nextAttempt = currentCount + 1;
    final remaining = (2 - currentCount).clamp(0, 2);

    Get.dialog<void>(
      Dialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isMaxReached
                            ? AppColors.error.withValues(alpha: 0.15)
                            : AppColors.brand.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isMaxReached ? Icons.block_rounded : Icons.refresh_rounded,
                        color: isMaxReached ? AppColors.error : AppColors.brand,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMaxReached
                                ? 'Resubmission Limit Reached'
                                : 'Resubmit for Moderation',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontFamily: TWTypography.brandFamily,
                            ),
                          ),
                          Text(
                            isMaxReached
                                ? '2 of 2 attempts used'
                                : 'Attempt $nextAttempt of 2 • $remaining remaining',
                            style: AppTextStyles.caption.copyWith(
                              color: isMaxReached ? AppColors.error : AppColors.brand,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Video snippet container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 56,
                          height: 32,
                          child: video.thumbnailUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: video.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => const ColoredBox(
                                    color: AppColors.bgSurface,
                                    child: Icon(Icons.movie_outlined, size: 16, color: Colors.white),
                                  ),
                                )
                              : const ColoredBox(
                                  color: AppColors.bgSurface,
                                  child: Icon(Icons.movie_outlined, size: 16, color: Colors.white),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (isMaxReached) ...[
                  Text(
                    'This video has already reached the maximum limit of 2 resubmissions and cannot be resubmitted again. If you believe this is in error, please contact TruthWorld support.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.bgDivider),
                      ),
                      onPressed: Get.back<void>,
                      child: const Text('Close'),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Before resubmitting, ensure your video title, description, and thumbnail comply with TruthWorld Community Guidelines. Each video can only be resubmitted twice.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You have $remaining resubmission attempt(s) remaining.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.bgDivider),
                        ),
                        onPressed: () {
                          Get.back<void>();
                          Get.to<dynamic>(() => EditVideoScreen(video: video));
                        },
                        child: const Text('Edit Details First'),
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
                        onPressed: () async {
                          Get.back<void>();
                          final success = await controller.resubmitVideoForModeration(video.id);
                          if (success && onResubmitted != null) {
                            onResubmitted();
                          }
                        },
                        child: Text(
                          'Resubmit (Attempt $nextAttempt/2)',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
