import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Reusable responsive artwork container with specular glass bevel and soft studio shadow.
class AudioArtwork extends StatelessWidget {
  const AudioArtwork({
    required this.size,
    this.thumbnailUrl,
    this.borderRadius = 16.0,
    super.key,
  });

  final double size;
  final String? thumbnailUrl;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1.0),
        child: (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: thumbnailUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _buildFallback(),
                placeholder: (_, _) => _buildFallback(),
              )
            : _buildFallback(),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: const Color(0xFF161820),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white54,
          size: 32,
        ),
      ),
    );
  }
}
