import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/watch_time_formatter.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:truthworld/features/analytics/presentation/pages/watch_time_page.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/edit_videoscreen.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/myvideos/presentation/controllers/my_videos_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

// ==========================================================================
// YOUTUBE-STYLE THEME COLORS (Standardized)
// ==========================================================================

const Color bgColor = AppColors.bgPage;
const Color surfaceColor = AppColors.bgPage;
const Color cardColor = Color(0xFF1E1E1E);
const Color primaryText = AppColors.textPrimary;
const Color secondaryText = AppColors.textSecondary;
const Color buttonBg = AppColors.bgSurfaceHover;

class MyVideos extends GetView<MyVideosController> {
  const MyVideos({super.key, this.isDashboard = false});
  final bool isDashboard;

  MyVideosController get _controller => controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Obx(() {
          final userId = AuthService.to.currentUser.value?.uid;

          if (userId == null || userId.isEmpty) {
            return _buildNotLoggedInWidget(context);
          }

          return _buildMainContent(userId);
        }),
      ),
    );
  }

  Widget _buildMainContent(String userId) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, isDashboard ? 16 : 48, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Obx(
                    () => _controller.isSearchExpanded.value
                        ? Container(
                            height: 40,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.bgDivider.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: TextField(
                              onChanged: (value) =>
                                  _controller.searchQuery.value = value,
                              style: const TextStyle(
                                color: primaryText,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search your videos...',
                                hintStyle: const TextStyle(
                                  color: secondaryText,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: secondaryText,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: secondaryText,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _controller.isSearchExpanded.value = false;
                                    _controller.searchQuery.value = '';
                                  },
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: primaryText,
                                ),
                                onPressed: () {
                                  if (isDashboard) {
                                    Get.find<HomeController>()
                                            .sideNavSelectedIndex
                                            .value =
                                        HomeController.indexLibrary;
                                  } else {
                                    Get.back();
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'My videos',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: primaryText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                Obx(
                  () => !_controller.isSearchExpanded.value
                      ? IconButton(
                          icon: const Icon(
                            Icons.search,
                            color: primaryText,
                          ),
                          onPressed: () =>
                              _controller.isSearchExpanded.value = true,
                        )
                      : const SizedBox.shrink(),
                ),
                IconButton(
                  tooltip: 'Upload video',
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: primaryText,
                    size: 24,
                  ),
                  onPressed: _controller.handleUploadTap,
                ),
              ],
            ),
          ),
        ),
        Obx(() {
          if (_controller.rxIsLoading.value) {
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => const ShimmerVideoListCard(),
                childCount: 6,
              ),
            );
          }

          if (_controller.rxErrorMessage.value.isNotEmpty) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _controller.rxErrorMessage.value,
                        style: const TextStyle(
                          color: primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _controller.retryFetch,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Retry',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final videos = _controller.filteredAndSortedVideos;
          if (videos.isEmpty) {
            return const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No videos found',
                  style: TextStyle(color: primaryText),
                ),
              ),
            );
          }

          final categoriesSet = <String>{'All'};
          for (final v in videos) {
            if (v.category.isNotEmpty) {
              categoriesSet.add(v.category);
            }
          }
          final categories = categoriesSet.toList();

          var displayVideos = List<Video>.from(videos);
          if (_controller.selectedCategory.value != 'All') {
            displayVideos = displayVideos
                .where((v) => v.category == _controller.selectedCategory.value)
                .toList();
          }

          final groupedVideos = _controller.groupVideosByDate(displayVideos);

          return SliverMainAxisGroup(
            slivers: [
              if (categories.length > 1)
                SliverToBoxAdapter(child: _buildCategoryChips(categories)),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final dateKey = groupedVideos.keys.elementAt(index);
                  final dateVideos = groupedVideos[dateKey]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                        child: Text(
                          dateKey,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                      ),
                      ...dateVideos.map(
                        (video) => _MyVideoListCard(
                          video: video,
                          controller: _controller,
                        ),
                      ),
                    ],
                  );
                }, childCount: groupedVideos.length),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildCategoryChips(List<String> categories) {
    return Container(
      height: 48,
      padding: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Obx(() {
            final isSelected = _controller.selectedCategory.value == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) _controller.setCategory(category);
                },
                selectedColor: primaryText,
                backgroundColor: buttonBg,
                labelStyle: TextStyle(
                  color: isSelected ? bgColor : primaryText,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                showCheckmark: false,
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildNotLoggedInWidget(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.video_library_rounded,
                size: 80,
                color: primaryText,
              ),
              const SizedBox(height: 24),
              const Text(
                'Sign in to see your videos',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Get.toNamed('/auth'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryText,
                  foregroundColor: bgColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyVideoListCard extends StatelessWidget {
  const _MyVideoListCard({required this.video, required this.controller});
  final Video video;
  final MyVideosController controller;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        MiniplayerNavigationHelper.navigateToVideoScreen(video: video);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: 140,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: buttonBg),
                    errorWidget: (context, url, error) =>
                        Container(color: buttonBg),
                  ),
                ),
                // Duration overlay
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        color: primaryText,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Visibility icon overlay
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: bgColor.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      video.visibility == 'public'
                          ? Icons.public
                          : Icons.lock,
                      size: 12,
                      color: primaryText,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          color: primaryText,
                          size: 18,
                        ),
                        onPressed: () => _showOptions(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${video.views} views • ${WatchTimeFormatter.format(video.totalWatchTimeSeconds)} • ${controller.formatTimeAgo(video.uploadedAt.toDate())}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: secondaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        video.visibility.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: secondaryText,
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

  void _showOptions(BuildContext context) {
    Get.bottomSheet(
      Material(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: secondaryText.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                video.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 16),
              _buildOptionItem(
                icon: Icons.analytics_outlined,
                label: 'Watch Time & Analytics',
                onTap: () {
                  Get.back();
                  Get.to<dynamic>(
                    () => const WatchTimePage(),
                    arguments: {
                      'channelId': video.channelId,
                      'videoId': video.id,
                    },
                  );
                },
              ),
              _buildOptionItem(
                icon: Icons.edit_outlined,
                label: 'Edit details',
                onTap: () {
                  Get.back();
                  Get.to<dynamic>(
                    () => EditVideoScreen(
                      video: video,
                    ),
                  );
                },
              ),
              _buildOptionItem(
                icon: Icons.visibility_outlined,
                label: 'Change visibility',
                onTap: () {
                  Get.back();
                  _showChangeVisibilityDialog(context);
                },
              ),
              _buildOptionItem(
                icon: Icons.share_rounded,
                label: 'Share video',
                onTap: () {
                  Get.back();
                  VideoOptionsSheet.show(context, video);
                },
              ),
              const Divider(height: 24, color: AppColors.bgDivider),
              _buildOptionItem(
                icon: Icons.delete_outline_rounded,
                label: 'Delete video',
                color: AppColors.error,
                onTap: () {
                  Get.back();
                  _showDeleteConfirmation(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: buttonBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? primaryText,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _showChangeVisibilityDialog(BuildContext context) {
    var initial = video.visibility.toLowerCase();
    if (initial == 'members') initial = 'members_only';
    if (initial == 'subscribers') initial = 'subscribers_only';

    final options = <({String value, String title, String subtitle, IconData icon})>[
      (
        value: 'public',
        title: 'Public',
        subtitle: 'Everyone can search for and watch this video',
        icon: Icons.public_rounded,
      ),
      (
        value: 'private',
        title: 'Private',
        subtitle: 'Only you can view this video',
        icon: Icons.lock_outline_rounded,
      ),
      (
        value: 'members_only',
        title: 'Members Only',
        subtitle: 'Exclusive access for paid channel members',
        icon: Icons.card_membership_rounded,
      ),
      (
        value: 'subscribers_only',
        title: 'Subscribers Only',
        subtitle: 'Exclusive access for subscribers',
        icon: Icons.subscriptions_rounded,
      ),
      (
        value: 'unlisted',
        title: 'Unlisted',
        subtitle: 'Anyone with the video link can watch',
        icon: Icons.link_rounded,
      ),
    ];

    Get.dialog<void>(
      Dialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
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
                      color: buttonBg,
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
                        const Text(
                          'Change Visibility',
                          style: TextStyle(
                            color: primaryText,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: secondaryText,
                            fontSize: 13,
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
                final isCurrent = initial == opt.value;
                return ListTile(
                  leading: Icon(opt.icon, color: Colors.white, size: 20),
                  title: Text(
                    opt.title,
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    opt.subtitle,
                    style: const TextStyle(color: secondaryText, fontSize: 12),
                  ),
                  trailing: isCurrent
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                  onTap: () {
                    Get.back();
                    controller.changeVideoVisibility(video.id, opt.value);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete video?',
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${video.title}"? This action cannot be undone.',
          style: const TextStyle(color: secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(color: secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deleteVideo(video);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: primaryText,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
