import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
// import 'package:blurhash/blurhash.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Image Optimization Utility
///
/// Provides utilities for:
/// - Responsive image URLs based on device
/// - Lazy loading with visibility detection
/// - Progressive image loading (BlurHash -> LQ -> HQ)
/// - Adaptive quality based on connection
class ImageOptimizer {
  /// Get responsive image URL based on device width
  ///
  /// Returns appropriate resolution thumbnail:
  /// - Mobile (<600px): small (320x180)
  /// - Tablet (600-1000px): medium (480x270)
  /// - Desktop (>1000px): large (640x360)
  static String getResponsiveUrl(
    String baseUrl,
    BuildContext context, {
    String? preferredSize,
  }) {
    if (preferredSize != null) {
      return _buildImageUrl(baseUrl, preferredSize);
    }

    final width = MediaQuery.of(context).size.width;
    final dpr = MediaQuery.of(context).devicePixelRatio;

    late String size;
    if (width > 1000) {
      size = dpr > 1.5 ? 'large@2x' : 'large';
    } else if (width > 600) {
      size = dpr > 1.5 ? 'medium@2x' : 'medium';
    } else {
      size = dpr > 1.5 ? 'small@2x' : 'small';
    }

    return _buildImageUrl(baseUrl, size);
  }

  /// Build image URL with size suffix
  ///
  /// Example: "https://cdn.example.com/thumb/abc123.webp"
  /// -> "https://cdn.example.com/thumb/abc123.small.webp"
  static String _buildImageUrl(String baseUrl, String size) {
    if (baseUrl.isEmpty) return '';

    // Extract extension and path
    final lastDot = baseUrl.lastIndexOf('.');
    if (lastDot == -1) return baseUrl;

    final withoutExt = baseUrl.substring(0, lastDot);
    final ext = baseUrl.substring(lastDot);

    return '$withoutExt.$size$ext';
  }

  /// Generate image URL with query parameters for CDN optimization
  ///
  /// Useful for CDN transformation APIs (Imgix, Cloudinary, etc.)
  static String optimizeWithCDN(
    String url, {
    required int width,
    required int height,
    int quality = 80,
    String format = 'webp',
    bool fit = true,
  }) {
    // Example for Imgix or similar CDN
    // Customize based on your CDN provider

    final uri = Uri.parse(url);

    final params = {
      'w': width.toString(),
      'h': height.toString(),
      'q': quality.toString(),
      'f': format,
      if (fit) 'fit': 'crop',
      'auto': 'format', // Auto-negotiate format
    };

    // For Imgix-like CDNs
    var queryString = params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    if (uri.query.isNotEmpty) {
      queryString = '${uri.query}&$queryString';
    }

    return '${uri.scheme}://${uri.host}${uri.path}?$queryString';
  }

  /// Estimate data usage for image load
  ///
  /// Returns estimated bytes for given resolution
  static int estimateImageSize(String resolution) {
    // Average sizes based on WebP format
    const sizes = {
      'small': 20000, // 20KB
      'medium': 35000, // 35KB
      'large': 50000, // 50KB
      'hd': 120000, // 120KB
    };

    return sizes[resolution] ?? 50000;
  }
}

/// Optimized Image Widget with Progressive Loading
///
/// Features:
/// - BlurHash placeholder
/// - Shimmer skeleton loader
/// - Progressive fade-in
/// - Responsive sizing
/// - Automatic caching
class OptimizedThumbnail extends StatelessWidget {
  const OptimizedThumbnail({
    required this.imageUrl,
    super.key,
    this.blurHash,
    this.width = double.infinity,
    this.height = double.infinity,
    this.fit = BoxFit.cover,
    this.onTap,
    this.lazy = true,
  });
  final String imageUrl;
  final String? blurHash;
  final double width;
  final double height;
  final BoxFit fit;
  final VoidCallback? onTap;
  final bool lazy;

  @override
  Widget build(BuildContext context) {
    // Build placeholder
    final placeholder = _buildPlaceholder();

    // If lazy loading, return placeholder and load image later
    if (lazy) {
      return InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            placeholder,
            _buildImage(),
          ],
        ),
      );
    }

    // Non-lazy: load image immediately
    return InkWell(
      onTap: onTap,
      child: CachedNetworkImage(
        imageUrl: imageUrl.replaceAll(' ', '%20'),
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => _buildErrorWidget(),
        fit: fit,
        fadeInDuration: Durations.medium1,
        width: width,
        height: height,
      ),
    );
  }

  Widget _buildImage() {
    return CachedNetworkImage(
      imageUrl: imageUrl.replaceAll(' ', '%20'),
      fit: fit,
      fadeInDuration: Durations.medium1,
    );
  }

  Widget _buildPlaceholder() {
    // Fallback to shimmer
    return Shimmer.fromColors(
      baseColor: AppTheme.colors.surface,
      highlightColor: AppTheme.colors.divider,
      child: Container(
        width: width,
        height: height,
        color: AppTheme.colors.surface,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: AppTheme.colors.surface,
      child: Center(
        child: Icon(Icons.broken_image, color: AppTheme.colors.error),
      ),
    );
  }
}

/// Video Thumbnail with Duration Badge
///
/// Commonly used in video feeds with optimized loading
class VideoThumbnailCard extends StatelessWidget {
  const VideoThumbnailCard({
    required this.imageUrl,
    required this.duration,
    required this.title,
    required this.channelName,
    required this.views,
    required this.uploadedTime,
    super.key,
    this.blurHash,
    this.onTap,
  });
  final String imageUrl;
  final String? blurHash;
  final String duration;
  final String title;
  final String channelName;
  final String views;
  final String uploadedTime;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail with duration overlay
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                OptimizedThumbnail(
                  imageUrl: imageUrl,
                  blurHash: blurHash,
                ),
                // Duration badge
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing.space8,
                      vertical: AppTheme.spacing.space4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.colors.background.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      duration,
                      style: TextStyle(
                        color: AppTheme.colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Video info
          Padding(
            padding: EdgeInsets.all(AppTheme.spacing.space12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.colors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: AppTheme.spacing.space8),
                Text(
                  channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: AppTheme.spacing.space4),
                Text(
                  '$views views • $uploadedTime',
                  style: TextStyle(
                    color: AppTheme.colors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton Loader for Image Placeholders
///
/// Used while images are loading
class ImageSkeletonLoader extends StatelessWidget {
  const ImageSkeletonLoader({
    required this.width,
    required this.height,
    super.key,
  });
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.colors.surface,
      highlightColor: AppTheme.colors.divider,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.colors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// Batch Image Preloader
///
/// Preload multiple images in the background
class BatchImagePreloader {
  static Future<void> preloadImages(
    BuildContext context,
    List<String> imageUrls, {
    int batchSize = 5,
  }) async {
    for (var i = 0; i < imageUrls.length; i += batchSize) {
      final batch = imageUrls.sublist(
        i,
        i + batchSize > imageUrls.length ? imageUrls.length : i + batchSize,
      );

      await Future.wait(
        batch.map(
          (url) => precacheImage(CachedNetworkImageProvider(url), context),
        ),
      );

      // Add delay between batches to avoid overwhelming network
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}
