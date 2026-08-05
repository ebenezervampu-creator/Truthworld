import 'dart:async';
import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/services/logger_service.dart';

/// Global centralized error handler setup for Truthworld apps.
void setupGlobalErrorHandlers() {
  // 1. Flutter framework error handler
  FlutterError.onError = (details) {
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
      logger.error(
        'Flutter Framework Error',
        error: details.exception,
        stackTrace: details.stack,
        tag: 'FlutterFramework',
      );
    } else if (!kIsWeb) {
      final errorStr = details.exception.toString();
      final isTransient = _isTransientError(details.exception, errorStr);

      if (isTransient) {
        unawaited(
          FirebaseCrashlytics.instance.recordError(
            details.exception,
            details.stack,
            reason: 'Transient framework error: ${details.summary}',
          ),
        );
      } else {
        unawaited(
          FirebaseCrashlytics.instance.recordFlutterFatalError(details),
        );
      }
    }
  };

  // 2. Uncaught async error handler across all Dart zones & isolates
  PlatformDispatcher.instance.onError = (error, stack) {
    final errorStr = error.toString();
    final isTransient = _isTransientError(error, errorStr);

    if (kDebugMode) {
      debugPrint('[GlobalErrorHandler] ${isTransient ? "Handled transient" : "Caught uncaught"} error: $error');
      if (!isTransient) debugPrintStack(stackTrace: stack);
    } else if (!kIsWeb) {
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          reason: isTransient ? 'Transient async error' : 'Uncaught async error',
          fatal: !isTransient,
        ),
      );
    }

    // Return true to mark exception as handled and prevent app crash
    return true;
  };
}

/// Checks if an error is a transient background/network/player lifecycle error
/// that should not crash the user's application session.
bool _isTransientError(Object error, String errorStr) {
  if (error is SocketException ||
      errorStr.contains('SocketException') ||
      errorStr.contains('Failed host lookup') ||
      errorStr.contains('Connection refused') ||
      errorStr.contains('Network is unreachable') ||
      errorStr.contains('Software caused connection abort') ||
      errorStr.contains('Connection closed before full header was received') ||
      errorStr.contains('HttpException') ||
      errorStr.contains('HandshakeException')) {
    return true;
  }

  if (errorStr.contains('No active player with ID') ||
      errorStr.contains('AndroidVideoPlayer._playerWith') ||
      errorStr.contains('VideoPlayerController')) {
    return true;
  }

  if (errorStr.contains('Bad state: Too many elements') ||
      errorStr.contains('ScrollController attached to multiple scroll views')) {
    return true;
  }

  return false;
}
