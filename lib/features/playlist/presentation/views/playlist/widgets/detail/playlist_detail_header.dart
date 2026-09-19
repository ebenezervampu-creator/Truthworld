import 'package:flutter/material.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/detail/playlist_action_buttons.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/detail/playlist_channel_header_info.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/detail/playlist_detail_constants.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/detail/playlist_thumbnail_widget.dart';

/// Mobile & tablet header section for the playlist detail screen.
class PlaylistDetailHeader extends StatelessWidget {
  const PlaylistDetailHeader({
    required this.playlist,
    super.key,
    this.isTablet = false,
  });

  final PlaylistModel playlist;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isTablet ? 24.0 : 16.0;

    return Container(
      padding: EdgeInsets.all(horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              PlaylistThumbnailWidget(playlist: playlist, isTablet: isTablet),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.playlistName,
                      style: TextStyle(
                        fontSize: isTablet ? 22 : 18,
                        fontWeight: FontWeight.w700,
                        color: ytTextPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    PlaylistChannelInfoWidget(playlist: playlist),
                    const SizedBox(height: 8),
                    PlaylistStatsWidget(playlist: playlist),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PlaylistActionButtons(playlist: playlist, isTablet: isTablet),
        ],
      ),
    );
  }
}

/// Desktop sidebar section displaying playlist metadata, large thumbnail, channel info, and action buttons.
class PlaylistDetailSidebar extends StatelessWidget {
  const PlaylistDetailSidebar({
    required this.playlist,
    super.key,
    this.isDesktop = false,
  });

  final PlaylistModel playlist;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large thumbnail
          PlaylistThumbnailWidget(playlist: playlist, isLarge: true),
          const SizedBox(height: 20),
          // Playlist title
          Text(
            playlist.playlistName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: ytTextPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Channel name with avatar
          PlaylistChannelInfoWidget(playlist: playlist),
          const SizedBox(height: 12),
          // Stats
          PlaylistStatsWidget(playlist: playlist),
          const SizedBox(height: 24),
          // Action buttons
          PlaylistActionButtons(playlist: playlist, isDesktop: true),
          const SizedBox(height: 16),
          // Description
          if (playlist.description.isNotEmpty)
            PlaylistDescriptionWidget(description: playlist.description),
        ],
      ),
    );
  }
}

/// Expandable playlist description block.
class PlaylistDescriptionWidget extends StatelessWidget {
  const PlaylistDescriptionWidget({
    required this.description,
    super.key,
  });

  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          style: const TextStyle(
            fontSize: 14,
            color: ytTextSecondary,
            height: 1.4,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        if (description.length > 100)
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Show more',
              style: TextStyle(
                fontSize: 12,
                color: ytTextPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
