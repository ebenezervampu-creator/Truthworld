import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Helper to extract initials (e.g. 'EV' for 'Ebenezer Vampu', 'T' for 'TruthWorld').
String _extractInitials(String? text) {
  if (text == null || text.trim().isEmpty) return '?';
  final trimmed = text.trim();
  final words = trimmed.split(RegExp(r'\s+'));
  if (words.length >= 2) {
    final first = words[0].isNotEmpty ? words[0][0] : '';
    final second = words[1].isNotEmpty ? words[1][0] : '';
    return '$first$second'.toUpperCase();
  }
  return trimmed.substring(0, 1).toUpperCase();
}

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
    final cleanUrl = imageUrl?.trim() ?? '';
    final hasImage = cleanUrl.isNotEmpty;
    final initials = _extractInitials(placeholderText);

    if (!hasImage) {
      return SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: ClipOval(
          child: _buildPlaceholder(initials),
        ),
      );
    }

    final formattedUrl = cleanUrl.replaceAll(' ', '%20');

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: formattedUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          memCacheWidth: kIsWeb
              ? null
              : (radius * 2 * MediaQuery.of(context).devicePixelRatio).toInt(),
          memCacheHeight: kIsWeb
              ? null
              : (radius * 2 * MediaQuery.of(context).devicePixelRatio).toInt(),
          placeholder: (context, url) => _buildPlaceholder(initials),
          errorWidget: (context, url, error) {
            if (kIsWeb) {
              return Image.network(
                formattedUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (context, err, stack) =>
                    _buildPlaceholder(initials),
              );
            }
            return _buildPlaceholder(initials);
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String initials) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      color: const Color(0xFF141416),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: initials.length > 1 ? radius * 0.72 : radius * 0.9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Backward compatibility alias
typedef ModernAvatar = VideoCardAvatar;
