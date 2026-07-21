import 'package:cached_network_image/cached_network_image.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/edit_videoscreen.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/video_management.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/video_pipeline_status.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';

class ContentScreen extends StatelessWidget {
  final String channelId;
  final bool isDarkMode;
  final String searchQuery;

  const ContentScreen({
    super.key,
    required this.channelId,
    required this.isDarkMode,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    final VideoManagementController controller =
        Get.isRegistered<VideoManagementController>()
            ? Get.find<VideoManagementController>()
            : Get.put(VideoManagementController());

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDarkMode
            ? AppTheme.colors.background
            : AppTheme.colors.textPrimary,
        appBar: AppBar(
          backgroundColor: isDarkMode
              ? AppTheme.colors.surface
              : AppTheme.colors.textPrimary,
          elevation: 0,
          toolbarHeight: 0, // Hide the app bar title portion, only keep TabBar
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                indicatorColor: AppColors.brand,
                labelColor: isDarkMode ? Colors.white : Colors.black,
                unselectedLabelColor: Colors.grey,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: GoogleFonts.roboto(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                tabs: const [
                  Tab(text: 'Videos'),
                  Tab(text: 'Posts'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildVideosTab(context, controller),
            _buildPostsTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildVideosTab(
    BuildContext context,
    VideoManagementController controller,
  ) {
    return StreamBuilder<List<Video>>(
      stream: controller.fetchChannelVideos(channelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam_off_outlined,
                  size: 80,
                  color: isDarkMode
                      ? AppColors.textPrimary38
                      : AppTheme.colors.textSecondary,
                ),
                const SizedBox(height: 20),
                Text(
                  'No Content Yet',
                  style: GoogleFonts.roboto(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppTheme.colors.textPrimary70
                        : AppTheme.colors.background54,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload your first video to get started!',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    color: isDarkMode
                        ? AppTheme.colors.textPrimary54
                        : AppTheme.colors.background45,
                  ),
                ),
              ],
            ),
          );
        }

        var videos = snapshot.data!;

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
                Icon(
                  Icons.search_off_rounded,
                  size: 80,
                  color: isDarkMode
                      ? AppTheme.colors.textPrimary30
                      : AppTheme.colors.textSecondary,
                ),
                const SizedBox(height: 20),
                Text(
                  'No matching content found',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? AppTheme.colors.textPrimary70
                        : AppTheme.colors.background54,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try searching with different keywords',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: isDarkMode
                        ? AppTheme.colors.textPrimary54
                        : AppTheme.colors.background45,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            return _buildVideoContentCard(video, controller);
          },
        );
      },
    );
  }

  Widget _buildPostsTab(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Community')
          .where('channelId', isEqualTo: channelId)
          .where('ownerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoPostsYetWidget();
        }

        var docs = snapshot.data!.docs;
        List<CommunityPostModel> posts = docs
            .map((doc) => CommunityPostModel.fromMap(doc.data() as Map<String, dynamic>))
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
          return _buildNoPostsYetWidget(isSearchFiltered: true);
        }

        // Sort posts chronologically descending
        posts.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return _buildPostContentCard(context, post);
          },
        );
      },
    );
  }

  Widget _buildPostContentCard(BuildContext context, CommunityPostModel post) {
    final hasImages = post.images.isNotEmpty;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: isDarkMode ? AppTheme.colors.surface : AppTheme.colors.textPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image / Thumbnail
            Container(
              width: 120,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isDarkMode ? AppTheme.colors.background : Colors.grey[200],
              ),
              child: hasImages
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: post.images.first,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      ),
                    )
                  : const Icon(Icons.article_outlined, size: 36, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            // Post Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title.isNotEmpty ? post.title : post.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: isDarkMode
                          ? AppTheme.colors.textPrimary
                          : AppTheme.colors.background87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.thumb_up_outlined,
                        size: 14,
                        color: AppTheme.colors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likes} likes',
                        style: TextStyle(
                          color: AppTheme.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppTheme.colors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, yyyy').format(post.uploadedAt),
                        style: TextStyle(
                          color: AppTheme.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Action Menu
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  Get.defaultDialog(
                    title: "Delete Post?",
                    middleText:
                        "Are you sure you want to delete this post? This action cannot be undone.",
                    textConfirm: "Delete",
                    textCancel: "Cancel",
                    confirmTextColor: AppTheme.colors.textPrimary,
                    onConfirm: () async {
                      try {
                        await FirebaseFirestore.instance
                            .collection('Community')
                            .doc(post.id)
                            .delete();
                        Get.back(); // Close dialog
                        Get.snackbar("Success", "Post deleted successfully.");
                      } catch (e) {
                        Get.snackbar("Error", "Failed to delete post: $e");
                      }
                    },
                  );
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: AppTheme.colors.primary,
                    ),
                    title: Text(
                      'Delete',
                      style: TextStyle(color: AppTheme.colors.primary),
                    ),
                  ),
                ),
              ],
              icon: Icon(
                Icons.more_vert,
                color: isDarkMode
                    ? AppTheme.colors.textPrimary70
                    : AppTheme.colors.background54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPostsYetWidget({bool isSearchFiltered = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearchFiltered ? Icons.search_off_rounded : Icons.chat_bubble_outline,
            size: 80,
            color: isDarkMode
                ? AppColors.textPrimary38
                : AppTheme.colors.textSecondary,
          ),
          const SizedBox(height: 20),
          Text(
            isSearchFiltered ? 'No matching posts found' : 'No Community Posts Yet',
            style: GoogleFonts.roboto(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDarkMode
                  ? AppTheme.colors.textPrimary70
                  : AppTheme.colors.background54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearchFiltered
                ? 'Try searching with different keywords'
                : 'Create your first post in the upload section!',
            style: GoogleFonts.roboto(
              fontSize: 16,
              color: isDarkMode
                  ? AppTheme.colors.textPrimary54
                  : AppTheme.colors.background45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoContentCard(
    Video video,
    VideoManagementController controller,
  ) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 16),
      color: isDarkMode ? AppTheme.colors.surface : AppTheme.colors.textPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Thumbnail
                Container(
                  width: 120,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(video.thumbnailUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Video Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: isDarkMode
                              ? AppTheme.colors.textPrimary
                              : AppTheme.colors.background87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 14,
                            color: AppTheme.colors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${video.views} views',
                            style: TextStyle(
                              color: AppTheme.colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: AppTheme.colors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat(
                              'MMM d, yyyy',
                            ).format(video.uploadedAt.toDate()),
                            style: TextStyle(
                              color: AppTheme.colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      Get.to(() => EditVideoScreen(video: video));
                    } else if (value == 'delete') {
                      Get.defaultDialog(
                        title: "Delete Video?",
                        middleText:
                            "Are you sure you want to delete '${video.title}'? This action cannot be undone.",
                        textConfirm: "Delete",
                        textCancel: "Cancel",
                        confirmTextColor: AppTheme.colors.textPrimary,
                        onConfirm: () {
                          controller.deleteVideo(video);
                          Get.back(); // Close dialog
                        },
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_outline,
                          color: AppTheme.colors.primary,
                        ),
                        title: Text(
                          'Delete',
                          style: TextStyle(color: AppTheme.colors.primary),
                        ),
                      ),
                    ),
                  ],
                  icon: Icon(
                    Icons.more_vert,
                    color: isDarkMode
                        ? AppTheme.colors.textPrimary70
                        : AppTheme.colors.background54,
                  ),
                ),
              ],
            ),
            VideoPipelineStatusWidget(
              video: video,
              isDarkMode: isDarkMode,
            ),
          ],
        ),
      ),
    );
  }
}





