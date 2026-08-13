import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/core/widgets/clickable_url_text.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/theme/app_theme.dart';

class PlaylistCard extends StatelessWidget {
  const PlaylistCard({
    required this.playlist,
    super.key,
    this.onTap,
    this.onOptionsTap,
    this.aspectRatio = 16 / 9,
  });

  final PlaylistModel playlist;
  final VoidCallback? onTap;
  final VoidCallback? onOptionsTap;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final isPodcast = playlist.playlistName.toLowerCase().contains('podcast');

    return Semantics(
      button: true,
      enabled: true,
      label: 'Playlist: ${playlist.playlistName}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stacked Thumbnail Architecture (100% matching 2nd image)
          InkWell(
            onTap:
                onTap ??
                () {
                  Get.toNamed(
                    '/playlist-detail',
                    arguments: {'playlist': playlist},
                  );
                },
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Layer 2 (Bottom-most card edge peek)
                  Positioned(
                    top: -6,
                    left: 12,
                    right: 12,
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  // Layer 1 (Middle card edge peek)
                  Positioned(
                    top: -3,
                    left: 6,
                    right: 6,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(11),
                          topRight: Radius.circular(11),
                        ),
                      ),
                    ),
                  ),
                  // Main Front Thumbnail
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (playlist.thumbnailUrl.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: playlist.thumbnailUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: AppColors.bgSurface,
                                highlightColor: AppColors.bgSurfaceHover,
                                child: Container(color: AppColors.bgSurface),
                              ),
                              errorWidget: (context, url, error) =>
                                  const ColoredBox(
                                    color: AppColors.bgSurface,
                                    child: Center(
                                      child: Icon(
                                        Icons.playlist_play_rounded,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                            )
                          else
                            const ColoredBox(
                              color: AppColors.bgSurface,
                              child: Center(
                                child: Icon(
                                  Icons.playlist_play_rounded,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          // Subtle gradient overlay for contrast
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.5),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Bottom Right Badge (Matching 2nd Image: ((•)) Mix / Playlist count)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPodcast
                                        ? Icons.podcasts_rounded
                                        : Icons.sensors_rounded,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isPodcast
                                        ? 'Podcast'
                                        : '${playlist.videoCount} videos',
                                    style: GoogleFonts.roboto(
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Metadata below thumbnail (100% 2nd Image Layout: Title & Subtitle + vertical menu)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap:
                      onTap ??
                      () {
                        Get.toNamed(
                          '/playlist-detail',
                          arguments: {'playlist': playlist},
                        );
                      },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClickableUrlText(
                        text: playlist.playlistName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClickableUrlText(
                        text: playlist.description.isNotEmpty
                            ? playlist.description
                            : "${playlist.isPublic ? 'Public' : 'Private'} • Playlist",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onOptionsTap != null)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: onOptionsTap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
