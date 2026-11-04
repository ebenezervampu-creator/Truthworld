import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_toast.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Premium Toast Notification Service
///
/// Quick-dismiss feedback notifications delegating to the unified AppToast.
///
/// Usage:
///   ToastService.success('Operation successful');
///   ToastService.error('Something went wrong');
///   ToastService.loading('Processing...');
class ToastService {
  ToastService._();

  static const double _maxWidth = 340;
  static const double _borderRadius = 22;

  /// Show success toast
  static void success(String message, {Duration? duration}) {
    AppToast.success(message, duration: duration);
  }

  /// Show error toast
  static void error(String message, {Duration? duration}) {
    AppToast.error(message, duration: duration ?? const Duration(seconds: 3));
  }

  /// Show warning toast
  static void warning(String message, {Duration? duration}) {
    AppToast.warning(message, duration: duration ?? const Duration(seconds: 3));
  }

  /// Show info toast
  static void info(String message, {Duration? duration}) {
    AppToast.info(message, duration: duration);
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
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        borderRadius: _borderRadius,
        backgroundColor: Colors.white,
        borderColor: const Color(0xFFE5E7EB),
        borderWidth: 1.0,
        shouldIconPulse: false,
        boxShadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        maxWidth: _maxWidth,
        snackPosition: SnackPosition.BOTTOM,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        messageText: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                strokeWidth: 2.2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.black,
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 13,
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
    Color? iconColor,
    Color? backgroundColor,
    Color? borderColor,
    Duration? duration,
  }) {
    _show(
      message: message,
      icon: icon,
      iconColor: iconColor ?? Colors.black,
      backgroundColor: backgroundColor ?? Colors.white,
      borderColor: borderColor ?? const Color(0xFFE5E7EB),
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
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
        borderRadius: _borderRadius,
        backgroundColor: backgroundColor,
        shouldIconPulse: false,
        boxShadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        maxWidth: _maxWidth,
        snackPosition: SnackPosition.BOTTOM,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderColor: borderColor,
        animationDuration: const Duration(milliseconds: 350),
        forwardAnimationCurve: Curves.easeOutCubic,
        reverseAnimationCurve: Curves.easeInCubic,
        messageText: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  fontSize: 13,
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
