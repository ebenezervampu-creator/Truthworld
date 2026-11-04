import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_toast.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Premium Snackbar Service
///
/// Centralized service for all app feedback/snackbars
/// Ensures visual consistency and enforces Crimson Noir theme
///
/// Usage:
///   SnackbarService.success(message: 'Video uploaded successfully');
///   SnackbarService.error(message: 'Failed to load videos');
///   SnackbarService.warning(message: 'This action cannot be undone');
///   SnackbarService.info(message: 'New content available');
class SnackbarService {
  // Prevent instantiation
  SnackbarService._();

  // Snackbar configuration constants
  static const Duration _defaultDuration = Duration(seconds: 3);
  static const Duration _longDuration = Duration(seconds: 5);

  /// Show success snackbar
  static void success({
    required String message,
    String? title,
    Duration duration = _defaultDuration,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    AppToast.success(
      message,
      title: title,
      duration: duration,
      onAction: onAction ?? onTap,
      actionLabel: actionLabel,
    );
  }

  /// Show error snackbar
  static void error({
    required String message,
    String? title,
    Duration duration = _longDuration,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    AppToast.error(
      message,
      title: title,
      duration: duration,
      onAction: onAction ?? onTap,
      actionLabel: actionLabel,
    );
  }

  /// Show warning snackbar
  static void warning({
    required String message,
    String? title,
    Duration duration = _defaultDuration,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    AppToast.warning(
      message,
      title: title,
      duration: duration,
      onAction: onAction ?? onTap,
      actionLabel: actionLabel,
    );
  }

  /// Show info snackbar
  static void info({
    required String message,
    String? title,
    Duration duration = _defaultDuration,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    AppToast.info(
      message,
      title: title,
      duration: duration,
      onAction: onAction ?? onTap,
      actionLabel: actionLabel,
    );
  }

  /// Show custom snackbar
  ///
  /// For advanced customization beyond standard types
  static void custom({
    required String message,
    required Color backgroundColor,
    String? title,
    Color? borderColor,
    Color? textColor,
    IconData? icon,
    Duration duration = _defaultDuration,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      message: message,
      title: title,
      duration: duration,
      onTap: onTap,
      actionLabel: actionLabel,
      onAction: onAction,
      icon: icon,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      textColor: textColor,
    );
  }

  /// Show loading snackbar
  ///
  /// For long-running operations
  static void loading({required String message, String? title}) {
    _show(
      message: message,
      title: title ?? 'Loading',
      duration: const Duration(milliseconds: 1),
      showProgress: true,
      backgroundColor: AppColors.bgSurface,
      borderColor: AppColors.brand.withValues(alpha: 0.3),
      textColor: AppColors.textPrimary,
    );
  }

  /// Dismiss all snackbars
  static void dismissAll() {
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }
  }

  /// Internal method to show snackbar with consistent styling
  static void _show({
    required String message,
    required Duration duration,
    required Color backgroundColor,
    String? title,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
    IconData? icon,
    Color? borderColor,
    Color? textColor,
    bool showProgress = false,
  }) {
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    Future.delayed(duration, () {
      if (Get.isSnackbarOpen && !showProgress) {
        Get.closeCurrentSnackbar();
      }
    });

    final isMobile = Get.width < 600;
    final actualMaxWidth = isMobile ? Get.width * 0.9 : 450.0;
    final sanitizedTitle = UserFeedbackSanitizer.sanitizeTitle(title);
    final sanitizedMessage = UserFeedbackSanitizer.sanitizeMessage(message);

    Get.snackbar(
      sanitizedTitle ?? '',
      sanitizedMessage,
      titleText: sanitizedTitle != null
          ? Text(
              sanitizedTitle,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                fontFamily: TWTypography.uiFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                letterSpacing: 0.1,
              ),
            )
          : const SizedBox.shrink(),
      messageText: Text(
        sanitizedMessage,
        style: const TextStyle(
          color: Color(0xFF1F2937),
          fontWeight: FontWeight.w400,
          fontSize: 13,
          fontFamily: TWTypography.uiFamily,
          fontFamilyFallback: TWTypography.fallbackFamilies,
          height: 1.35,
        ),
      ),
      backgroundColor: Colors.white,
      colorText: Colors.black,
      borderColor: const Color(0xFFE5E7EB),
      borderWidth: 1.0,
      borderRadius: 22,
      margin: EdgeInsets.only(
        bottom: isMobile ? 16 : 24,
        left: 16,
        right: 16,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      maxWidth: actualMaxWidth,
      snackPosition: SnackPosition.BOTTOM,
      isDismissible: true,
      animationDuration: const Duration(milliseconds: 350),
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
      icon: icon != null
          ? Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                icon,
                color: Colors.black,
                size: 24,
              ),
            )
          : null,
      shouldIconPulse: false,
      mainButton: actionLabel != null
          ? TextButton(
              onPressed: () {
                Get.closeCurrentSnackbar();
                onAction?.call();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                minimumSize: const Size(68, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.black,
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            )
          : null,
      showProgressIndicator: showProgress,
      progressIndicatorBackgroundColor: Colors.transparent,
      progressIndicatorValueColor: const AlwaysStoppedAnimation<Color>(
        Colors.black,
      ),
      duration: duration,
      onTap: (_) => onTap?.call(),
    );
  }
}

/// Custom Snackbar Content Widget
///
/// For more complex snackbar UI beyond text
class SnackbarContent extends StatelessWidget {
  const SnackbarContent({
    required this.message,
    super.key,
    this.icon,
    this.title,
    this.iconColor,
    this.textColor,
    this.actionLabel,
    this.onAction,
  });
  final IconData? icon;
  final String? title;
  final String message;
  final Color? iconColor;
  final Color? textColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTokens.spacing.space12,
        vertical: AppTokens.spacing.space8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          if (icon != null)
            Padding(
              padding: EdgeInsets.only(right: AppTokens.spacing.space12),
              child: Icon(
                icon,
                color: iconColor ?? Colors.black,
                size: 20,
              ),
            ),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: AppTokens.spacing.space4),
                    child: Text(
                      title!,
                      style: TextStyle(
                        color: textColor ?? Colors.black,
                        fontWeight: FontWeight.w600,
                        fontFamily: TWTypography.uiFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        fontSize: 13,
                      ),
                    ),
                  ),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor ?? const Color(0xFF1F2937),
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Action button
          if (actionLabel != null)
            Padding(
              padding: EdgeInsets.only(left: AppTokens.spacing.space12),
              child: OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  minimumSize: const Size(68, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: const BorderSide(
                    color: Color(0xFFD1D5DB),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  actionLabel!,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
