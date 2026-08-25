import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/utils/watch_time_formatter.dart';
import 'package:truthworld/features/analytics/presentation/pages/watch_time_page.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/edit_videoscreen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_content_details_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

class ContentScreen extends StatelessWidget {
  const ContentScreen({
    required this.channelId,
    required this.isDarkMode,
    super.key,
    this.searchQuery = '',
  });

  final String channelId;
  final bool isDarkMode;
  final String searchQuery;

  VideoManagementController get controller {
    final ctrl = Get.isRegistered<VideoManagementController>()
        ? Get.find<VideoManagementController>()
        : Get.put(VideoManagementController());
    ctrl.listenToChannelVideos(channelId);
    ctrl.listenToCommunityPosts(channelId);
    return ctrl;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.bgPage,
        appBar: AppBar(
          backgroundColor: AppColors.bgSurface,
          elevation: 0,
          toolbarHeight: 0, // Hide the app bar title portion, only keep TabBar
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                indicatorColor: AppColors.brand,
                indicatorWeight: 3,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.normal,
                ),
                tabs: const [
                  Tab(text: 'Videos'),
                  Tab(text: 'Posts'),
                  Tab(text: 'Drafts'),
                  Tab(text: 'Scheduled'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildVideosTab(context),
            _buildPostsTab(context),
            _buildDraftsTab(context),
            _buildScheduledTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildVideosTab(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingChannelVideos.value) {
        return const Center(
          child: CircularProgressIndicator(
            color: AppColors.brand,
          ),
        );
      }
      if (controller.channelVideosError.value.isNotEmpty) {
        return Center(
          child: Text(
            'Error: ${controller.channelVideosError.value}',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
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

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return _buildVideoContentCard(context, video, controller);
        },
      );
    });
  }

  Widget _buildPostsTab(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingPosts.value) {
        return const Center(
          child: CircularProgressIndicator(
            color: AppColors.brand,
          ),
        );
      }
      if (controller.postsError.value.isNotEmpty) {
        return Center(
          child: Text(
            'Error: ${controller.postsError.value}',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
          ),
        );
      }
      if (controller.communityPosts.isEmpty) {
        return _buildNoPostsYetWidget();
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
        return _buildNoPostsYetWidget(isSearchFiltered: true);
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

  Widget _buildNoPostsYetWidget({bool isSearchFiltered = false}) {
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

  Widget _buildDraftsTab(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingChannelVideos.value ||
          controller.isLoadingPosts.value) {
        return const Center(
          child: CircularProgressIndicator(
            color: AppColors.brand,
          ),
        );
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
                color: AppColors.textTertiary,
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

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is Video) {
            return _buildDraftVideoCard(context, item, controller);
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

  Widget _buildScheduledTab(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingChannelVideos.value ||
          controller.isLoadingPosts.value) {
        return const Center(
          child: CircularProgressIndicator(
            color: AppColors.brand,
          ),
        );
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
            return _buildScheduledVideoCard(context, item, controller);
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

  Widget _buildDraftVideoCard(
    BuildContext context,
    Video video,
    VideoManagementController controller,
  ) {
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
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          debugPrint('🎬 Direct draft resume tapped for video: ${video.id}');
          Get.toNamed(
            '/upload/video',
            arguments: {'video': video, 'videoId': video.id, 'draft': video},
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  child: video.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: video.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const Icon(
                            Icons.drafts_outlined,
                            color: Colors.white,
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.drafts_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'DRAFT',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: const Color(0xFFF59E0B),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      video.title.isNotEmpty ? video.title : 'Untitled Draft',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.videoTitleMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'edit') {
                    Get.toNamed(
                      '/upload/video',
                      arguments: {'video': video, 'videoId': video.id, 'draft': video},
                    );
                  } else if (value == 'delete') {
                    controller.deleteVideo(video);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Resume / Edit Upload'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8),
                        Text('Delete Draft'),
                      ],
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

  Widget _buildScheduledVideoCard(
    BuildContext context,
    Video video,
    VideoManagementController controller,
  ) {
    final scheduledText = DateFormat('MMM dd, yyyy · hh:mm a')
        .format(video.uploadedAt.toDate());

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      color: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                child: video.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: video.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Icon(
                          Icons.schedule_rounded,
                          color: Colors.white,
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.schedule_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF6366F1)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: Color(0xFF818CF8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'SCHEDULED: $scheduledText',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: const Color(0xFF818CF8),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    video.title.isNotEmpty ? video.title : 'Scheduled Video',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.videoTitleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'publish') {
                  controller.updateVideo(video.id, {
                    'status': 'published',
                    'visibility': 'public',
                  });
                } else if (value == 'delete') {
                  controller.deleteVideo(video);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'publish',
                  child: Row(
                    children: [
                      Icon(Icons.publish_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Publish Now'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      SizedBox(width: 8),
                      Text('Delete Scheduled Video'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContentCard(
    BuildContext context,
    Video video,
    VideoManagementController controller,
  ) {
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
        onTap: () => _showVideoActionOptionsModal(context, video),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail container with 16:9 ratio (Compact 96x54)
              // Thumbnail container with 16:9 ratio (Compact 96x54)
              InkWell(
                onTap: () => _showVideoActionOptionsModal(context, video),
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
                  } else if (value == 'visibility') {
                    _showChangeVisibilityDialog(context, video, controller);
                  } else if (value == 'edit') {
                    Get.to<dynamic>(() => EditVideoScreen(video: video));
                  } else if (value == 'reactions_settings') {
                    _showVideoReactionsSettingsDialog(
                      context,
                      video,
                      controller,
                    );
                  } else if (value == 'ai_features') {
                    _showGenerateAIFeaturesDialog(context, video, controller);
                  } else if (value == 'delete') {
                    _showDeleteVideoDialog(context, video, controller);
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

  void _showVideoActionOptionsModal(BuildContext context, Video video) {
    Get.bottomSheet<void>(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                _showChangeVisibilityDialog(context, video, controller);
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
      isScrollControlled: true,
    );
  }

  void _showVideoReactionsSettingsDialog(
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

  void _showDeleteVideoDialog(
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

  void _showGenerateAIFeaturesDialog(
    BuildContext context,
    Video video,
    VideoManagementController controller,
  ) {
    final selectedLangs = <String>{'te', 'hi'}.obs;
    final selectedFeatures = <String>{
      'subtitles',
      'dubbing',
      'factcheck',
      'summary',
      'chapters',
    }.obs;
    final isAccuracyMode = true.obs;
    final showAdvanced = false.obs;

    final availableLangs = [
      {'code': 'te', 'name': 'Telugu (తెలుగు)'},
      {'code': 'hi', 'name': 'Hindi (हिन्दी)'},
      {'code': 'en', 'name': 'English'},
      {'code': 'ta', 'name': 'Tamil (தமிழ்)'},
      {'code': 'kn', 'name': 'Kannada (ಕನ್ನಡ)'},
      {'code': 'ml', 'name': 'Malayalam (മലയാളം)'},
      {'code': 'es', 'name': 'Spanish'},
    ];

    Get.dialog<void>(
      Dialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.bgDivider),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
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
                          Icons.auto_awesome_rounded,
                          color: AppColors.textPrimary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'AI Features & Advanced Settings',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: Get.back<void>,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Generate subtitles, dubbed audio tracks, fact-checking, AI summaries, and chapters anytime on demand.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const Divider(height: 24),

                    // Section 1: Target Languages
                    Text(
                      'Select Target Languages',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableLangs.map((lang) {
                        final code = lang['code']!;
                        final name = lang['name']!;
                        final isSelected = selectedLangs.contains(code);
                        return FilterChip(
                          label: Text(name),
                          selected: isSelected,
                          selectedColor: AppColors.brand.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.brand,
                          labelStyle: AppTextStyles.labelMedium.copyWith(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.brand
                                : AppColors.textPrimary,
                          ),
                          onSelected: (val) {
                            if (val) {
                              selectedLangs.add(code);
                            } else {
                              if (selectedLangs.length > 1) {
                                selectedLangs.remove(code);
                              }
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Section 2: AI Capabilities
                    Text(
                      'Select AI Features to Generate',
                      style: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildFeatureCheckbox(
                      title: 'Subtitles & Closed Captions (SRT/VTT)',
                      subtitle:
                          'Generate native subtitles in selected target languages',
                      icon: Icons.subtitles_outlined,
                      value: selectedFeatures.contains('subtitles'),
                      onChanged: (val) {
                        if (val ?? false) {
                          selectedFeatures.add('subtitles');
                        } else {
                          selectedFeatures.remove('subtitles');
                        }
                      },
                    ),
                    _buildFeatureCheckbox(
                      title: 'AI Audio Dubbing Tracks',
                      subtitle:
                          'Generate natural AI voice tracks in Telugu, Hindi, etc.',
                      icon: Icons.record_voice_over_outlined,
                      value: selectedFeatures.contains('dubbing'),
                      onChanged: (val) {
                        if (val ?? false) {
                          selectedFeatures.add('dubbing');
                        } else {
                          selectedFeatures.remove('dubbing');
                        }
                      },
                    ),
                    _buildFeatureCheckbox(
                      title: 'Fact-Checking & Truth Score Report',
                      subtitle:
                          'Extract claims & verify truthfulness with citations',
                      icon: Icons.fact_check_outlined,
                      value: selectedFeatures.contains('factcheck'),
                      onChanged: (val) {
                        if (val ?? false) {
                          selectedFeatures.add('factcheck');
                        } else {
                          selectedFeatures.remove('factcheck');
                        }
                      },
                    ),
                    _buildFeatureCheckbox(
                      title: 'AI Video Summary & Key Takeaways',
                      subtitle: 'Generate concise summary of video content',
                      icon: Icons.auto_stories_outlined,
                      value: selectedFeatures.contains('summary'),
                      onChanged: (val) {
                        if (val ?? false) {
                          selectedFeatures.add('summary');
                        } else {
                          selectedFeatures.remove('summary');
                        }
                      },
                    ),
                    _buildFeatureCheckbox(
                      title: 'Timestamped Auto-Chapters',
                      subtitle: 'Detect topics and create chapter timestamps',
                      icon: Icons.bookmarks_outlined,
                      value: selectedFeatures.contains('chapters'),
                      onChanged: (val) {
                        if (val ?? false) {
                          selectedFeatures.add('chapters');
                        } else {
                          selectedFeatures.remove('chapters');
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Section 3: Advanced Settings Accordion
                    InkWell(
                      onTap: () => showAdvanced.value = !showAdvanced.value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.settings_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Advanced Settings',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              showAdvanced.value
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showAdvanced.value) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurfaceHover,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Priority Mode',
                                      style: AppTextStyles.labelMedium.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      isAccuracyMode.value
                                          ? 'Accuracy Mode (Universal-3 Pro + Grounding)'
                                          : 'Fast Mode (Draft)',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: isAccuracyMode.value,
                                  activeTrackColor: AppColors.brand,
                                  onChanged: (val) =>
                                      isAccuracyMode.value = val,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurfaceHover,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.bgDivider),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Funding Source:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                r'Channel Revenue & $10 Trial Credit',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Estimated Cost:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '\$${ChannelWalletService.calculateAIFeatureCost(selectedFeatures: selectedFeatures.toSet(), targetLanguages: selectedLangs.toList()).toStringAsFixed(2)}',
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.black,
                            size: 18,
                          ),
                          label: Text(
                            'Generate & Pay from Balance',
                            style: AppTextStyles.buttonText.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: selectedFeatures.isEmpty
                              ? null
                              : () {
                                  Get.back<void>();
                                  controller.triggerAIFeatures(
                                    videoId: video.id,
                                    features: selectedFeatures.toList(),
                                    targetLanguages: selectedLangs.toList(),
                                    priorityMode: isAccuracyMode.value
                                        ? 'accuracy'
                                        : 'speed',
                                    autoChapters: selectedFeatures.contains(
                                      'chapters',
                                    ),
                                  );
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCheckbox({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.brand,
      dense: true,
      contentPadding: EdgeInsets.zero,
      secondary: Icon(
        icon,
        color: Colors.white,
        size: 22,
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }
}
