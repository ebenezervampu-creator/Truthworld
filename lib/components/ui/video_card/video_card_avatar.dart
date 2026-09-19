import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Reusable Modern Avatar Widget matching the Truthworld design language.
class VideoCardAvatar extends StatelessWidget {
  const VideoCardAvatar({
    required this.radius,
    super.key,
    this.imageUrl,
    this.placeholderText,
  });

  final String? imageUrl;
  final double radius;
  final String? placeholderText;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child: hasImage
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  memCacheWidth:
                      (radius * 2 * MediaQuery.of(context).devicePixelRatio)
                          .toInt(),
                  placeholder: (context, url) => _buildPlaceholder(theme),
                  errorWidget: (context, url, error) => _buildPlaceholder(theme),
                )
              : _buildPlaceholder(theme),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          (placeholderText != null && placeholderText!.isNotEmpty)
              ? placeholderText![0].toUpperCase()
              : '?',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: radius * 0.9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Backward compatibility alias
typedef ModernAvatar = VideoCardAvatar;
