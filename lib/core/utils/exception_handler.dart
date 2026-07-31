/// Enhanced exception handling utilities for consistent error reporting
/// Implements industry standards for exception handling and logging
library;

import 'package:truthworld/core/services/logger_service.dart';

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
      logger.error(
        'Error in ${name ?? 'operation'}',
        tag: tag,
        error: e,
        stackTrace: stackTrace,
      );
      onError?.call(e, stackTrace);
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
      logger.error(
        'Error in ${name ?? 'operation'}',
        tag: tag,
        error: e,
        stackTrace: stackTrace,
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
    logger.error(
      '$context failed',
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Validate input and return cleaned value or throw structured exception
class ValidationException implements Exception {
  ValidationException({
    required this.fieldName,
    required this.message,
  });
  final String fieldName;
  final String message;

  @override
  String toString() => 'Validation Error on $fieldName: $message';
}

class AppException implements Exception {
  AppException({
    required this.message,
    this.code,
    this.originalException,
    this.stackTrace,
  });
  final String message;
  final String? code;
  final Object? originalException;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
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
