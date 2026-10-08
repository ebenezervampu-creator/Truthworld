import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content/desktop_content_data_table.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content/draft_scheduled_cards.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content/video_content_card.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/drafts_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

Widget buildContentShimmerSkeleton() {
  return Shimmer.fromColors(
    baseColor: const Color(0xFF1E1E1E),
    highlightColor: AppColors.bgSurfaceHover,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: 7,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );
}

class VideosTab extends StatelessWidget {
  const VideosTab({
    required this.controller,
    required this.isDarkMode,
    this.searchQuery = '',
    super.key,
  });

  final VideoManagementController controller;
  final bool isDarkMode;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingChannelVideos.value) {
        return buildContentShimmerSkeleton();
      }
      if (controller.channelVideosError.value.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.signal_wifi_connected_no_internet_4_rounded,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to load videos. Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: controller.refreshChannelVideos,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                  label: const Text('Try Again', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      }
      if (controller.channelVideos.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                size: 72,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'No Content Yet',
                style: AppTextStyles.pageTitle.copyWith(
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload your first video to get started!',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }

      var videos = controller.channelVideos
          .where(
            (v) =>
                !v.isDraft &&
                !v.isUploadingOrProcessing &&
                v.status != VideoStatus.draft &&
                v.status != VideoStatus.scheduled &&
                v.visibility.toLowerCase() != 'draft' &&
                v.visibility.toLowerCase() != 'scheduled',
          )
          .toList();

      // Filter videos based on search query
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        videos = videos
            .where(
              (video) =>
                  video.title.toLowerCase().contains(query) ||
                  video.description.toLowerCase().contains(query) ||
                  video.tags.any(
                    (tag) => tag.toLowerCase().contains(query),
                  ),
            )
            .toList();
      }

      if (videos.isEmpty && searchQuery.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 72,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'No matching content found',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching with different keywords',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1100) {
            return DesktopContentDataTable(
              videos: videos,
              controller: controller,
              isDarkMode: isDarkMode,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return VideoContentCard(
                video: video,
                controller: controller,
                isDarkMode: isDarkMode,
              );
            },
          );
        },
      );
    });
  }


}

class PostsTab extends StatelessWidget {
  const PostsTab({
    required this.controller,
    this.searchQuery = '',
    super.key,
  });

  final VideoManagementController controller;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingPosts.value) {
        return buildContentShimmerSkeleton();
      }
      if (controller.postsError.value.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.signal_wifi_connected_no_internet_4_rounded,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to load community posts. Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: controller.refreshCommunityPosts,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                  label: const Text('Try Again', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      }
      if (controller.communityPosts.isEmpty) {
        return const NoPostsYetWidget();
      }

      var posts = controller.communityPosts.toList();

      // Filter posts based on search query
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        posts = posts
            .where(
              (post) =>
                  post.title.toLowerCase().contains(query) ||
                  post.description.toLowerCase().contains(query),
            )
            .toList();
      }

      if (posts.isEmpty && searchQuery.isNotEmpty) {
        return const NoPostsYetWidget(isSearchFiltered: true);
      }

      // Sort posts chronologically descending
      posts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return CommunityPostCard(
            key: ValueKey(post.id),
            post: post,
          );
        },
      );
    });
  }


}

class NoPostsYetWidget extends StatelessWidget {
  const NoPostsYetWidget({this.isSearchFiltered = false, super.key});
  final bool isSearchFiltered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearchFiltered
                ? Icons.search_off_rounded
                : Icons.chat_bubble_outline,
            size: 72,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            isSearchFiltered
                ? 'No matching posts found'
                : 'No Community Posts Yet',
            style: AppTextStyles.pageTitle.copyWith(
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearchFiltered
                ? 'Try searching with different keywords'
                : 'Create your first post in the community section!',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }


}

class DraftsTab extends StatelessWidget {
  const DraftsTab({
    required this.channelId,
    required this.isDarkMode,
    required this.controller,
    this.searchQuery = '',
    super.key,
  });

