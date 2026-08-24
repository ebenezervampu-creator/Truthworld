import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/widgets/global_error_boundary.dart';

/// Global centralized error handler setup for Truthworld apps.
void setupGlobalErrorHandlers() {
  // 1. Custom UI Error Boundary (replaces default red/grey screen)
  ErrorWidget.builder = (details) {
    return GlobalErrorBoundary(details: details);
  };

  // 2. Flutter framework error handler
  FlutterError.onError = (details) {
    final errorStr = details.exception.toString();
    final isTransient = _isTransientError(details.exception, errorStr);

    if (kDebugMode) {
      if (!isTransient) {
        try {
          FlutterError.dumpErrorToConsole(details);
        } catch (_) {
          debugPrint('[FlutterError] ${details.exceptionAsString()}');
        }
        logger.error(
          'Flutter Framework Error',
          error: details.exception,
          stackTrace: details.stack,
          tag: 'FlutterFramework',
        );
      }
    } else {
      ErrorHandler.log(
        details.exception,
        stackTrace: details.stack,
        tag: 'FlutterFramework',
        isFatal: !isTransient,
      );
    }
  };

  // 3. Uncaught async error handler across all Dart zones & isolates
  PlatformDispatcher.instance.onError = (error, stack) {
    final errorStr = error.toString();
    final isTransient = _isTransientError(error, errorStr);

    if (kDebugMode) {
      if (!isTransient) {
        debugPrint('[GlobalErrorHandler] Caught uncaught error: $error');
        debugPrintStack(stackTrace: stack);
      }
    } else {
      ErrorHandler.log(
        error,
        stackTrace: stack,
        tag: 'AsyncZone',
        isFatal: !isTransient,
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
      errorStr.contains('ScrollController attached to multiple scroll views') ||
      errorStr.contains('_handledContextLostEvent') ||
      errorStr.contains('MissingPluginException') ||
      errorStr.contains('engine/window.dart') ||
      errorStr.contains('LegacyJavaScriptObject') ||
      errorStr.contains('DiagnosticsNode') ||
      errorStr.contains('debugTransformDebugCreator')) {
    return true;
  }

  return false;
}
