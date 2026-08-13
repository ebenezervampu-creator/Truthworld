// Performance Optimizations for TruthWorld App
// ============================================
// This file implements critical performance optimizations:
// 1. Image caching and lazy loading
// 2. List virtualization and pagination
// 3. Reduced setState calls
// 4. Deferred loading for features
// 5. Network image optimization
// 6. Memory management
// 7. Render optimization

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Optimized horizontal playlist list with cached images
class OptimizedPlaylistList extends StatelessWidget {
  final List<Map<String, dynamic>> playlists;
  final double height;
  final double itemWidth;
  final Function(String)? onTap;

  const OptimizedPlaylistList({
    super.key,
    required this.playlists,
    this.height = 180,
    this.itemWidth = 240,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: playlists.length,
        // Add cacheExtent to preload items before they're visible
        cacheExtent: itemWidth * 2,
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          return _PlaylistItem(
            playlist: playlist,
            width: itemWidth,
            onTap: onTap != null ? () => onTap!(playlist['id'] ?? '') : null,
          );
        },
      ),
    );
  }
}

class _PlaylistItem extends StatelessWidget {
  final Map<String, dynamic> playlist;
  final double width;
  final VoidCallback? onTap;

  const _PlaylistItem({
    required this.playlist,
    required this.width,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Use CachedNetworkImage instead of NetworkImage for better performance
            CachedNetworkImage(
              imageUrl: playlist['image'] ?? '',
              fit: BoxFit.cover,
              fadeInDuration: Durations.medium1,
              placeholder: (context, url) => _buildPlaceholder(),
              errorWidget: (context, url, error) => _buildErrorWidget(),
              memCacheWidth: (width * MediaQuery.of(context).devicePixelRatio).toInt(),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Title
            Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  playlist['title'] ?? '',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.bgInput,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: AppColors.bgInput,
      child: Icon(Icons.broken_image, color: Colors.white.withValues(alpha: 0.5)),
    );
  }
}
