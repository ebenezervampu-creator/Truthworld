import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:truthworld/core/services/auth_service.dart';

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

    String? effectivePhotoUrl = photoUrl;
    String? effectiveDisplayName = displayName;

    try {
      if (Get.isRegistered<AuthService>()) {
        final authService = AuthService.to;
        final currentUser = FirebaseAuth.instance.currentUser;
        if (authService.hasChannel.value && authService.userChannel != null && currentUser != null) {
          final userPhoto = currentUser.photoURL;
          final userName = currentUser.displayName;

          final isCurrentUserDetails = (photoUrl == userPhoto) ||
                                       (displayName == userName) ||
                                       (displayName == 'User') ||
                                       (displayName == 'Anonymous User') ||
                                       (photoUrl == null && displayName == null);

          if (isCurrentUserDetails) {
            effectivePhotoUrl = authService.userChannel!.avatarUrl;
            effectiveDisplayName = authService.userChannel!.name;
          }
        }
      }
    } catch (_) {}

    final String initial = effectiveDisplayName?.isNotEmpty == true
        ? effectiveDisplayName![0].toUpperCase()
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
        child: effectivePhotoUrl != null && effectivePhotoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: effectivePhotoUrl,
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





