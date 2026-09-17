import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/controllers/playlist_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Draggable bottom sheet for inspecting, reordering, and removing videos in a playlist.
void showManagePlaylistVideosSheet({
  required BuildContext context,
  required PlaylistModel playlist,
  required PlaylistController playlistController,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Manage Videos',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: FutureBuilder<List<Video>>(
                    future: playlistController.fetchVideos(playlist.videoIds),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Unable to load videos. Please try again.',
                            style: GoogleFonts.roboto(color: Colors.white),
                          ),
                        );
                      }
                      final videos = snapshot.data ?? [];
                      if (videos.isEmpty) {
                        return Center(
                          child: Text(
                            'No videos in this playlist',
                            style: GoogleFonts.roboto(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: videos.length,
                        itemBuilder: (context, index) {
                          final video = videos[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: video.thumbnailUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: video.thumbnailUrl,
                                      width: 80,
                                      height: 45,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) => Container(
                                        width: 80,
                                        height: 45,
                                        color: AppColors.bgSurfaceHover,
                                      ),
                                    )
                                  : Container(
                                      width: 80,
                                      height: 45,
                                      color: AppColors.bgSurfaceHover,
                                    ),
                            ),
                            title: Text(
                              video.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.roboto(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                playlistController.removeVideoFromPlaylist(
                                  playlist.id,
                                  video.id,
                                  playlist.isPublic,
                                );
                                Navigator.pop(context);
                                AppSnackbar.info(
                                  'Video removed from playlist',
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
