import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/community_post_card.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/feedback/feedback_service.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/topic_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content/desktop_content_data_table.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content/draft_scheduled_cards.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/content/video_content_card.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/drafts_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/dialogs/create_playlist_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/playlists_view_body.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/topics/topics_widgets.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/trash_restore_screen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic_dialog.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

Widget buildContentLoadingIndicator() {
  return const StudioLoadingIndicator(
    message: 'Loading studio content...',
    isFullScreen: false,
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
      if (controller.isLoadingChannelVideos.value && controller.channelVideos.isEmpty) {
        return buildContentLoadingIndicator();
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
                v.status != VideoStatus.deleted &&
                v.status.name != 'deleted' &&
                v.status.name != 'deletion_pending' &&
                v.status.name != 'trashed' &&
                v.visibility.toLowerCase() != 'draft' &&
                v.visibility.toLowerCase() != 'scheduled' &&
                !v.title.trim().toLowerCase().startsWith('our first video'),
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
      if (controller.isLoadingPosts.value && controller.communityPosts.isEmpty) {
        return buildContentLoadingIndicator();
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

      var posts = controller.communityPosts
          .where(
            (p) =>
                !p.isDeleted &&
                p.status != 'deletion_pending' &&
                p.status != 'trashed' &&
                p.status != 'deleted' &&
                p.id != '8Zq2KuYIgm9m8kgogAE3' &&
                !p.title.trim().toLowerCase().startsWith('our first video'),
          )
          .toList();

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: CommunityPostCard(
                key: ValueKey(post.id),
                post: post,
                isChannelContext: true,
              ),
            ),
          );
        },
      );
    });
  }
}

typedef CommunityTab = PostsTab;

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
      if ((controller.isLoadingChannelVideos.value ||
              controller.isLoadingPosts.value) &&
          controller.channelVideos.isEmpty) {
        return buildContentLoadingIndicator();
      }

      final draftVideos = controller.channelVideos
          .where(
            (v) =>
                v.status != VideoStatus.deleted &&
                v.status.name != 'deleted' &&
                v.status.name != 'deletion_pending' &&
                v.status.name != 'trashed' &&
                (v.isDraft ||
                    v.isUploadingOrProcessing ||
                    v.status == VideoStatus.draft ||
                    v.visibility.toLowerCase() == 'draft' ||
                    v.status.name.toLowerCase() == 'draft'),
          )
          .toList();

      final draftPosts = controller.communityPosts
          .where(
            (p) =>
                !p.isDeleted &&
                p.status != 'deletion_pending' &&
                p.status != 'trashed' &&
                p.status != 'deleted' &&
                p.id != '8Zq2KuYIgm9m8kgogAE3' &&
                !p.title.trim().toLowerCase().startsWith('our first video') &&
                (p.isDraft ||
                    p.visibility.toLowerCase() == 'draft' ||
                    p.selectedCategory.toLowerCase() == 'draft'),
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
                    isChannelContext: true,
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
      if ((controller.isLoadingChannelVideos.value ||
              controller.isLoadingPosts.value) &&
          controller.channelVideos.isEmpty) {
        return buildContentLoadingIndicator();
      }

      final scheduledVideos = controller.channelVideos
          .where(
            (v) =>
                v.status != VideoStatus.deleted &&
                v.status.name != 'deleted' &&
                v.status.name != 'deletion_pending' &&
                v.status.name != 'trashed' &&
                (v.status == VideoStatus.scheduled ||
                    v.status.name == 'scheduled' ||
                    v.visibility == 'scheduled' ||
                    v.scheduledPublishAt != null),
          )
          .toList();

      final scheduledPosts = controller.communityPosts
          .where(
            (p) =>
                !p.isDeleted &&
                p.status != 'deletion_pending' &&
                p.status != 'trashed' &&
                p.status != 'deleted' &&
                p.id != '8Zq2KuYIgm9m8kgogAE3' &&
                !p.title.trim().toLowerCase().startsWith('our first video') &&
                p.scheduledTime != null,
          )
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
              isChannelContext: true,
            );
          }
        },
      );
    });
  }
}

