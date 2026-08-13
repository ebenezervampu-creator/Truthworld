/// Enhanced exception handling utilities for consistent error reporting.
/// Implements industry standards for exception handling and logging.
library;

import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/logger_service.dart';

export 'package:truthworld/core/errors/error_handler.dart';
export 'package:truthworld/core/exceptions/app_exceptions.dart';

/// Exception handler mixin for controllers and services
mixin ExceptionHandlerMixin {
  /// Wrap an async operation with exception handling
  /// Returns `Future<T>` or null on error
  Future<T?> safeExecute<T>(
    Future<T> Function() operation, {
    String? name,
    String? tag,
    bool shouldRethrow = false,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    try {
      final result = await operation();
      if (name != null) {
        logger.info('✓ $name completed successfully', tag: tag);
      }
      return result;
    } catch (e, stackTrace) {
      final appException = ErrorHandler.handle(
        e,
        stackTrace: stackTrace,
        tag: tag,
        showFeedback: false,
      );
      onError?.call(appException, stackTrace);
      if (shouldRethrow) rethrow;
      return null;
    }
  }

  /// Execute a synchronous operation with exception handling
  T? safeExecuteSync<T>(
    T Function() operation, {
    String? name,
    String? tag,
    bool shouldRethrow = false,
  }) {
    try {
      final result = operation();
      if (name != null) {
        logger.debug('✓ $name completed successfully', tag: tag);
      }
      return result;
    } catch (e, stackTrace) {
      ErrorHandler.handle(
        e,
        stackTrace: stackTrace,
        tag: tag,
        showFeedback: false,
      );
      if (shouldRethrow) rethrow;
      return null;
    }
  }

  /// Handle and log an exception with context
  void handleException(
    Object error,
    StackTrace? stackTrace, {
    String context = 'Operation',
    String? tag,
  }) {
    ErrorHandler.handle(
      error,
      stackTrace: stackTrace,
      tag: tag,
      showFeedback: false,
    );
  }
}

/// Time an operation and log the duration
class PerformanceTimer {
  PerformanceTimer(this.name, {this.tag});
  final String name;
  final String? tag;
  final DateTime _startTime = DateTime.now();

  /// Finish timing and log
  void finish({String? additional}) {
    final duration = DateTime.now().difference(_startTime);
    var message = '⏱️ $name: ${duration.inMilliseconds}ms';
    if (additional != null) message += ' ($additional)';

    if (duration.inMilliseconds > 1000) {
      logger.warning(message, tag: tag ?? 'PERF');
    } else {
      logger.info(message, tag: tag ?? 'PERF');
    }
  }

  /// Log as debug
  void debug() {
    final duration = DateTime.now().difference(_startTime);
    logger.debug(
      '⏱️ $name: ${duration.inMilliseconds}ms',
      tag: tag ?? 'PERF',
    );
  }
}
