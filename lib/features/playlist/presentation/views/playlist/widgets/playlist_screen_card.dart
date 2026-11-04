import 'package:truthworld/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:truthworld/data/models/playlist_model.dart';

/// Modern, pixel-perfect playlist card matching TruthWorld's updated design architecture.
class PlaylistScreenCard extends StatelessWidget {
  const PlaylistScreenCard({
    required this.playlist,
    required this.onTap,
    required this.onOptionsTap,
    super.key,
  });

  final PlaylistModel playlist;
  final VoidCallback onTap;
  final VoidCallback onOptionsTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgPage,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF242424),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 16:9 Thumbnail Header with Badges
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (playlist.thumbnailUrl.trim().isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: playlist.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFF1A1A1A),
                        ),
                        errorWidget: (context, url, error) => _buildPlaceholder(),
                      )
                    else
                      _buildPlaceholder(),

                    // Subtle top-to-bottom vignette gradient for badge legibility
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.3),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Top-right lock/globe privacy icon badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            playlist.isPublic
                                ? Icons.public_rounded
                                : Icons.lock_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                        ),
                      ),
                    ),

                    // Bottom-right video count badge
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
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
                              () {
                                final count = playlist.effectiveVideoCount;
                                return '$count ${count == 1 ? "video" : "videos"}';
                              }(),
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
              ),
            ),
            const SizedBox(height: 8),

            // Metadata: Title and Options Menu Row
            Row(
              children: [
                Expanded(
                  child: Text(
                    playlist.playlistName.isNotEmpty
                        ? playlist.playlistName
                        : 'Untitled Playlist',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: onOptionsTap,
                  borderRadius: BorderRadius.circular(14),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),

            // Relative Update Time
            Text(
              'Updated ${timeago.format(playlist.updatedAt.toDate())}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: const Color(0xFF8E8E93),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const ColoredBox(
      color: AppColors.bgSurface,
      child: Center(
        child: Icon(
          Icons.playlist_play_rounded,
          color: Colors.white54,
          size: 36,
        ),
      ),
    );
  }
}
