import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  ///
  /// Green accent with Crimson Noir harmony
  static void success({
    required String message,
    String? title,
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
      icon: Icons.check_circle,
      backgroundColor: AppTokens.colors.success,
      borderColor: AppTokens.colors.success.withValues(alpha: 0.3),
    );
  }

  /// Show error snackbar
  ///
  /// Crimson highlight with clear error indication
  static void error({
    required String message,
    String? title,
    Duration duration = _longDuration,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      message: message,
      title: title ?? 'Error',
      duration: duration,
      onTap: onTap,
      actionLabel: actionLabel,
      onAction: onAction,
      icon: Icons.error_outline,
      backgroundColor: AppTokens.colors.error.withValues(alpha: 0.15),
      borderColor: AppTokens.colors.error,
      textColor: AppColors.textPrimary,
    );
  }

  /// Show warning snackbar
  ///
  /// Muted amber tone for caution messages
  static void warning({
    required String message,
    String? title,
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
      icon: Icons.warning_amber_rounded,
      backgroundColor: AppTokens.colors.warning.withValues(alpha: 0.15),
      borderColor: AppTokens.colors.warning.withValues(alpha: 0.5),
      textColor: AppColors.textPrimary,
    );
  }

  /// Show info snackbar
  ///
  /// Neutral info tone for general information
  static void info({
    required String message,
    String? title,
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
      icon: Icons.info_outline,
      backgroundColor: AppTokens.colors.info.withValues(alpha: 0.15),
      borderColor: AppTokens.colors.info.withValues(alpha: 0.5),
      textColor: AppColors.textPrimary,
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

    Get.snackbar(
      title ?? '',
      message,
      titleText: title != null
          ? Text(
              title,
              style: TextStyle(
                color: textColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            )
          : const SizedBox.shrink(),
      messageText: Text(
        message,
        style: TextStyle(
          color: (textColor ?? AppColors.textPrimary).withValues(alpha: 0.9),
          fontWeight: FontWeight.w400,
          fontSize: 13,
          letterSpacing: 0.1,
          height: 1.4,
        ),
      ),
      backgroundColor: backgroundColor.withValues(alpha: 0.85),
      colorText: textColor ?? AppColors.textPrimary,
      borderColor: borderColor?.withValues(alpha: 0.4),
      borderWidth: borderColor != null ? 0.5 : 0,
      borderRadius: 14,
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
      animationDuration: const Duration(milliseconds: 400),
      forwardAnimationCurve: Curves.easeOutCirc,
      reverseAnimationCurve: Curves.easeInCirc,
      boxShadows: [
        BoxShadow(
          color: AppColors.bgPage.withValues(alpha: 0.25),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
      icon: icon != null
          ? Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                icon,
                color: borderColor ?? AppColors.textPrimary,
                size: 22,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: (borderColor ?? AppColors.brand).withValues(
                  alpha: 0.15,
                ),
              ),
              child: Text(
                actionLabel,
                style: TextStyle(
                  color: borderColor ?? AppColors.brand,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            )
          : null,
      showProgressIndicator: showProgress,
      progressIndicatorBackgroundColor: Colors.transparent,
      progressIndicatorValueColor: AlwaysStoppedAnimation<Color>(
        borderColor ?? AppColors.brand,
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
                color: iconColor ?? AppColors.textPrimary,
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
                        color: textColor ?? AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor ?? AppColors.textSecondary,
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
              child: TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTokens.spacing.space8,
                    vertical: AppTokens.spacing.space4,
                  ),
                  minimumSize: const Size(0, 0),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
