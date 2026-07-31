import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Premium Dialog Service
///
/// Handles all dialogs, alerts, and modals with Crimson Noir styling
///
/// Usage:
///   DialogService.success(
///     title: 'Success',
///     message: 'Video uploaded successfully',
///   );
class DialogService {
  DialogService._();

  /// Show success dialog
  static Future<bool?> success({
    required String title,
    required String message,
    String? confirmLabel,
    VoidCallback? onConfirm,
  }) {
    return _showDialog(
      title: title,
      message: message,
      icon: Icons.check_circle,
      iconColor: AppTokens.colors.success,
      headerBackgroundColor: AppTokens.colors.success.withValues(alpha: 0.1),
      confirmLabel: confirmLabel ?? 'Done',
      onConfirm: onConfirm,
    );
  }

  /// Show error dialog
  static Future<bool?> error({
    required String title,
    required String message,
    String? confirmLabel,
    VoidCallback? onConfirm,
  }) {
    return _showDialog(
      title: title,
      message: message,
      icon: Icons.error_outline,
      iconColor: AppTokens.colors.error,
      headerBackgroundColor: AppTokens.colors.error.withValues(alpha: 0.1),
      confirmLabel: confirmLabel ?? 'Close',
      onConfirm: onConfirm,
    );
  }

  /// Show warning dialog
  static Future<bool?> warning({
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    return _showDialog(
      title: title,
      message: message,
      icon: Icons.warning_amber_rounded,
      iconColor: AppTokens.colors.warning,
      headerBackgroundColor: AppTokens.colors.warning.withValues(alpha: 0.1),
      confirmLabel: confirmLabel ?? 'Continue',
      cancelLabel: cancelLabel ?? 'Cancel',
      onConfirm: onConfirm,
      onCancel: onCancel,
    );
  }

  /// Show confirm dialog
  ///
  /// Generic confirmation dialog with two actions
  static Future<bool?> confirm({
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) async {
    return _showDialog(
      title: title,
      message: message,
      icon: Icons.help_outline,
      iconColor: AppTokens.colors.info,
      headerBackgroundColor: AppTokens.colors.info.withValues(alpha: 0.1),
      confirmLabel: confirmLabel ?? 'Confirm',
      cancelLabel: cancelLabel ?? 'Cancel',
      onConfirm: onConfirm,
      onCancel: onCancel,
    );
  }

  /// Show info dialog
  static Future<bool?> info({
    required String title,
    required String message,
    String? confirmLabel,
    VoidCallback? onConfirm,
  }) {
    return _showDialog(
      title: title,
      message: message,
      icon: Icons.info_outline,
      iconColor: AppTokens.colors.info,
      headerBackgroundColor: AppTokens.colors.info.withValues(alpha: 0.1),
      confirmLabel: confirmLabel ?? 'Got it',
      onConfirm: onConfirm,
    );
  }

  /// Show loading dialog
  ///
  /// Non-dismissible loading dialog
  static Future<void> loading({required String message, String? title}) {
    final isMobile = Get.width < 600;
    final actualMaxWidth = isMobile ? Get.width * 0.75 : 280.0;

    return Get.dialog<void>(
      Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: actualMaxWidth,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTokens.colors.border.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.bgPage.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              if (title != null) ...[
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
      transitionCurve: Curves.easeOutCirc,
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Show custom dialog
  static Future<T?> custom<T>({
    required Widget content,
    String? title,
    String? confirmLabel,
    String? cancelLabel,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool barrierDismissible = true,
  }) {
    final isMobile = Get.width < 600;
    final actualMaxWidth = isMobile ? Get.width * 0.9 : 450.0;

    return Get.dialog<T>(
      Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: actualMaxWidth,
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTokens.colors.border.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.bgPage.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),

              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  title == null ? 24 : 0,
                  24,
                  24,
                ),
                child: content,
              ),

              if (confirmLabel != null || cancelLabel != null)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (cancelLabel != null)
                        TextButton(
                          onPressed: () {
                            Get.back(result: false);
                            onCancel?.call();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            cancelLabel,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      if (cancelLabel != null) const SizedBox(width: 8),
                      if (confirmLabel != null)
                        ElevatedButton(
                          onPressed: () {
                            Get.back(result: true);
                            onConfirm?.call();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            confirmLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      barrierDismissible: barrierDismissible,
      transitionCurve: Curves.easeOutCirc,
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Close current dialog
  static void close<T>([T? result]) {
    Get.back<T>(result: result);
  }

  /// Internal method for standard dialogs
  static Future<bool?> _showDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color headerBackgroundColor,
    required String confirmLabel,
    String? cancelLabel,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    final isMobile = Get.width < 600;
    final actualMaxWidth = isMobile ? Get.width * 0.85 : 360.0;

    return Get.dialog<bool>(
      Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: actualMaxWidth,
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTokens.colors.border.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.bgPage.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Premium Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: AppTokens.spacing.space24,
                  bottom: AppTokens.spacing.space16,
                ),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      headerBackgroundColor,
                      AppColors.bgSurface,
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 32, color: iconColor),
                  ),
                ),
              ),

              // Title and message
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTokens.spacing.space24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Padding(
                padding: EdgeInsets.only(
                  left: AppTokens.spacing.space20,
                  right: AppTokens.spacing.space20,
                  bottom: AppTokens.spacing.space20,
                ),
                child: Row(
                  children: [
                    if (cancelLabel != null) ...[
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Get.back(result: false);
                            onCancel?.call();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            cancelLabel,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back(result: true);
                          onConfirm?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          confirmLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      transitionCurve: Curves.easeOutCirc,
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
