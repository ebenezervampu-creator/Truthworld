import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/detail/playlist_detail_constants.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/detail/playlist_detail_video_loader.dart';

/// Action buttons for playlist playback, shuffle, download, and sharing.
class PlaylistActionButtons extends StatelessWidget {
  const PlaylistActionButtons({
    required this.playlist,
    super.key,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final PlaylistModel playlist;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Play all button (white primary)
        Expanded(
          flex: 2,
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: ytTextPrimary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => playAllPlaylistVideos(playlist),
                borderRadius: BorderRadius.circular(18),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow, color: ytBackground, size: 20),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Play all',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: ytBackground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Shuffle button (dark surface)
        Expanded(
          flex: 2,
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: ytSurfaceLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => shufflePlaylistVideos(playlist),
                borderRadius: BorderRadius.circular(18),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shuffle, color: Colors.white, size: 18),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Shuffle',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: ytTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isDesktop) ...[
          const SizedBox(width: 8),
          const PlaylistActionButtonIcon(
            icon: Icons.download,
            onTap: HapticFeedback.lightImpact,
            tooltip: 'Download',
          ),
          const SizedBox(width: 8),
          PlaylistActionButtonIcon(
            icon: Icons.share,
            onTap: () {
              if (Get.isRegistered<MainController>()) {
                Get.find<MainController>().sharePlaylist(
                  playlist.id,
                  playlist.playlistName,
                  thumbnailUrl: playlist.thumbnailUrl,
                );
              }
            },
            tooltip: 'Share',
          ),
        ] else ...[
          const SizedBox(width: 8),
          PlaylistActionButtonIcon(
            icon: Icons.share,
            onTap: () {
              if (Get.isRegistered<MainController>()) {
                Get.find<MainController>().sharePlaylist(
                  playlist.id,
                  playlist.playlistName,
                  thumbnailUrl: playlist.thumbnailUrl,
                );
              }
            },
            tooltip: 'Share',
          ),
        ],
      ],
    );
  }
}

/// Circular icon button for secondary playlist actions.
class PlaylistActionButtonIcon extends StatelessWidget {
  const PlaylistActionButtonIcon({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: ytSurfaceLight,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        type: MaterialType.circle,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Tooltip(
            message: tooltip,
            child: Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> playAllPlaylistVideos(PlaylistModel playlist) async {
  HapticFeedback.lightImpact();
  final videos = await fetchPlaylistVideos(playlist);
  if (videos.isNotEmpty) {
    MiniplayerNavigationHelper.navigateToVideoScreen(
      video: videos.first,
      routeArguments: {
        'video': videos.first,
        'playlist': playlist,
        'fromPlaylist': true,
        'isShuffled': false,
      },
    );
  }
}

Future<void> shufflePlaylistVideos(PlaylistModel playlist) async {
  HapticFeedback.lightImpact();
  final videos = await fetchPlaylistVideos(playlist);
  if (videos.isNotEmpty) {
    final randomIndex = DateTime.now().millisecondsSinceEpoch % videos.length;
    final video = videos[randomIndex];
    MiniplayerNavigationHelper.navigateToVideoScreen(
      video: video,
      routeArguments: {
        'video': video,
        'playlist': playlist,
        'fromPlaylist': true,
        'isShuffled': true,
      },
    );
  }
}
