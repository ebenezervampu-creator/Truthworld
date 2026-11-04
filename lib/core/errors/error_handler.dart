import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/ux/app_toast.dart';
import 'package:truthworld/core/ux/user_feedback_sanitizer.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Centralized Industry-Standard Error Handling Service.
/// Unifies exception parsing, user-friendly UI presentation, rate-limiting,
/// and analytics/Crashlytics reporting.
class ErrorHandler {
  ErrorHandler._();

  static DateTime _lastSnackbarTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
  static String? _lastSnackbarMessage;

  /// Minimum duration between duplicate snackbars to prevent UI spamming
  static const Duration _snackbarDebounceInterval = Duration(milliseconds: 1800);

  /// Handle any error cleanly with optional logging, user feedback, and retry action.
  static AppException handle(
    Object error, {
    StackTrace? stackTrace,
    String? tag,
    BuildContext? context,
    bool showFeedback = true,
    VoidCallback? onRetry,
  }) {
    final appException = AppException.from(error, stackTrace);

    // 1. Log with diagnostics & Crashlytics
    log(appException, stackTrace: stackTrace, tag: tag);

    // 2. Present user feedback if requested
    if (showFeedback && appException.severity != ErrorSeverity.info) {
      if (context != null && context.mounted) {
        showErrorDialog(context, appException, onRetry: onRetry);
      } else {
        showSnackbar(appException, onRetry: onRetry);
      }
    }

    return appException;
  }

  /// Log exception to [LoggerService] and dispatch to [FirebaseCrashlytics] (on non-web).
  static void log(
    Object? error, {
    StackTrace? stackTrace,
    String? tag,
    String? context,
    String? reason,
    bool isFatal = false,
  }) {
    if (error == null) return;
    final appException = AppException.from(error, stackTrace);
    final trace = stackTrace ?? appException.stackTrace ?? StackTrace.current;
    final logTag = tag ?? context ?? reason ?? 'ErrorHandler';

    switch (appException.severity) {
      case ErrorSeverity.info:
        logger.info(
          '[${appException.code}] ${appException.message}',
          tag: logTag,
        );
      case ErrorSeverity.warning:
        logger.warning(
          '[${appException.code}] ${appException.message}',
          tag: logTag,
        );
      case ErrorSeverity.error:
      case ErrorSeverity.fatal:
        logger.error(
          '[${appException.code}] ${appException.message}',
          error: appException.originalException ?? appException,
          stackTrace: trace,
          tag: logTag,
        );
    }

    // Record non-transient, actionable errors in Firebase Crashlytics on supported platforms.
    // Exclude informational/warning diagnostics and transient network drops/timeouts to prevent
    // Crashlytics quota exhaustion and false crash metrics.
    final isCrashlyticsSupported = !kIsWeb &&
        !Platform.environment.containsKey('FLUTTER_TEST') &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    final isActionableError = isFatal ||
        appException.severity == ErrorSeverity.fatal ||
        (appException.severity == ErrorSeverity.error &&
            appException is! NetworkException);

    if (isCrashlyticsSupported &&
        isActionableError &&
        Firebase.apps.isNotEmpty) {
      try {
        unawaited(
          FirebaseCrashlytics.instance
              .recordError(
                appException.originalException ?? appException,
                trace,
                reason: '[${appException.code}] ${appException.message}',
                fatal: isFatal || appException.severity == ErrorSeverity.fatal,
              )
              .catchError((e, s) {
                logger.warning('Crashlytics async record error: $e', tag: 'ErrorHandler');
              }),
        );
      } catch (e) {
        logger.warning('Crashlytics uninitialized fallback: $e', tag: 'ErrorHandler');
      }
    }
  }

  /// Display a sleek, modern, rate-limited snackbar with human-friendly message and retry action.
  static void showSnackbar(
    Object error, {
    VoidCallback? onRetry,
  }) {
    final appException = AppException.from(error);
    final userMessage = UserFeedbackSanitizer.sanitizeMessage(appException.displayMessage);
    final now = DateTime.now();

    // Prevent spamming identical snackbars in rapid succession
    if (_lastSnackbarMessage == userMessage &&
        now.difference(_lastSnackbarTimestamp) < _snackbarDebounceInterval) {
      return;
    }

    _lastSnackbarTimestamp = now;
    _lastSnackbarMessage = userMessage;

    if (Get.context == null) {
      debugPrint('[ErrorHandler] Snackbar suppressed (no active context): $userMessage');
      return;
    }

    AppToast.error(
      userMessage,
      onAction: (onRetry != null || appException.isRetryable) ? onRetry : null,
      actionLabel: (onRetry != null || appException.isRetryable) ? 'Retry' : null,
    );
  }

  /// Display a modal error dialog with action triggers.
  static void showErrorDialog(
    BuildContext context,
    Object error, {
    VoidCallback? onRetry,
  }) {
    final appException = AppException.from(error);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.bgDivider),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white, // Rule: Icons must be white
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  appException is NetworkException ? 'Connection Issue' : 'Notice',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            UserFeedbackSanitizer.sanitizeMessage(appException.displayMessage),
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Dismiss',
                style: AppTextStyles.buttonText.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (onRetry != null || appException.isRetryable)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onRetry?.call();
                },
                child: const Text('Try Again'),
              ),
          ],
        );
      },
    );
  }
}
