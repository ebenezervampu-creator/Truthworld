import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_detail_screen.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_interactive_avatars.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Banner displaying current playlist context, progress, and navigation trigger.
class VideoPlaylistBanner extends StatelessWidget {
  const VideoPlaylistBanner({
    required this.controller,
    required this.playlist,
    super.key,
  });

  final VideoController controller;
  final PlaylistModel playlist;

  void _navigateToPlaylistDetail() {
    Get.to(() => PlaylistDetailScreen(playlist: playlist));
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isPlaying = controller.isPlayingRx.value;
      final currentIndex = controller.calculatedPlaylistIndex;
      final totalVideos = controller.playlistVideos.isNotEmpty
          ? controller.playlistVideos.length
          : (playlist.videoIds.isNotEmpty
              ? playlist.videoIds.length
              : (playlist.videoCount > 0 ? playlist.videoCount : 1));

      return Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.brand.withValues(alpha: 0.25),
              AppColors.bgSurface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.brand.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _navigateToPlaylistDetail,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  RotatingPlaylistAvatar(
                    playlist: playlist,
                    isPlaying: isPlaying,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brand,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PLAYLIST',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                playlist.playlistName,
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            PlayingAudioWaveAnimation(
                              isPlaying: isPlaying,
                              height: 12,
                              barWidth: 2,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Playing video ${currentIndex + 1} of $totalVideos',
                              style: GoogleFonts.roboto(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Banner displaying current topic context and bottom sheet trigger.
class VideoTopicBanner extends StatelessWidget {
  const VideoTopicBanner({
    required this.controller,
    required this.topic,
    this.videoTag,
    super.key,
  });

  final VideoController controller;
  final Topic topic;
  final String? videoTag;

  void _showTopicBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TopicVideosBottomSheet(
        topic: topic,
        videoTag: videoTag,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isPlaying = controller.isPlayingRx.value;

      return Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF3B82F6).withValues(alpha: 0.25),
              AppColors.bgSurface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showTopicBottomSheet(context),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  RotatingTopicAvatar(
                    topic: topic,
                    isPlaying: isPlaying,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'TOPIC',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                topic.title,
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            PlayingAudioWaveAnimation(
                              isPlaying: isPlaying,
                              height: 12,
                              barWidth: 2,
                              color: const Color(0xFF3B82F6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${topic.videoCount > 0 ? '${topic.videoCount} videos' : 'Topic Hub'} • Tap to view topic videos',
                              style: GoogleFonts.roboto(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
