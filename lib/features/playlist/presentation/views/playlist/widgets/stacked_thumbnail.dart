import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Layered stacked thumbnail representation for playlists and podcasts.
class StackedThumbnail extends StatelessWidget {
  const StackedThumbnail({
    required this.thumbnailUrl,
    required this.videoCount,
    super.key,
    this.isPodcast = false,
  });

  final String thumbnailUrl;
  final int videoCount;
  final bool isPodcast;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Bottom-most layer
            Positioned(
              top: -8,
              left: width * 0.08,
              right: width * 0.08,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            // Middle layer
            Positioned(
              top: -4,
              left: width * 0.04,
              right: width * 0.04,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            // Main layer (top)
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Thumbnail
                    CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      width: width,
                      height: height,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const ColoredBox(
                        color: AppColors.bgSurfaceHover,
                        child: Center(
                          child: Icon(Icons.image, color: Colors.white24),
                        ),
                      ),
                      errorWidget: (context, url, error) => const ColoredBox(
                        color: AppColors.bgSurfaceHover,
                        child: Center(
                          child: Icon(Icons.error, color: Colors.white24),
                        ),
                      ),
                    ),
                    // Overlay for contrast
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                    // Badge (Bottom Right)
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
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPodcast
                                  ? Icons.podcasts_rounded
                                  : Icons.playlist_play_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "$videoCount ${isPodcast ? 'episodes' : 'videos'}",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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
        );
      },
    );
  }
}
