import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
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
    Duration? duration,
  }) {
    _show(
      title: title,
      message: message,
      type: _ToastType.success,
      onAction: onAction,
      actionLabel: actionLabel,
      duration: duration,
    );
  }

  /// Red error toast — failures, invalid actions.
  static void error(
    String message, {
    String? title,
    VoidCallback? onAction,
    String? actionLabel,
    Duration? duration,
  }) {
    _show(
      title: title,
      message: message,
      type: _ToastType.error,
      onAction: onAction,
      actionLabel: actionLabel ?? (onAction != null ? 'Retry' : null),
      duration: duration,
    );
  }

  /// Brand purple info toast — neutral information.
  static void info(
    String message, {
    String? title,
    VoidCallback? onAction,
    String? actionLabel,
    Duration? duration,
  }) {
    _show(
      title: title,
      message: message,
      type: _ToastType.info,
      onAction: onAction,
      actionLabel: actionLabel,
      duration: duration,
    );
  }

  /// Amber warning toast — cautions, degraded states.
  static void warning(
    String message, {
    String? title,
    VoidCallback? onAction,
    String? actionLabel,
    Duration? duration,
  }) {
    _show(
      title: title,
      message: message,
      type: _ToastType.warning,
      onAction: onAction,
      actionLabel: actionLabel,
      duration: duration,
    );
  }

  // ── Internal ────────────────────────────────────────────────────────────

  static void _show({
    required String message,
    required _ToastType type,
    String? title,
    VoidCallback? onAction,
    String? actionLabel,
    Duration? duration,
  }) {
    if (Get.testMode || Get.context == null || Get.overlayContext == null) {
      return;
    }

    final context = Get.context;
    final colors = context?.colors;
    final radius = context?.radius;
    final config = _toastConfig(type);

    // Dismiss any active snackbars to prevent overlap/stacking
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }

    final sanitizedTitle = UserFeedbackSanitizer.sanitizeTitle(title);
    var sanitizedMessage = UserFeedbackSanitizer.sanitizeMessage(message);

    final lowerSanitized = sanitizedMessage.trim().toLowerCase();
    if (lowerSanitized == 'internal' ||
        lowerSanitized == 'unavailable' ||
        lowerSanitized == 'internal error' ||
        lowerSanitized == 'error' ||
        lowerSanitized == 'failed' ||
        lowerSanitized.isEmpty) {
      sanitizedMessage = 'The service is temporarily unavailable. Please try again shortly.';
    }

    // Determine if the title is redundant (e.g. empty or matches semantic name)
    final typeName = type.name.toLowerCase();
    final isTitleRedundant = sanitizedTitle == null ||
        sanitizedTitle.isEmpty ||
        sanitizedTitle.toLowerCase() == typeName;

    final inlineText = isTitleRedundant
        ? TextSpan(
            text: sanitizedMessage,
            style: TextStyle(
              color: colors?.textPrimary ?? AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          )
        : TextSpan(
            children: [
              TextSpan(
                text: '$sanitizedTitle: ',
                style: TextStyle(
                  color: colors?.textPrimary ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: sanitizedMessage,
                style: TextStyle(
                  color: colors?.textSecondary ?? AppColors.textSecondary,
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
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              inlineText,
              style: const TextStyle(
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
                  borderRadius: radius?.md ?? BorderRadius.circular(8),
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
      duration: duration ?? config.duration,
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: radius?.lgValue ?? 12,
      backgroundColor: colors?.surfaceContainer ?? AppColors.bgSurfaceHover,
      borderColor: AppColors.textPrimary.withValues(alpha: 0.08),
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
    final context = Get.context;
    final colors = context?.colors;
    switch (type) {
      case _ToastType.success:
        return _ToastConfig(
          color: colors?.success ?? AppColors.success,
          icon: Icons.check_circle_rounded,
          duration: const Duration(milliseconds: 2500),
        );
      case _ToastType.error:
        return _ToastConfig(
          color: colors?.error ?? AppColors.error,
          icon: Icons.error_rounded,
          duration: const Duration(milliseconds: 4000),
        );
      case _ToastType.info:
        return _ToastConfig(
          color: colors?.brand ?? AppColors.brand,
          icon: Icons.info_rounded,
          duration: const Duration(milliseconds: 3000),
        );
      case _ToastType.warning:
        return _ToastConfig(
          color: colors?.warning ?? AppColors.warning,
          icon: Icons.warning_rounded,
          duration: const Duration(milliseconds: 3500),
        );
    }
  }
}

enum _ToastType { success, error, info, warning }

class _ToastConfig {
  const _ToastConfig({
    required this.color,
    required this.icon,
    required this.duration,
  });
  final Color color;
  final IconData icon;
  final Duration duration;
}
