import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? displayName;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final Color? borderColor;
  final bool showBorder;

  const UserAvatar({
    super.key,
    this.photoUrl,
    this.displayName,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.borderColor,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackgroundColor = backgroundColor ?? theme.colorScheme.primary.withValues(alpha: 0.1);
    final effectiveTextColor = textColor ?? theme.colorScheme.primary;
    final effectiveFontSize = fontSize ?? (radius * 0.8);

    final String initial = displayName?.isNotEmpty == true
        ? displayName![0].toUpperCase()
        : 'U';

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: effectiveBackgroundColor,
        border: showBorder
            ? Border.all(
                color: borderColor ?? theme.colorScheme.primary.withValues(alpha: 0.2),
                width: 0.5,
              )
            : null,
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                memCacheWidth: (radius * 2 * MediaQuery.of(context).devicePixelRatio).toInt(),
                memCacheHeight: (radius * 2 * MediaQuery.of(context).devicePixelRatio).toInt(),
                placeholder: (context, url) => _buildPlaceholder(initial, effectiveTextColor, effectiveFontSize),
                errorWidget: (context, url, error) => _buildPlaceholder(initial, effectiveTextColor, effectiveFontSize),
              )
            : _buildPlaceholder(initial, effectiveTextColor, effectiveFontSize),
      ),
    );
  }

  Widget _buildPlaceholder(String initial, Color textColor, double fontSize) {
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.roboto(
          textStyle: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }
}





