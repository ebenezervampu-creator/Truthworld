import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/core/widgets/google_logo.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Unified toast/notification system for Truthworld.
///
/// Features an absolute-white floating card theme contrasting against
/// Truthworld's dark background, using authentic TruthWorld fonts (Roboto & TruthWorld Sans fallback).
///
/// Variants:
/// - Sign-In Prompt (Image 2): Soft red circular badge + red warning icon + Google "G" pill button.
/// - Standard Notifications (Image 3): Solid black semantic icon + inline title/message + outlined pill button.
class AppToast {
  AppToast._();

  // ── Semantic Variants ───────────────────────────────────────────────────

  /// Sign-in required notification (Image 2 Design: soft red badge, Google sign-in button).
  static void signIn({
    String? message,
    String? title,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    _show(
      title: title ?? 'Sign In Required',
      message: message ?? 'Please sign in with your Google account to proceed.',
      type: _ToastType.signIn,
      onAction: onAction,
      actionLabel: 'Sign In',
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Success toast — confirmations, completions (Image 3 Design).
  static void success(
    String message, {
    String? title,
    VoidCallback? onAction,
    String? actionLabel,
    Widget? action,
    Duration? duration,
  }) {
    _show(
      title: title,
      message: message,
      type: _ToastType.success,
      onAction: onAction,
      actionLabel: actionLabel,
      action: action,
      duration: duration,
    );
  }

  /// Error toast — failures, invalid actions (Image 3 Design).
  static void error(
    String message, {
    String? title,
    VoidCallback? onAction,
    String? actionLabel,
    Widget? action,
    Duration? duration,
  }) {
    _show(
      title: title,
      message: message,
      type: _ToastType.error,
      onAction: onAction,
      actionLabel: actionLabel ?? (onAction != null ? 'Retry' : null),
      action: action,
      duration: duration,
    );
  }

  /// Info toast — neutral information (Image 3 Design).
  static void info(
    String message, {
    String? title,
    VoidCallback? onAction,
    String? actionLabel,
    Widget? action,
    Duration? duration,
  }) {
    _show(
      title: title,
      message: message,
      type: _ToastType.info,
      onAction: onAction,
      actionLabel: actionLabel,
      action: action,
      duration: duration,
    );
  }

  /// Warning toast — cautions, degraded states (Image 3 Design).
  static void warning(
    String message, {
    String? title,
    VoidCallback? onAction,
    String? actionLabel,
    Widget? action,
    Duration? duration,
  }) {
    _show(
      title: title,
      message: message,
      type: _ToastType.warning,
      onAction: onAction,
      actionLabel: actionLabel,
      action: action,
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
    Widget? action,
    Duration? duration,
  }) {
    if (Get.testMode || Get.context == null || Get.overlayContext == null) {
      return;
    }

    final config = _toastConfig(type);

    // Dismiss any active snackbars to prevent overlap/stacking
    _safeCloseAllSnackbars();

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

    // Determine if this is a sign-in snackbar (Image 2 vs Image 3)
    final titleLower = sanitizedTitle?.toLowerCase() ?? '';
    final messageLower = sanitizedMessage.toLowerCase();
    final actionLabelLower = actionLabel?.toLowerCase() ?? '';

    final isSignIn = type == _ToastType.signIn ||
        titleLower.contains('sign in') ||
        actionLabelLower.contains('sign in') ||
        messageLower.contains('sign in with your google') ||
        messageLower.contains('sign in to post') ||
        messageLower.contains('please sign in');

    // Determine if the title is redundant (e.g. empty or matches semantic name)
    final typeName = type.name.toLowerCase();
    final isTitleRedundant = sanitizedTitle == null ||
        sanitizedTitle.isEmpty ||
        sanitizedTitle.toLowerCase() == typeName;

    // Format action label to clean title case if ALL CAPS
    var formattedActionLabel = actionLabel ?? '';
    if (formattedActionLabel.length > 1 &&
        formattedActionLabel == formattedActionLabel.toUpperCase()) {
      formattedActionLabel = formattedActionLabel[0].toUpperCase() +
          formattedActionLabel.substring(1).toLowerCase();
    }

    // Build the action button
    Widget? trailingAction;
    if (action != null) {
      trailingAction = action;
    } else if (isSignIn) {
      // Image 2: Black pill button with Google logo + "Sign In"
      trailingAction = Material(
        color: Colors.black,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            _safeCloseAllSnackbars();
            if (onAction != null) {
              onAction();
            } else if (Get.isRegistered<AuthService>()) {
              AuthService.to.triggerPlatformSignIn();
            }
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GoogleLogo(size: 16),
                SizedBox(width: 8),
                Text(
                  'Sign In',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (onAction != null && formattedActionLabel.isNotEmpty) {
      // Image 3: White outlined pill button with dark text
      trailingAction = OutlinedButton(
        onPressed: () {
          _safeCloseAllSnackbars();
          onAction();
        },
        style: OutlinedButton.styleFrom(
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
          formattedActionLabel,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.black,
            fontFamily: TWTypography.uiFamily,
            fontFamilyFallback: TWTypography.fallbackFamilies,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Build the leading icon
    final Widget leadingIcon;
    if (isSignIn) {
      // Image 2: Soft red circular badge + bright red warning icon
      leadingIcon = Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Color(0xFFFFECEB),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.warning_rounded,
          color: Color(0xFFFF1744),
          size: 22,
        ),
      );
    } else {
      // Image 3: Solid black icon directly on the white background
      leadingIcon = Icon(
        config.icon,
        color: Colors.black,
        size: 24,
      );
    }

    // Build the text layout
    final Widget textWidget;
    if (isSignIn) {
      // Image 2: Stacked bold title with message underneath
      textWidget = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sanitizedTitle?.isNotEmpty == true
                ? (sanitizedTitle!.endsWith(':')
                    ? sanitizedTitle!
                    : '$sanitizedTitle:')
                : 'Sign In Required:',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
              letterSpacing: -0.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            sanitizedMessage,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontWeight: FontWeight.w400,
              fontSize: 12.5,
              height: 1.3,
              fontFamily: TWTypography.uiFamily,
              fontFamilyFallback: TWTypography.fallbackFamilies,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else {
      // Image 3: Flowing inline title and message with TruthWorld fonts
      textWidget = isTitleRedundant
          ? Text(
              sanitizedMessage,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w500,
                fontSize: 13.5,
                height: 1.35,
                fontFamily: TWTypography.uiFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: sanitizedTitle!.endsWith(':')
                        ? '$sanitizedTitle '
                        : '$sanitizedTitle: ',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                    ),
                  ),
                  TextSpan(
                    text: sanitizedMessage,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontWeight: FontWeight.w400,
                      fontSize: 13.5,
                      height: 1.35,
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            );
    }

    Get.snackbar(
      '',
      '',
      titleText: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leadingIcon,
          const SizedBox(width: 14),
          Expanded(child: textWidget),
          if (trailingAction != null) ...[
            const SizedBox(width: 12),
            trailingAction,
          ],
        ],
      ),
      messageText: const SizedBox.shrink(),
      snackPosition: SnackPosition.BOTTOM,
      duration: duration ?? config.duration,
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 22,
      backgroundColor: Colors.white,
      borderColor: const Color(0xFFE5E7EB),
      borderWidth: 1.0,
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
      animationDuration: const Duration(milliseconds: 350),
      snackStyle: SnackStyle.FLOATING,
      maxWidth: 480,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static void _safeCloseAllSnackbars() {
    try {
      if (Get.isSnackbarOpen) {
        Get.closeCurrentSnackbar();
      }
    } on Object {
      // Gracefully intercept any transition or assertion errors during rapid transitions
    }
  }

  static _ToastConfig _toastConfig(_ToastType type) {
    switch (type) {
      case _ToastType.success:
        return const _ToastConfig(
          icon: Icons.check_circle_rounded,
          duration: Duration(milliseconds: 2500),
        );
      case _ToastType.error:
        return const _ToastConfig(
          icon: Icons.error_outline_rounded,
          duration: Duration(milliseconds: 4000),
        );
      case _ToastType.info:
        return const _ToastConfig(
          icon: Icons.info_outline_rounded,
          duration: Duration(milliseconds: 3000),
        );
      case _ToastType.warning:
        return const _ToastConfig(
          icon: Icons.warning_rounded,
          duration: Duration(milliseconds: 3500),
        );
      case _ToastType.signIn:
        return const _ToastConfig(
          icon: Icons.warning_rounded,
          duration: Duration(milliseconds: 4000),
        );
    }
  }
}

enum _ToastType { success, error, info, warning, signIn }

class _ToastConfig {
  const _ToastConfig({
    required this.icon,
    required this.duration,
  });
  final IconData icon;
  final Duration duration;
}
