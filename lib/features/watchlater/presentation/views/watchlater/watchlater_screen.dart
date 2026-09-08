import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/video_options_sheet.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/widgets/shimmer_skeletons.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/watchlater/presentation/controllers/watchlater_controller.dart';
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

class WatchLaterScreen extends StatelessWidget {
  const WatchLaterScreen({super.key, this.isDashboard = false});
  final bool isDashboard;

  WatchLaterController get _controller =>
      Get.isRegistered<WatchLaterController>()
          ? Get.find<WatchLaterController>()
          : Get.put(WatchLaterController());

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final userId = AuthService.to.currentUser.value?.uid;

      if (userId == null || userId.isEmpty) {
        return Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(child: _buildNotLoggedInWidget(context)),
        );
      }

      return Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(child: _buildMainContent(userId)),
      );
    });
  }

  Widget _buildMainContent(String userId) {
    return CustomScrollView(
      controller: _controller.scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, isDashboard ? 16 : 48, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.textPrimary,
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
                      Expanded(
                        child: Obx(() {
                          if (_controller.isSearching.value) {
                            return TextField(
                              controller: _controller.searchController,
                              autofocus: true,
                              style: const TextStyle(
                                color: primaryText,
                                fontSize: 16,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Search Watch Later...',
                                hintStyle: TextStyle(color: secondaryText),
                                border: InputBorder.none,
                              ),
                              onChanged: _controller.setSearchQuery,
                            );
                          }
                          return const Text(
                            'Watch later',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                Obx(() => IconButton(
                      icon: Icon(
                        _controller.isSearching.value
                            ? Icons.close
                            : Icons.search,
                        color: primaryText,
                      ),
                      onPressed: _controller.toggleSearch,
                    )),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: primaryText),
                  onPressed: _showWatchLaterSettingsBottomSheet,
                ),
              ],
            ),
          ),
        ),
        Obx(() {
          if (_controller.rxIsLoading.value &&
              _controller.watchLaterVideos.isEmpty) {
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => const ShimmerVideoListCard(),
                childCount: 6,
              ),
            );
          }

          final videos = _controller.watchLaterVideos;

          if (videos.isEmpty) {
            return const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No watch later videos found',
                  style: TextStyle(color: AppColors.textPrimary),
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

          // Filter by search query
          if (_controller.searchQuery.value.trim().isNotEmpty) {
            final q = _controller.searchQuery.value.trim().toLowerCase();
            displayVideos = displayVideos.where((v) {
              return v.title.toLowerCase().contains(q) ||
                  v.channelName.toLowerCase().contains(q) ||
                  v.category.toLowerCase().contains(q);
            }).toList();
          }

          // Filter by category
          if (_controller.selectedCategory.value != 'All') {
            displayVideos = displayVideos
                .where(
                  (v) => v.category == _controller.selectedCategory.value,
                )
                .toList();
          }

          if (displayVideos.isEmpty) {
            return const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No matching videos found',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            );
          }

          _controller.sortVideos(displayVideos);

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
                        (video) => _WatchLaterListCard(
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
                selectedColor: AppColors.textPrimary,
                backgroundColor: AppColors.bgSurfaceHover,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.bgPage : AppColors.textPrimary,
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
                Icons.watch_later_rounded,
                size: 80,
                color: AppColors.textPrimary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Sign in to see your Watch Later list',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Get.toNamed('/auth'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: AppColors.bgPage,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.bgPage,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWatchLaterSettingsBottomSheet() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
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
            const Text(
              'Watch Later Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
              title: const Text(
                'Play All Videos',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
              ),
              subtitle: const Text(
                'Play all saved videos',
                style: TextStyle(color: secondaryText),
              ),
              onTap: () {
                Get.back();
                _controller.playAll();
              },
            ),
            const Divider(height: 32, color: AppColors.bgDivider),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_sweep_rounded,
                  color: AppColors.error,
                ),
              ),
              title: const Text(
                'Clear All Watch Later',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
                ),
              ),
              subtitle: const Text(
                'Remove all videos from Watch Later',
                style: TextStyle(color: secondaryText),
              ),
              onTap: () {
                Get.back();
                _controller.clearAll();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}

class _WatchLaterListCard extends StatelessWidget {
  const _WatchLaterListCard({required this.video, required this.controller});
  final Video video;
  final WatchLaterController controller;

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
                        Container(color: AppColors.bgSurfaceHover),
                    errorWidget: (context, url, error) =>
                        Container(color: AppColors.bgSurfaceHover),
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
                      color: AppColors.bgPage.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
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
                        onPressed: () {
                          VideoOptionsSheet.show(
                            context,
                            video,
                            onRemoveFromWatchLater: () =>
                                controller.removeFromWatchLater(video.id),
                          );
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${video.channelName} • ${video.views} views',
                    style: const TextStyle(
                      fontSize: 13,
                      color: secondaryText,
                    ),
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
