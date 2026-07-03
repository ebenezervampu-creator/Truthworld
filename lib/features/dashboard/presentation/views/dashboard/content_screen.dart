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
        Get.find<VideoManagementController>();

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppTheme.colors.background
          : AppTheme.colors.textPrimary,
      body: StreamBuilder<List<Video>>(
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
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return _buildVideoContentCard(video, controller);
            },
          );
        },
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





