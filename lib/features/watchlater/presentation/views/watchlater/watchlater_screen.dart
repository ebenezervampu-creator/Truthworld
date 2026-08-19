import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/loading_state.dart';
import 'package:truthworld/components/ui/video_card.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/watchlater/presentation/controllers/watchlater_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class WatchLaterScreen extends GetView<WatchLaterController> {
  const WatchLaterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
          ),
          onPressed: Get.back,
        ),
        title: Obx(() {
          if (controller.isSearching.value) {
            return TextField(
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Search Watch Later...',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                border: InputBorder.none,
              ),
              onChanged: (query) => controller.searchQuery.value = query,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Watch Later',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${controller.watchLaterVideos.length} videos',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          );
        }),
        actions: [
          Obx(() => IconButton(
                icon: Icon(
                  controller.isSearching.value ? Icons.close : Icons.search,
                  color: AppColors.textPrimary,
                ),
                onPressed: controller.toggleSearch,
              )),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: AppColors.textPrimary,
            ),
            color: AppColors.bgSurface,
            onSelected: (value) {
              if (value == 'clear_all') {
                controller.clearAll();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Clear all Watch Later',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Obx(() {
        if (controller.rxIsLoading.value && controller.watchLaterVideos.isEmpty) {
          return const LoadingState(
            color: AppColors.textPrimary,
          );
        }

        final videos = controller.filteredVideos;

        if (videos.isEmpty) {
          return _buildEmptyState(context);
        }

        return RefreshIndicator(
          onRefresh: () async => controller.fetchWatchLaterVideos(),
          color: AppColors.textPrimary,
          backgroundColor: AppColors.bgSurface,
          child: Column(
            children: [
              _buildHeaderSection(context),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: videos.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: AppColors.bgDivider,
                    height: 16,
                  ),
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    return _buildDismissibleVideoItem(context, video);
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(
          bottom: BorderSide(color: AppColors.bgDivider),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.watch_later_outlined,
                color: AppColors.textPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Obx(() => Text(
                    '${controller.filteredVideos.length} saved videos',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  )),
            ],
          ),
          ElevatedButton.icon(
            onPressed: controller.playAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bgElevated,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 20,
            ),
            label: const Text(
              'Play All',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissibleVideoItem(BuildContext context, Video video) {
    return Dismissible(
      key: Key('watchlater_${video.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.error,
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 28,
        ),
      ),
      onDismissed: (direction) {
        controller.removeFromWatchLater(video.id);
      },
      child: Stack(
        children: [
          VideoCard(
            video: video,
            onTap: () {
              Get.toNamed(
                '/videoscreen',
                arguments: {'video': video},
              );
            },
          ),
          Positioned(
            right: 8,
            top: 8,
            child: PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: AppColors.textPrimary,
              ),
              color: AppColors.bgSurface,
              onSelected: (value) {
                if (value == 'remove') {
                  controller.removeFromWatchLater(video.id);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Remove from Watch Later',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.bgSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.watch_later_outlined,
                size: 64,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              controller.searchQuery.isNotEmpty
                  ? 'No matching videos found'
                  : 'Your Watch Later list is empty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              controller.searchQuery.isNotEmpty
                  ? 'Try searching for another keyword.'
                  : 'Save videos to watch later and they will show up here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () {
                if (controller.searchQuery.isNotEmpty) {
                  controller.searchQuery.value = '';
                } else {
                  Get.offAllNamed('/home');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bgElevated,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              icon: const Icon(
                Icons.explore_outlined,
                color: Colors.white,
              ),
              label: Text(
                controller.searchQuery.isNotEmpty
                    ? 'Clear Search'
                    : 'Explore Videos',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
