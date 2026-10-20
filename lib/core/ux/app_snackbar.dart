import 'package:flutter/material.dart';
import 'package:truthworld/core/ux/app_toast.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Centralized Snackbar feedback service delegating to the unified AppToast.
/// Enforces consistent styling, duration, action buttons, and responsive behaviors.
/// All user-facing messages and titles are automatically sanitized to ensure
/// no raw developer exceptions or harsh 'Error' headers are ever displayed to users.
class AppSnackbar {
  AppSnackbar._();

  /// Generic snackbar matching Get.snackbar parameters to route legacy calls to unified styling
  static void show(
    String title,
    String message, {
    Color? backgroundColor,
    Color? colorText,
    dynamic snackPosition, // Support SnackPosition (GetX)
    Duration? duration,
    Widget? icon,
    Widget? titleText,
    Widget? messageText,
    bool? shouldIconPulse,
    double? borderRadius,
    EdgeInsets? margin,
    dynamic mainButton,
    dynamic isDismissible,
    dynamic dismissDirection,
    dynamic forwardAnimationCurve,
    dynamic reverseAnimationCurve,
    dynamic animationDuration,
    dynamic snackStyle,
    double? maxWidth,
    dynamic boxShadows,
    Color? borderColor,
    double? borderWidth,
    double? barBlur,
    Color? leftBarIndicatorColor,
    double? overlayBlur,
    Color? overlayColor,
    dynamic userInputForm,
    bool? showProgressIndicator,
    dynamic progressIndicatorController,
    Color? progressIndicatorBackgroundColor,
    dynamic progressIndicatorValueColor,
    dynamic onTap,
    dynamic snackbarStatus,
    EdgeInsets? padding,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final titleLower = title.toLowerCase().trim();
    final messageLower = message.toLowerCase().trim();

    final isError =
        titleLower.contains('error') ||
        titleLower.contains('fail') ||
        titleLower.contains('cannot') ||
        titleLower.contains('rejected') ||
        titleLower.contains('required') ||
        titleLower.contains('invalid') ||
        titleLower.contains('denied') ||
        messageLower.contains('error') ||
        messageLower.contains('failed') ||
        messageLower.contains('invalid') ||
        (backgroundColor != null &&
            (backgroundColor.toARGB32() == 0xFFEF4444 ||
                backgroundColor.toARGB32() == 0xFFCF6679 ||
                backgroundColor == AppColors.error ||
                backgroundColor == AppColors.error));

    final isSuccess =
        titleLower.contains('success') ||
        titleLower.contains('complete') ||
        titleLower.contains('saved') ||
        titleLower.contains('uploaded') ||
        messageLower.contains('success') ||
        messageLower.contains('successfully') ||
        messageLower.contains('completed') ||
        (backgroundColor != null &&
            (backgroundColor.toARGB32() == 0xFF2BA640 ||
                backgroundColor.toARGB32() == 0xFF10B981 ||
                backgroundColor == AppColors.success ||
                backgroundColor == AppColors.success));

    final isWarning =
        titleLower.contains('warning') ||
        titleLower.contains('alert') ||
        titleLower.contains('caution') ||
        titleLower.contains('pending') ||
        titleLower.contains('verify') ||
        messageLower.contains('warning') ||
        (backgroundColor != null &&
            (backgroundColor.toARGB32() == 0xFFF59E0B ||
                backgroundColor.toARGB32() == 0xFFF9BF05 ||
                backgroundColor == AppColors.warning ||
                backgroundColor == AppColors.warning));

    Widget? actionWidget;
    if (mainButton is Widget) {
      actionWidget = mainButton;
    }

    if (isError) {
      AppToast.error(
        message,
        title: title,
        onAction: onAction,
        actionLabel: actionLabel,
        action: actionWidget,
        duration: duration,
      );
    } else if (isSuccess) {
      AppToast.success(
        message,
        title: title,
        onAction: onAction,
        actionLabel: actionLabel,
        action: actionWidget,
        duration: duration,
      );
    } else if (isWarning) {
      AppToast.warning(
        message,
        title: title,
        onAction: onAction,
        actionLabel: actionLabel,
        action: actionWidget,
        duration: duration,
      );
    } else {
      AppToast.info(
        message,
        title: title,
        onAction: onAction,
        actionLabel: actionLabel,
        action: actionWidget,
        duration: duration,
      );
    }
  }

  /// Semantic Success Snackbar
  static void success(
    String message, {
    String? title,
    VoidCallback? onAction,
    String? actionLabel,
    Widget? action,
    Duration? duration,
  }) {
    AppToast.success(
      message,
      title: title,
      onAction: onAction,
      actionLabel: actionLabel,
      action: action,
      duration: duration,
    );
  }

  /// Semantic Error Snackbar
  static void error(
    String message, {
    String? title,
    VoidCallback? onAction,
    String? actionLabel,
    Widget? action,
    Duration? duration,
  }) {
    AppToast.error(
      message,
      title: title,
      onAction: onAction,
      actionLabel: actionLabel,
      action: action,
      duration: duration,
    );
  }

  /// Semantic Info/Neutral Snackbar
  static void info(
    String message, {
    String? title,
    VoidCallback? onAction,
    String? actionLabel,
    Widget? action,
    Duration? duration,
  }) {
    AppToast.info(
      message,
      title: title,
      onAction: onAction,
      actionLabel: actionLabel,
      action: action,
      duration: duration,
    );
  }

  /// Semantic Warning Snackbar
  static void warning(
    String message, {
    String? title,
    VoidCallback? onAction,
    String? actionLabel,
    Widget? action,
    Duration? duration,
  }) {
    AppToast.warning(
      message,
      title: title,
      onAction: onAction,
      actionLabel: actionLabel,
      action: action,
      duration: duration,
    );
  }
}
