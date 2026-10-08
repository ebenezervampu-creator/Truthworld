import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Accessible image wrapper with mandatory semantic description.
///
/// WCAG 2.1 SC 1.1.1 (Level A): All non-text content must have a text
/// alternative that serves the equivalent purpose.
///
/// Usage:
/// ```dart
/// AccessibleImage.network(
///   url: video.thumbnailUrl,
///   semanticLabel: '${video.title} thumbnail',
///   width: 160,
///   height: 90,
/// )
/// ```
class AccessibleImage extends StatelessWidget {
  /// Network image with semantic label (most common use case)
  const AccessibleImage.network({
    required this.url,
    required this.semanticLabel,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.isDecorative = false,
    super.key,
  }) : assetPath = null,
       imageProvider = null;

  /// Asset image with semantic label
  const AccessibleImage.asset({
    required this.assetPath,
    required this.semanticLabel,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.isDecorative = false,
    super.key,
  }) : url = null,
       placeholder = null,
       errorWidget = null,
       imageProvider = null;

  /// Generic image provider with semantic label
  const AccessibleImage.provider({
    required this.imageProvider,
    required this.semanticLabel,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.isDecorative = false,
    super.key,
  }) : url = null,
       assetPath = null,
       placeholder = null,
       errorWidget = null;

  final String? url;
  final String? assetPath;
  final ImageProvider? imageProvider;

  /// Screen reader description. REQUIRED.
  /// Use descriptive text like "Video thumbnail showing a sunset over mountains".
  /// For decorative images, set [isDecorative] = true instead.
  final String semanticLabel;

  /// If true, the image is decorative and will be hidden from screen readers.
  /// Use for background patterns, dividers, and purely aesthetic images.
  final bool isDecorative;

  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;

  @override
  Widget build(BuildContext context) {
    Widget image;

    if (url != null && url!.isNotEmpty) {
      image = CachedNetworkImage(
        imageUrl: url!,
        width: width,
        height: height,
        fit: fit,
        placeholder: placeholder,
        errorWidget: errorWidget ?? _defaultErrorWidget,
      );
    } else if (assetPath != null) {
      image = Image.asset(
        assetPath!,
        width: width,
        height: height,
        fit: fit,
        semanticLabel: isDecorative ? null : semanticLabel,
      );
    } else if (imageProvider != null) {
      image = Image(
        image: imageProvider!,
        width: width,
        height: height,
        fit: fit,
        semanticLabel: isDecorative ? null : semanticLabel,
      );
    } else {
      image = SizedBox(width: width, height: height);
    }

    // Wrap with semantics
    final Widget semanticImage = isDecorative
        ? ExcludeSemantics(child: image)
        : Semantics(
            label: semanticLabel,
            image: true,
            child: image,
          );

    // Apply border radius if specified
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: semanticImage,
      );
    }

    return semanticImage;
  }

  static Widget _defaultErrorWidget(
    BuildContext context,
    String url,
    Object error,
  ) {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
      ),
    );
  }
}
