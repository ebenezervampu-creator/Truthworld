import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Premium Toast Notification Service
///
/// Quick-dismiss feedback notifications with minimal disruption
/// Toasts are smaller and faster than snackbars
///
/// Usage:
///   ToastService.success('Operation successful');
///   ToastService.error('Something went wrong');
///   ToastService.loading('Processing...');
class ToastService {
  ToastService._();

  static const double _maxWidth = 320;

  static const double _borderRadius = 12;

  /// Show success toast
  static void success(String message, {Duration? duration}) {
    _show(
      message: message,
      icon: Icons.check_circle,
      iconColor: AppTheme.colors.success,
      backgroundColor: AppTheme.colors.success.withValues(alpha: 0.15),
      borderColor: AppTheme.colors.success.withValues(alpha: 0.3),
      duration: duration,
    );
  }

  /// Show error toast
  static void error(String message, {Duration? duration}) {
    _show(
      message: message,
      icon: Icons.error_outline,
      iconColor: AppTheme.colors.error,
      backgroundColor: AppTheme.colors.error.withValues(alpha: 0.15),
      borderColor: AppTheme.colors.error.withValues(alpha: 0.3),
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// Show warning toast
  static void warning(String message, {Duration? duration}) {
    _show(
      message: message,
      icon: Icons.warning_amber_rounded,
      iconColor: AppTheme.colors.warning,
      backgroundColor: AppTheme.colors.warning.withValues(alpha: 0.15),
      borderColor: AppTheme.colors.warning.withValues(alpha: 0.3),
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// Show info toast
  static void info(String message, {Duration? duration}) {
    _show(
      message: message,
      icon: Icons.info_outline,
      iconColor: AppTheme.colors.info,
      backgroundColor: AppTheme.colors.info.withValues(alpha: 0.15),
      borderColor: AppTheme.colors.info.withValues(alpha: 0.3),
      duration: duration,
    );
  }

  /// Show loading toast
  ///
  /// Displays with loading indicator, auto-dismiss not recommended
  static void loading(String message) {
    Get.showSnackbar(
      GetSnackBar(
        title: '',
        message: '',
        duration: const Duration(days: 365),
        margin: EdgeInsets.all(AppTheme.spacing.space16),
        borderRadius: _borderRadius,
        backgroundColor: AppTheme.colors.surface,
        shouldIconPulse: false,
        boxShadows: [
          BoxShadow(
            color: AppTheme.colors.overlay,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        maxWidth: _maxWidth,
        snackPosition: SnackPosition.TOP,
        padding: EdgeInsets.all(AppTheme.spacing.space12),
        messageText: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.colors.primary,
                ),
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: AppTheme.spacing.space8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: AppTheme.colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show custom toast
  static void custom({
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
    Duration? duration,
  }) {
    _show(
      message: message,
      icon: icon,
      iconColor: iconColor,
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      duration: duration,
    );
  }

  /// Dismiss all toasts
  static void dismissAll() {
    Get.closeAllSnackbars();
  }

  /// Internal method to show toast
  static void _show({
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
    Duration? duration,
  }) {
    Get.showSnackbar(
      GetSnackBar(
        title: '',
        message: '',
        duration: duration ?? const Duration(seconds: 2),
        margin: EdgeInsets.all(AppTheme.spacing.space16),
        borderRadius: _borderRadius,
        backgroundColor: backgroundColor,
        shouldIconPulse: false,
        boxShadows: [
          BoxShadow(
            color: AppTheme.colors.overlayLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        maxWidth: _maxWidth,
        snackPosition: SnackPosition.TOP,
        padding: EdgeInsets.all(AppTheme.spacing.space12),
        borderColor: borderColor,
        animationDuration: const Duration(milliseconds: 200),
        forwardAnimationCurve: Curves.easeOutCubic,
        reverseAnimationCurve: Curves.easeInCubic,
        messageText: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            SizedBox(width: AppTheme.spacing.space8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}





