import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/auth_service.dart';

class UserAvatar extends StatelessWidget {
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
  final String? photoUrl;
  final String? displayName;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final Color? borderColor;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackgroundColor =
        backgroundColor ?? theme.colorScheme.primary.withValues(alpha: 0.1);
    final effectiveTextColor = textColor ?? theme.colorScheme.primary;
    final effectiveFontSize = fontSize ?? (radius * 0.8);

    var effectivePhotoUrl = photoUrl;
    var effectiveDisplayName = displayName;

    try {
      if (Get.isRegistered<AuthService>()) {
        final authService = AuthService.to;
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final userPhoto = currentUser.photoURL;
          final userName = currentUser.displayName;

          final isCurrentUserDetails =
              (photoUrl == userPhoto) ||
              (displayName == userName) ||
              (displayName == 'User') ||
              (displayName == 'Anonymous User') ||
              (photoUrl == null && displayName == null);

          if (isCurrentUserDetails) {
            if (authService.activePhotoUrl.isNotEmpty) {
              effectivePhotoUrl = authService.activePhotoUrl;
            }
            if (authService.activeDisplayName.isNotEmpty) {
              effectiveDisplayName = authService.activeDisplayName;
            }
          }
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'UserAvatar.resolveCurrentUserDetails',
      );
    }

    final initial = (effectiveDisplayName != null &&
            effectiveDisplayName.isNotEmpty &&
            effectiveDisplayName != 'User' &&
            effectiveDisplayName != 'Anonymous User')
        ? effectiveDisplayName[0].toUpperCase()
        : '';

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: effectiveBackgroundColor,
        border: showBorder
            ? Border.all(
                color:
                    borderColor ??
                    theme.colorScheme.primary.withValues(alpha: 0.2),
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
                memCacheWidth:
                    (radius * 2 * MediaQuery.of(context).devicePixelRatio)
                        .toInt(),
                memCacheHeight:
                    (radius * 2 * MediaQuery.of(context).devicePixelRatio)
                        .toInt(),
                placeholder: (context, url) => _buildPlaceholder(
                  initial,
                  effectiveTextColor,
                  effectiveFontSize,
                ),
                errorWidget: (context, url, error) => _buildPlaceholder(
                  initial,
                  effectiveTextColor,
                  effectiveFontSize,
                ),
              )
            : _buildPlaceholder(initial, effectiveTextColor, effectiveFontSize),
      ),
    );
  }

  Widget _buildPlaceholder(String initial, Color textColor, double fontSize) {
    if (initial.isNotEmpty) {
      return Center(
        child: Text(
          initial,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
          ),
        ),
      );
    }
    return Center(
      child: Icon(
        Icons.person_rounded,
        size: fontSize * 1.3,
        color: Colors.white,
      ),
    );
  }
}
