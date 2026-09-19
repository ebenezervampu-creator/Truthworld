import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/miniplayer/presentation/utils/miniplayer_utils.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/detail/playlist_detail_constants.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/detail/playlist_video_options_bottom_sheet.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Single row item representing a video in the playlist with thumbnail, metadata, and options.
class PlaylistVideoListItem extends StatelessWidget {
  const PlaylistVideoListItem({
    required this.index,
    required this.video,
    super.key,
    this.playlist,
    this.isDesktop = false,
    this.isTablet = false,
  });

  final int index;
  final Video video;
  final PlaylistModel? playlist;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final thumbnailWidth = isDesktop ? 160.0 : (isTablet ? 200.0 : 140.0);

    return InkWell(
      onTap: () {
        MiniplayerNavigationHelper.navigateToVideoScreen(
          video: video,
          routeArguments: {
            'video': video,
            'playlist': playlist,
            'fromPlaylist': true,
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with Duration Overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    width: thumbnailWidth,
                    height: thumbnailWidth * 9 / 16,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: thumbnailWidth,
                      height: thumbnailWidth * 9 / 16,
                      color: ytSurfaceLight,
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: thumbnailWidth,
                      height: thumbnailWidth * 9 / 16,
                      color: ytSurfaceLight,
                      child: const Icon(
                        Icons.play_circle_outline,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
                // Duration overlay
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgPage.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.duration,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Details (Title & Metadata)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: ytTextPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: () => showPlaylistVideoOptions(context, video),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${video.channelName} • ${formatPlaylistViews(video.views)} views',
                    style: const TextStyle(
                      fontSize: 13,
                      color: ytTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
