import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'components/home_theme.dart';

/// Optimized thumbnail preloading service
/// Manages image caching strategy for better scroll performance
class ThumbnailPreloader {
  static final ThumbnailPreloader _instance = ThumbnailPreloader._internal();
  factory ThumbnailPreloader() => _instance;
  ThumbnailPreloader._internal();

  // LRU cache for tracking preload priority
  final List<String> _recentlyAccessed = [];
  static const int maxCacheSize = 20;

  /// Preload a single image
  void preload(String imageUrl, BuildContext context) {
    if (imageUrl.isEmpty) return;
    
    // Add to recently accessed for LRU tracking
    _addToRecentlyAccessed(imageUrl);
    
    // Use Flutter's built-in precache
    precacheImage(CachedNetworkImageProvider(imageUrl), context);
  }

  /// Preload multiple images ahead of current position
  void preloadAhead(List<String> imageUrls, BuildContext context, int startIndex, int count) {
    final endIndex = (startIndex + count).clamp(0, imageUrls.length - 1);
    
    for (int i = startIndex; i <= endIndex && i < imageUrls.length; i++) {
      if (imageUrls[i].isNotEmpty) {
        preload(imageUrls[i], context);
      }
    }
  }

  /// Prefetch next N thumbnails in a list
  Future<void> prefetchNext({
    required List<String> imageUrls,
    required BuildContext context,
    required int currentIndex,
    int aheadCount = 3,
  }) async {
    final startIndex = currentIndex + 1;
    final endIndex = (currentIndex + aheadCount).clamp(0, imageUrls.length - 1);
    
    for (int i = startIndex; i <= endIndex && i < imageUrls.length; i++) {
      if (imageUrls[i].isNotEmpty) {
        await precacheImage(CachedNetworkImageProvider(imageUrls[i]), context);
      }
    }
  }

  void _addToRecentlyAccessed(String url) {
    _recentlyAccessed.remove(url);
    _recentlyAccessed.add(url);
    
    // Maintain LRU size
    if (_recentlyAccessed.length > maxCacheSize) {
      _recentlyAccessed.removeAt(0);
    }
  }

  /// Clear cached images that are not recently accessed
  void clearOldCache() {
    // Flutter's image cache is automatically managed
    // This method is for potential future manual cache management
    _recentlyAccessed.clear();
  }

  /// Get cache statistics for monitoring
  Map<String, dynamic> getStats() {
    return {
      'recently_accessed_count': _recentlyAccessed.length,
      'max_cache_size': maxCacheSize,
    };
  }
}

/// Widget for optimized image loading with automatic preloading
class OptimizedThumbnail extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final Widget Function(BuildContext, String)? placeholderBuilder;
  final Widget Function(BuildContext, String, Object)? errorBuilder;

  const OptimizedThumbnail({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.placeholderBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // Trigger preload when widget is built
    ThumbnailPreloader().preload(imageUrl, context);

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: (width * 2).toInt(),
        memCacheHeight: (height * 2).toInt(),
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 200),
        placeholder: (context, url) => 
            placeholderBuilder?.call(context, url) ?? _defaultPlaceholder(context),
        errorWidget: (context, url, error) => 
            errorBuilder?.call(context, url, error) ?? _defaultErrorWidget(context),
      ),
    );
  }

  Widget _defaultPlaceholder(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: HomeTheme.darkSurfaceVariant.withOpacity(0.3),
      highlightColor: HomeTheme.darkSurfaceVariant.withOpacity(0.1),
      child: Container(
        width: width,
        height: height,
        color: HomeTheme.darkSurfaceVariant,
      ),
    );
  }

  Widget _defaultErrorWidget(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: HomeTheme.darkSurfaceVariant,
      child: Icon(
        Icons.broken_image,
        color: HomeTheme.darkOnSurfaceVariant,
        size: 32,
      ),
    );
  }
}
