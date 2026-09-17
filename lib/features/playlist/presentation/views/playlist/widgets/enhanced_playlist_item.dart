import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/playlist_options_sheet.dart';
import 'package:truthworld/features/playlist/presentation/views/playlist/widgets/stacked_thumbnail.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive card component representing a playlist in either grid or list mode.
class EnhancedPlaylistItem extends StatelessWidget {
  EnhancedPlaylistItem({
    required this.playlist,
    required this.index,
    required this.isGridView,
    this.videoId,
    super.key,
  });

  final PlaylistModel playlist;
  final String? videoId;
  final int index;
  final bool isGridView;
  final RxBool _isHovered = false.obs;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _isHovered.value = true,
      onExit: (_) => _isHovered.value = false,
      child: Obx(
        () => AnimatedScale(
          scale: _isHovered.value ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Container(
            margin: EdgeInsets.only(bottom: isGridView ? 0 : 16),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _isHovered.value ? 0.2 : 0.08,
                  ),
                  blurRadius: _isHovered.value ? 16 : 8,
                  offset: Offset(0, _isHovered.value ? 6 : 3),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                final firstVideoId = playlist.videoIds.isNotEmpty
                    ? playlist.videoIds.first
                    : '';
                Get.toNamed(
                  '/watch?v=$firstVideoId',
                  arguments: {'playlist': playlist},
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: isGridView
                    ? _buildGridContent(context)
                    : _buildListContent(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModerationStatusBadge(String status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'active':
        return const SizedBox.shrink();
      case 'verificationRejected':
        color = AppColors.error;
        icon = Icons.error_outline_rounded;
        label = 'Rejected';
      case 'underReview':
      default:
        color = AppColors.warning;
        icon = Icons.hourglass_empty_rounded;
        label = 'Under Review';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridContent(BuildContext context) {
    final status = playlist.status;
    final isPodcast = playlist.playlistName.toLowerCase().contains('podcast');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stacked Thumbnail Effect
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              Positioned.fill(
                child: StackedThumbnail(
                  thumbnailUrl: playlist.thumbnailUrl,
                  videoCount: playlist.videoCount,
                  isPodcast: isPodcast,
                ),
              ),
              if (status != 'active')
                Positioned(
                  top: 8,
                  left: 8,
                  child: _buildModerationStatusBadge(status),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => showPlaylistOptionsSheet(
                    context: context,
                    playlist: playlist,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Playlist metadata
        Text(
          playlist.playlistName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "${playlist.isPublic ? 'Public' : 'Private'} • ${isPodcast ? 'Podcast' : 'Playlist'}",
          style: GoogleFonts.roboto(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          TimestampUtils.formatRelativeTime(
            playlist.updatedAt.toDate(),
            prefix: 'Updated',
          ),
          style: GoogleFonts.roboto(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () {
            final firstVideoId =
                playlist.videoIds.isNotEmpty ? playlist.videoIds.first : '';
            Get.toNamed(
              '/watch?v=$firstVideoId',
              arguments: {'playlist': playlist},
            );
          },
          child: Text(
            "View full ${isPodcast ? 'podcast' : 'playlist'}",
            style: GoogleFonts.roboto(
              fontSize: 13,
              color: AppColors.textLink,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListContent(BuildContext context) {
    final status = playlist.status;

    return Row(
      children: [
        // Playlist thumbnail
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.bgSurfaceHover,
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(
              image: CachedNetworkImageProvider(playlist.thumbnailUrl),
              fit: BoxFit.cover,
              onError: (_, _) {},
            ),
          ),
          child: Stack(
            children: [
              // Dark overlay for contrast
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                ),
              ),
              // Video count badge
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.playlist_play_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${playlist.videoCount}',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Privacy indicator
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    playlist.isPublic
                        ? Icons.public_rounded
                        : Icons.lock_outline_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Playlist info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                playlist.playlistName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${playlist.videoCount} videos',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (status != 'active') ...[
                    const SizedBox(width: 8),
                    _buildModerationStatusBadge(status),
                  ],
                ],
              ),
            ],
          ),
        ),

        // More options
        IconButton(
          icon: const Icon(
            Icons.more_vert_rounded,
            color: Colors.white,
          ),
          onPressed: () => showPlaylistOptionsSheet(
            context: context,
            playlist: playlist,
          ),
        ),
      ],
    );
  }
}