  final String channelId;
  final bool isDarkMode;
  final VideoManagementController controller;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingChannelVideos.value ||
          controller.isLoadingPosts.value) {
        return buildContentShimmerSkeleton();
      }

      final draftVideos = controller.channelVideos
          .where(
            (v) =>
                v.isDraft ||
                v.isUploadingOrProcessing ||
                v.status == VideoStatus.draft ||
                v.visibility.toLowerCase() == 'draft' ||
                v.status.name.toLowerCase() == 'draft',
          )
          .toList();

      final draftPosts = controller.communityPosts
          .where(
            (p) =>
                p.isDraft ||
                p.visibility.toLowerCase() == 'draft' ||
                p.selectedCategory.toLowerCase() == 'draft',
          )
          .toList();

      if (draftVideos.isEmpty && draftPosts.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.drafts_outlined,
                size: 72,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                'No Drafts Available',
                style: AppTextStyles.pageTitle.copyWith(
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Drafts you save while creating videos or posts will appear here.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Get.to<dynamic>(
                    () => DraftsScreen(
                      channelId: channelId,
                      isDarkMode: isDarkMode,
                    ),
                  );
                },
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  'Open Drafts Manager',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.bgDivider),
                  backgroundColor: AppColors.bgSurface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      var items = <dynamic>[...draftVideos, ...draftPosts];

      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        items = items.where((item) {
          if (item is Video) {
            return item.title.toLowerCase().contains(query) ||
                item.description.toLowerCase().contains(query);
          } else if (item is CommunityPostModel) {
            return item.title.toLowerCase().contains(query) ||
                item.description.toLowerCase().contains(query);
          }
          return false;
        }).toList();
      }

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Drafts (${items.length})',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Get.to<dynamic>(
                      () => DraftsScreen(
                        channelId: channelId,
                        isDarkMode: isDarkMode,
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Advanced Drafts Manager',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.bgDivider),
                    backgroundColor: AppColors.bgSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                if (item is Video) {
                  return DraftVideoCard(video: item, controller: controller);
                } else {
                  return CommunityPostCard(
                    key: ValueKey((item as CommunityPostModel).id),
                    post: item,
                  );
                }
              },
            ),
          ),
        ],
      );
    });
  }


}

class ScheduledTab extends StatelessWidget {
  const ScheduledTab({
    required this.controller,
    this.searchQuery = '',
    super.key,
  });

  final VideoManagementController controller;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingChannelVideos.value ||
          controller.isLoadingPosts.value) {
        return buildContentShimmerSkeleton();
      }

      final scheduledVideos = controller.channelVideos
          .where(
            (v) =>
                v.status == VideoStatus.scheduled ||
                v.status.name == 'scheduled' ||
                v.visibility == 'scheduled' ||
                v.scheduledPublishAt != null,
          )
          .toList();

      final scheduledPosts = controller.communityPosts
          .where((p) => p.scheduledTime != null)
          .toList();

      if (scheduledVideos.isEmpty && scheduledPosts.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 72,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'No Scheduled Content',
                style: AppTextStyles.pageTitle.copyWith(
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Videos and posts scheduled for future release will appear here.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }

      var items = <dynamic>[...scheduledVideos, ...scheduledPosts];

      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        items = items.where((item) {
          if (item is Video) {
            return item.title.toLowerCase().contains(query) ||
                item.description.toLowerCase().contains(query);
          } else if (item is CommunityPostModel) {
            return item.title.toLowerCase().contains(query) ||
                item.description.toLowerCase().contains(query);
          }
          return false;
        }).toList();
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is Video) {
            return ScheduledVideoCard(video: item, controller: controller);
          } else {
            return CommunityPostCard(
              key: ValueKey((item as CommunityPostModel).id),
              post: item,
            );
          }
        },
      );
    });
  }


}
