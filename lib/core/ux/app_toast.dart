import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Unified toast/notification system for Truthworld.
///
/// Replaces all ad-hoc `Get.snackbar(...)` calls with a consistent,
/// branded notification system. Four semantic variants:
///
/// ```dart
/// AppToast.success('Video published!');
/// AppToast.error('Upload failed', onAction: retry, actionLabel: 'Retry');
/// AppToast.info('History paused');
/// AppToast.warning('You are offline');
/// ```
class AppToast {
  AppToast._();

  // ── Semantic Variants ───────────────────────────────────────────────────

  /// Green success toast — confirmations, completions.
  static void success(
    String message, {
    String? title,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    _show(
      title: title ?? 'Success',
      message: message,
      type: _ToastType.success,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Red error toast — failures, invalid actions.
  static void error(
    String message, {
    String? title,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    _show(
      title: title ?? 'Error',
      message: message,
      type: _ToastType.error,
      onAction: onAction,
      actionLabel: actionLabel ?? (onAction != null ? 'Retry' : null),
    );
  }

  /// Brand purple info toast — neutral information.
  static void info(
    String message, {
    String? title,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    _show(
      title: title ?? 'Info',
      message: message,
      type: _ToastType.info,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Amber warning toast — cautions, degraded states.
  static void warning(
    String message, {
    String? title,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    _show(
      title: title ?? 'Warning',
      message: message,
      type: _ToastType.warning,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  // ── Internal ────────────────────────────────────────────────────────────

  static void _show({
    required String title,
    required String message,
    required _ToastType type,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final config = _toastConfig(type);

    // Dismiss any active snackbars to prevent overlap/stacking
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }

    // Determine if the title is redundant (e.g. standard semantic labels)
    final titleLower = title.toLowerCase().trim();
    final typeName = type.name.toLowerCase();
    final isTitleRedundant = title.isEmpty ||
        titleLower == 'success' ||
        titleLower == 'error' ||
        titleLower == 'info' ||
        titleLower == 'warning' ||
        titleLower == typeName;

    final inlineText = isTitleRedundant
        ? TextSpan(
            text: message,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          )
        : TextSpan(
            children: [
              TextSpan(
                text: '$title: ',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: message,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          );

    Get.snackbar(
      '',
      '',
      titleText: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            color: config.color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              inlineText,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: () {
                if (Get.isSnackbarOpen) Get.closeAllSnackbars();
                onAction();
              },
              style: TextButton.styleFrom(
                foregroundColor: config.color,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: config.color.withValues(alpha: 0.3),
                  ),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      messageText: const SizedBox.shrink(),
      snackPosition: SnackPosition.BOTTOM,
      duration: config.duration,
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 12,
      backgroundColor: const Color(0xFF1E1E1E),
      borderColor: Colors.white.withValues(alpha: 0.08),
      borderWidth: 1,
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
      animationDuration: const Duration(milliseconds: 350),
      snackStyle: SnackStyle.FLOATING,
      maxWidth: 420,
    );
  }

  static _ToastConfig _toastConfig(_ToastType type) {
    switch (type) {
      case _ToastType.success:
        return _ToastConfig(
          color: const Color(0xFF2BA640),
          icon: Icons.check_circle_rounded,
          duration: const Duration(milliseconds: 2500),
        );
      case _ToastType.error:
        return _ToastConfig(
          color: const Color(0xFFEF4444),
          icon: Icons.error_rounded,
          duration: const Duration(milliseconds: 4000),
        );
      case _ToastType.info:
        return _ToastConfig(
          color: AppColors.brand,
          icon: Icons.info_rounded,
          duration: const Duration(milliseconds: 3000),
        );
      case _ToastType.warning:
        return _ToastConfig(
          color: const Color(0xFFF59E0B),
          icon: Icons.warning_rounded,
          duration: const Duration(milliseconds: 3500),
        );
    }
  }
}

enum _ToastType { success, error, info, warning }

class _ToastConfig {
  final Color color;
  final IconData icon;
  final Duration duration;

  const _ToastConfig({
    required this.color,
    required this.icon,
    required this.duration,
  });
}
