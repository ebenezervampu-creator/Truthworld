import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Optimized Network Image Widget
/// 
/// Performance benefits:
/// - Automatic memory and disk caching
/// - Progressive loading with placeholder
/// - Reduced memory usage with memCacheWidth/Height
/// - Fade-in animation for smooth UX
/// - Error handling with retry capability
class OptimizedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? backgroundColor;
  final double borderRadius;
  final bool fadeIn;
  
  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.backgroundColor,
    this.borderRadius = 0,
    this.fadeIn = true,
  });

  @override
  State<OptimizedNetworkImage> createState() => _OptimizedNetworkImageState();
}

class _OptimizedNetworkImageState extends State<OptimizedNetworkImage> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: CachedNetworkImage(
        imageUrl: widget.imageUrl.replaceAll(' ', '%20'),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        fadeInDuration: widget.fadeIn ? Durations.medium1 : Duration.zero,
        fadeOutDuration: Durations.short1,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildErrorWidget(),
        // Memory cache optimization - resize to widget dimensions
        memCacheWidth: widget.width != null 
            ? (widget.width! * MediaQuery.of(context).devicePixelRatio).toInt()
            : null,
        memCacheHeight: widget.height != null
            ? (widget.height! * MediaQuery.of(context).devicePixelRatio).toInt()
            : null,
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.backgroundColor ?? AppColors.bgInput,
      child: Shimmer.fromColors(
        baseColor: AppColors.bgInput,
        highlightColor: AppColors.bgPage.withOpacity(0.1),
        child: Container(
          color: Colors.white,
          child: widget.width == null && widget.height == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : null,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.backgroundColor ?? AppColors.bgInput,
      child: Icon(
        Icons.broken_image,
        color: AppColors.textTertiary,
        size: widget.width != null ? widget.width! * 0.3 : 48,
      ),
    );
  }
}

/// Avatar-specific optimized image with circular clipping
class OptimizedAvatar extends StatelessWidget {
  final String imageUrl;
  final double size;
  final Color? backgroundColor;
  
  const OptimizedAvatar({
    super.key,
    required this.imageUrl,
    this.size = 40,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: OptimizedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        backgroundColor: backgroundColor,
        fadeIn: false, // Avatars should load instantly from cache
      ),
    );
  }
}

/// Thumbnail-specific optimized image with aspect ratio
class OptimizedThumbnail extends StatelessWidget {
  final String imageUrl;
  final double aspectRatio;
  final double width;
  final double borderRadius;
  
  const OptimizedThumbnail({
    super.key,
    required this.imageUrl,
    this.aspectRatio = 16/9,
    required this.width,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: OptimizedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: width / aspectRatio,
        fit: BoxFit.cover,
        borderRadius: borderRadius,
      ),
    );
  }
}
