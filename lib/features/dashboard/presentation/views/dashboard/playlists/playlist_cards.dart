import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/core/utils/playlist_navigation.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/playlists_management_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/dialogs/delete_playlist_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/dialogs/edit_playlist_dialog.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/playlists/dialogs/manage_playlist_videos_modal.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Default 16:9 placeholder thumbnail for playlists.
class PlaylistDefaultThumbnail extends StatelessWidget {
  const PlaylistDefaultThumbnail({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF1F1F23),
      child: Center(
        child: Icon(
          Icons.playlist_play_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }
}

/// Action menu dropdown for playlists.
class PlaylistMenuButton extends StatelessWidget {
  const PlaylistMenuButton({
    required this.playlist,
    required this.channelId,
    super.key,
  });

  final PlaylistModel playlist;
  final String channelId;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlaylistsManagementController>();

    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert_rounded,
        color: Colors.white,
        size: 18,
      ),
      color: const Color(0xFF1C1C20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF27272A)),
      ),
      onSelected: (action) {
        if (action == 'view') {
          PlaylistNavigation.openPlaylistDetail(playlist);
        } else if (action == 'manage') {
          ManagePlaylistVideosModal.show(
            context,
            playlist: playlist,
            channelId: channelId,
          );
        } else if (action == 'edit') {
          EditPlaylistDialog.show(context, playlist: playlist);
        } else if (action == 'copy') {
          controller.copyPlaylistLink(playlist);
        } else if (action == 'delete') {
          DeletePlaylistConfirmationDialog.show(context, playlist: playlist);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: 10),
              Text(
                'Play & View',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'manage',
          child: Row(
            children: [
              Icon(
                Icons.video_collection_outlined,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: 10),
              Text(
                'Manage & Reorder Videos',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: 10),
              Text(
                'Edit Metadata',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(
                Icons.link_rounded,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: 10),
              Text(
                'Copy Share Link',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: 10),
              Text(
                'Delete Playlist',
                style: TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Grid card presentation for a single playlist.
class PlaylistGridCard extends StatelessWidget {
  const PlaylistGridCard({
    required this.playlist,
    required this.channelId,
    super.key,
  });

  final PlaylistModel playlist;
  final String channelId;

  @override
  Widget build(BuildContext context) {
    final visibilityColor = playlist.visibility == PlaylistVisibility.public
        ? Colors.green
        : (playlist.visibility == PlaylistVisibility.unlisted
            ? Colors.amber
            : const Color(0xFF94A3B8));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail Header with Badge & Hover Overlay
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: playlist.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: playlist.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            const PlaylistDefaultThumbnail(),
                      )
                    : const PlaylistDefaultThumbnail(),
              ),
              // Video Count Pill Overlay
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.playlist_play_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${playlist.videoCount} videos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Visibility Pill Overlay
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: visibilityColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        playlist.visibility == PlaylistVisibility.public
                            ? Icons.public_rounded
                            : (playlist.visibility ==
                                    PlaylistVisibility.unlisted
                                ? Icons.link_rounded
                                : Icons.lock_outline_rounded),
                        color: Colors.white,
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        playlist.visibility.name.toUpperCase(),
                        style: TextStyle(
                          color: visibilityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Metadata & Controls
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          playlist.name.isNotEmpty
                              ? playlist.name
                              : 'Untitled Playlist',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PlaylistMenuButton(
                        playlist: playlist,
                        channelId: channelId,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playlist.description.isNotEmpty
                        ? playlist.description
                        : 'No description provided.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  const Divider(height: 12, color: Color(0xFF27272A)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Updated ${timeago.format(playlist.updatedAt.toDate())}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      InkWell(
                        onTap: () => ManagePlaylistVideosModal.show(
                          context,
                          playlist: playlist,
                          channelId: channelId,
                        ),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.video_collection_outlined,
                                color: Colors.white,
                                size: 13,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Manage',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// List row presentation for a single playlist.
class PlaylistListCard extends StatelessWidget {
  const PlaylistListCard({
    required this.playlist,
    required this.channelId,
    super.key,
  });

  final PlaylistModel playlist;
  final String channelId;

  @override
  Widget build(BuildContext context) {
    final visibilityColor = playlist.visibility == PlaylistVisibility.public
        ? Colors.green
        : (playlist.visibility == PlaylistVisibility.unlisted
            ? Colors.amber
            : const Color(0xFF94A3B8));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // 16:9 Thumbnail Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 140,
              height: 80,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (playlist.thumbnailUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: playlist.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) =>
                          const PlaylistDefaultThumbnail(),
                    )
                  else
                    const PlaylistDefaultThumbnail(),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${playlist.videoCount} videos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Metadata Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        playlist.name.isNotEmpty
                            ? playlist.name
                            : 'Untitled Playlist',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: visibilityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: visibilityColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        playlist.visibility.name.toUpperCase(),
                        style: TextStyle(
                          color: visibilityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  playlist.description.isNotEmpty
                        ? playlist.description
                        : 'No description provided.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  'Updated ${timeago.format(playlist.updatedAt.toDate())}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Action Buttons
          OutlinedButton.icon(
            onPressed: () => ManagePlaylistVideosModal.show(
              context,
              playlist: playlist,
              channelId: channelId,
            ),
            icon: const Icon(
              Icons.video_collection_outlined,
              size: 14,
              color: Colors.white,
            ),
            label: const Text(
              'Manage Videos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E22),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF27272A)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PlaylistMenuButton(
            playlist: playlist,
            channelId: channelId,
          ),
        ],
      ),
    );
  }
}