class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({
    required this.channelId,
    required this.isDarkMode,
    this.searchQuery = '',
    super.key,
  });

  final String channelId;
  final bool isDarkMode;
  final String searchQuery;

  String get activeChannelId {
    if (channelId.isNotEmpty) {
      return channelId;
    }
    if (Get.isRegistered<AuthService>() &&
        AuthService.to.userChannel?.id != null) {
      return AuthService.to.userChannel!.id;
    }
    return AuthService.to.uid;
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<PlaylistsManagementController>()
        ? Get.find<PlaylistsManagementController>()
        : Get.put(PlaylistsManagementController());

    if (searchQuery.isNotEmpty && controller.searchQuery.value != searchQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.searchQuery.value = searchQuery;
      });
    }

    final effectiveChannelId = activeChannelId;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final horizontalPadding = isMobile ? 16.0 : 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Obx(() {
                    final count = controller.filteredPlaylists.length;
                    return Text(
                      'Playlists ($count)',
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    );
                  }),
                  ElevatedButton.icon(
                    onPressed: () {
                      CreatePlaylistDialog.show(
                        context,
                        channelId: effectiveChannelId,
                      );
                    },
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: Colors.black,
                    ),
                    label: const Text(
                      'New Playlist',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PlaylistsViewBody(channelId: effectiveChannelId),
            ],
          ),
        );
      },
    );
  }
}

class TopicsTab extends StatelessWidget {
  const TopicsTab({
    required this.channelId,
    required this.isDarkMode,
    this.searchQuery = '',
    super.key,
  });

  final String channelId;
  final bool isDarkMode;
  final String searchQuery;

  String get activeChannelId {
    if (channelId.isNotEmpty) {
      return channelId;
    }
    if (Get.isRegistered<AuthService>() &&
        AuthService.to.userChannel?.id != null) {
      return AuthService.to.userChannel!.id;
    }
    return AuthService.to.uid;
  }

  void _showCreateTopicDialog(
    BuildContext context,
    TopicManagementController controller,
    String effectiveChannelId,
  ) {
    CreateTopicDialog.show(
      context: context,
      isDarkMode: isDarkMode,
      channelVideosFuture: controller.fetchChannelVideos(effectiveChannelId),
      onCreateTopicSubmitted: (createCtrl) async {
        String? finalThumbnailUrl;
        if (createCtrl.thumbnailSource.value == 'custom' &&
            createCtrl.pickedCustomImageBytes.value != null) {
          finalThumbnailUrl = await controller.uploadTopicThumbnail(
            createCtrl.pickedCustomImageBytes.value!,
            createCtrl.pickedCustomImageName.value ?? 'custom_topic_thumb.jpg',
          );
        } else if (createCtrl.thumbnailSource.value == 'video') {
          finalThumbnailUrl = createCtrl.chosenVideoThumbnailUrl.value;
        }

        await controller.createTopic(
          channelId: effectiveChannelId,
          name: createCtrl.nameController.text,
          handle: createCtrl.handleController.text,
          description: createCtrl.descriptionController.text,
          category: createCtrl.categoryController.text.isEmpty
              ? 'General'
              : createCtrl.categoryController.text,
          selectedVideoIds: createCtrl.selectedVideoIds,
          visibilityType: createCtrl.selectedVisibility.value,
          accessCode: createCtrl.selectedVisibility.value == TopicVisibilityType.private
              ? createCtrl.accessCodeController.text.trim()
              : null,
          thumbnailUrl: finalThumbnailUrl,
        );
      },
    );
  }

