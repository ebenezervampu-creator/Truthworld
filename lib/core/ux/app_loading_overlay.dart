import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Standardized loading overlay for async operations.
///
/// Usage:
/// ```dart
/// AppLoadingOverlay.show(message: 'Loading video...');
/// await doWork();
/// AppLoadingOverlay.dismiss();
/// ```
class AppLoadingOverlay {
  AppLoadingOverlay._();

  static Timer? _safetyTimer;

  /// Show a branded loading overlay.
  ///
  /// [message] — optional message displayed below the spinner.
  /// [safetyTimeout] — auto-dismiss after this duration to prevent stuck overlays.
  static void show({
    String? message,
    Duration safetyTimeout = const Duration(seconds: 15),
  }) {
    // Cancel any previous safety timer
    _safetyTimer?.cancel();

    // Auto-dismiss safety net
    _safetyTimer = Timer(safetyTimeout, () {
      dismiss();
    });

    Get.dialog(
      PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.brand.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.brand,
                    ),
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
    );
  }

  /// Dismiss the loading overlay if one is showing.
  static void dismiss() {
    _safetyTimer?.cancel();
    _safetyTimer = null;
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }
}
