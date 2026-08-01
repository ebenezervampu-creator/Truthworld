import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/video/presentation/controllers/download_videoplayer.dart';
import 'package:truthworld/theme/app_theme.dart';

class OfflineVideoPlayerPage extends StatelessWidget {
  const OfflineVideoPlayerPage({
    required this.videoId,
    required this.title,
    required this.video,
    super.key,
  });
  final String videoId;
  final String title;
  final OfflineVideo video;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OfflineVideoController>();
    controller.videoId = videoId;
    // Load video data once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadVideo();
    });
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: Get.back,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast, color: AppColors.textPrimary),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.error),
          );
        }
        if (controller.videoUrl.value.isEmpty) {
          return const Center(
            child: Text(
              'Video not found',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          );
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Video Player
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(
                  color: AppColors.bgPage,
                  child: HtmlElementView(
                    viewType: 'video-${controller.videoId}',
                  ),
                ),
              ),

              // Video Info Section
              Container(
                color: AppColors.bgPage,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Views
                    Text(
                      '${video.views} views',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionButton(Icons.thumb_up_outlined, ''),
                        _buildActionButton(Icons.thumb_down_outlined, ''),
                        _buildActionButton(Icons.share, 'Share'),
                        _buildActionButton(Icons.download, 'Download'),
                        _buildActionButton(Icons.playlist_add, 'Save'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.textSecondary, height: 1),
                    const SizedBox(height: 16),

                    // Channel Info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(video.channelImage),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                video.channelName,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: AppColors.textPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text('SUBSCRIBE'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textPrimary, size: 24),
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}
