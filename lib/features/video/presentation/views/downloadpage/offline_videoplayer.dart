import 'package:truthworld/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/video/presentation/controllers/download_videoplayer.dart';

class OfflineVideoPlayerPage extends StatelessWidget {
  final String videoId;
  final String title;
  final OfflineVideo video;

  const OfflineVideoPlayerPage({
    super.key,
    required this.videoId,
    required this.title,
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OfflineVideoController());
    controller.videoId = videoId;
    // Load video data once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.loadVideo();
    });
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
        }
        if (controller.videoUrl.value.isEmpty) {
          return const Center(
            child: Text(
              'Video not found',
              style: TextStyle(color: Colors.white),
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
                child: Container(
                  color: Colors.black,
                  child: HtmlElementView(
                    viewType: 'video-${controller.videoId}',
                  ),
                ),
              ),

              // Video Info Section
              Container(
                color: AppColors.bgPage,
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Views
                    Text(
                      '${video.views} views',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
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
                    const Divider(color: Colors.grey, height: 1),
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
                                style: TextStyle(
                                  color: Colors.white,
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
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
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
        Icon(icon, color: Colors.white, size: 24),
        if (label.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              label,
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
      ],
    );
  }
}







