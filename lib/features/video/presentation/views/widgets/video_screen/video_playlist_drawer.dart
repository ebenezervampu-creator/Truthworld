import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/playlist_detail_screen.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_interactive_avatars.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive playlist queue drawer displaying loop/shuffle controls and playable track list.
class VideoPlaylistDrawer extends StatelessWidget {
  const VideoPlaylistDrawer({
    required this.controller,
    super.key,
  });

  final VideoController controller;

  void _navigateToPlaylistDetail(PlaylistModel playlist) {
    Get.to(() => PlaylistDetailScreen(playlist: playlist));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Rotating Playlist Avatar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Obx(
                  () => RotatingPlaylistAvatar(
                    playlist: controller.currentPlaylist.value!,
                    isPlaying: controller.isPlayingRx.value,
                    size: 46,
                    onTap: () => _navigateToPlaylistDetail(
                      controller.currentPlaylist.value!,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _navigateToPlaylistDetail(
                      controller.currentPlaylist.value!,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.currentPlaylist.value!.playlistName,
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${controller.video.channelName.isNotEmpty ? '${controller.video.channelName} - ' : ''}${controller.currentPlaylistIndex.value + 1} / ${controller.playlistVideos.length}",
                          style: GoogleFonts.roboto(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => controller.showPlaylistDrawer.value = false,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Obx(
                  () => IconButton(
                    icon: Icon(
                      Icons.repeat,
                      color: controller.isPlaylistLooping.value
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                    onPressed: () => controller.isPlaylistLooping.value =
                        !controller.isPlaylistLooping.value,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(width: 16),
                Obx(
                  () => IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color: controller.isPlaylistShuffled.value
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                    onPressed: () {
                      controller.isPlaylistShuffled.value =
                          !controller.isPlaylistShuffled.value;
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Videos List
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: controller.playlistVideos.length,
              itemBuilder: (context, index) {
                final video = controller.playlistVideos[index];
                final isActive = index == controller.currentPlaylistIndex.value;

                return InkWell(
                  onTap: () => controller.playPlaylistVideoAtIndex(index),
                  child: Container(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          child: Center(
                            child: isActive
                                ? Obx(
                                    () => PlayingAudioWaveAnimation(
                                      isPlaying: controller.isPlayingRx.value,
                                      height: 16,
                                    ),
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: GoogleFonts.roboto(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: video.thumbnailUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: video.thumbnailUrl,
                                  width: 100,
                                  height: 56,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 100,
                                  height: 56,
                                  color: Colors.grey[800],
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                video.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                video.channelName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.roboto(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
