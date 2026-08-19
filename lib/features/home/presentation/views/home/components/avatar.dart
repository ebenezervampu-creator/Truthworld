import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:truthworld/features/home/presentation/views/home/components/home_theme.dart';

/// Reusable Avatar component extracted from home.dart
class Avatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? placeholderText;
  final bool showBorder;

  const Avatar({
    required this.radius, super.key,
    this.imageUrl,
    this.placeholderText,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      decoration: showBorder
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: HomeTheme.primaryAccent.withValues(alpha: 0.2),
              ),
            )
          : null,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: HomeTheme.darkSurfaceVariant.withValues(alpha: 0.3),
        child: ClipOval(
          child: _buildImage(hasImage, context),
        ),
      ),
    );
  }

  Widget _buildImage(bool hasImage, BuildContext context) {
    if (!hasImage) {
      return _buildPlaceholder();
    }

    if (kIsWeb) {
      return Image.network(
        imageUrl!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      memCacheWidth:
          (radius * 2 * MediaQuery.of(context).devicePixelRatio).toInt(),
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Text(
        placeholderText ?? '?',
        style: GoogleFonts.roboto(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