  bool _haveTopicsChanged(List<Topic> current, List<Topic> incoming) {
    if (current.length != incoming.length) return true;
    for (var i = 0; i < current.length; i++) {
      if (current[i].id != incoming[i].id ||
          current[i].updatedAt != incoming[i].updatedAt ||
          current[i].title != incoming[i].title ||
          current[i].videoCount != incoming[i].videoCount ||
          current[i].visibilityType != incoming[i].visibilityType ||
          current[i].thumbnailUrl != incoming[i].thumbnailUrl ||
          current[i].category != incoming[i].category) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<TopicManagementController>()
        ? Get.find<TopicManagementController>()
        : Get.put(TopicManagementController());

    controller.onEditTopicRequested = (ctx, topic) {
      final isOwner =
          Get.isRegistered<AuthService>() &&
          ((topic.channelId != null &&
                  topic.channelId!.isNotEmpty &&
                  AuthService.to.userChannel?.id == topic.channelId) ||
              (topic.creatorId != null &&
                  topic.creatorId!.isNotEmpty &&
                  AuthService.to.uid == topic.creatorId));

      if (!isOwner) {
        SnackbarService.error(
          message: 'Only the topic creator channel can edit this topic.',
        );
        return;
      }

      EditTopicDialog.show(
        context: ctx,
        topic: topic,
        channelId: topic.channelId ?? activeChannelId,
        isDarkMode: isDarkMode,
        controller: controller,
      );
    };

    if (searchQuery.isNotEmpty && controller.searchQuery.value != searchQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.searchQuery.value = searchQuery;
      });
    }

    final effectiveChannelId = activeChannelId;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final horizontalPadding = isMobile ? 16.0 : 24.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Obx(() {
                    final count = controller.topicsList.length;
                    return Text(
                      'Topics ($count)',
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    );
                  }),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateTopicDialog(
                      context,
                      controller,
                      effectiveChannelId,
                    ),
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: Colors.black,
                    ),
                    label: const Text(
                      'New Topic',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Topic>>(
                stream: controller.fetchChannelTopics(effectiveChannelId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const TopicLoadingGrid();
                  }
                  if (snapshot.hasError) {
                    ErrorHandler.log(
                      snapshot.error,
                      tag: 'TopicsTab.stream',
                    );
                    return TopicErrorState(
                      error: UserFeedbackSanitizer.sanitizeMessage(
                        snapshot.error,
                        defaultActionContext:
                            'Unable to load topics. Please check your connection and try again.',
                      ),
                      onRetry: () => controller.update(),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const TopicEmptyState();
                  }

                  final topics = snapshot.data!;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_haveTopicsChanged(controller.topicsList, topics)) {
                      controller.topicsList.assignAll(topics);
                    }
                  });

                  return Obx(() {
                    final query = searchQuery.isNotEmpty
                        ? searchQuery.trim().toLowerCase()
                        : controller.searchQuery.value.trim().toLowerCase();
                    final filterMode = controller.activeFilterMode.value;

                    var baseTopics = topics;
                    if (filterMode == 'public') {
                      baseTopics = topics
                          .where((t) =>
                              t.visibilityType == TopicVisibilityType.public &&
                              t.status.toLowerCase() == 'active')
                          .toList();
                    } else if (filterMode == 'private') {
                      baseTopics = topics
                          .where((t) => t.visibilityType == TopicVisibilityType.private)
                          .toList();
                    } else if (filterMode == 'rejected') {
                      baseTopics = topics
                          .where((t) =>
                              t.status.toLowerCase() == 'verificationrejected' ||
                              t.status.toLowerCase() == 'rejected')
                          .toList();
                    }

                    final filtered = query.isEmpty
                        ? baseTopics
                        : baseTopics.where((topic) {
                            return topic.name.toLowerCase().contains(query) ||
                                topic.handle.toLowerCase().contains(query) ||
                                topic.description.toLowerCase().contains(query) ||
                                topic.category.toLowerCase().contains(query);
                          }).toList();

                    if (filtered.isEmpty) {
                      return TopicSearchEmptyState(controller: controller);
                    }

                    return TopicGridView(
                      topics: filtered,
                      controller: controller,
                    );
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class TrashTab extends StatelessWidget {
  const TrashTab({
    required this.channelId,
    required this.isDarkMode,
    this.searchQuery = '',
    super.key,
  });

  final String channelId;
  final bool isDarkMode;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return TrashRestoreScreen(
      channelId: channelId,
      isDarkMode: isDarkMode,
      searchQuery: searchQuery,
      isConsumer: false,
      isStudioContentTab: true,
    );
  }
}
