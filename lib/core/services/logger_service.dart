import 'package:flutter/foundation.dart';

/// Structured logging service for production-grade observability
/// Implements industry standards for error tracking and debugging
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  static const String _tag = 'Truthworld';

  // Log levels ordered by severity
  static const int _levelVerbose = 2;
  static const int _levelDebug = 3;
  static const int _levelInfo = 4;
  static const int _levelWarning = 5;
  static const int _levelError = 6;
  static const int _levelWTF = 7;

  int _minLevel = _levelDebug;
  bool _enableCrashlytics = false;

  /// Crash reporting callback for Firebase Crashlytics integration
  void Function(Object error, StackTrace? stack)? onCrash;

  LoggerService._internal();

  factory LoggerService() {
    return _instance;
  }

  /// Initialize logger with configuration
  /// Set [enableCrashlytics] to true to automatically report to Firebase Crashlytics
  /// Set [minLogLevel] to control verbosity (2=verbose, 3=debug, 4=info, 5=warning, 6=error, 7=wtf)
  void init({
    bool enableCrashlytics = false,
    int minLogLevel = _levelDebug,
  }) {
    _enableCrashlytics = enableCrashlytics;
    _minLevel = minLogLevel.clamp(_levelVerbose, _levelWTF);
    info('❅ Logger initialized | Crashlytics: $_enableCrashlytics | Level: $minLogLevel');
  }

  /// Log verbose messages (for development only)
  void verbose(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      level: _levelVerbose,
      tag: tag ?? _tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      emoji: '🔍',
    );
  }

  /// Log debug messages
  void debug(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      level: _levelDebug,
      tag: tag ?? _tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      emoji: '🐛',
    );
  }

  /// Log info messages (general application flow)
  void info(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      level: _levelInfo,
      tag: tag ?? _tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      emoji: 'ℹ️',
    );
  }

  /// Log warning messages (potential issues)
  void warning(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      level: _levelWarning,
      tag: tag ?? _tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      emoji: '⚠️',
    );
  }

  /// Log error messages (recoverable errors)
  void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      level: _levelError,
      tag: tag ?? _tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      emoji: '❌',
    );

    // Report to crash analytics if enabled
    if (_enableCrashlytics && onCrash != null) {
      onCrash!(error ?? Exception(message), stackTrace);
    }
  }

  /// Log severe errors (critical failures)
  void wtf(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      level: _levelWTF,
      tag: tag ?? _tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      emoji: '💥',
    );

    // Always report WTF to crash analytics
    if (_enableCrashlytics && onCrash != null) {
      onCrash!(error ?? Exception(message), stackTrace);
    }
  }

  /// Log a performance metric
  void metric(String name, Duration duration, {String? tag}) {
    info('⏱️ METRIC: $name took ${duration.inMilliseconds}ms',
        tag: tag ?? 'PERF');
  }

  /// Log API request
  void logRequest(String method, String url, {dynamic body, String? tag}) {
    debug('📤 $method $url', tag: tag ?? 'API');
    if (body != null) {
      verbose('Request body: $body', tag: tag ?? 'API');
    }
  }

  /// Log API response
  void logResponse(
    String method,
    String url,
    int statusCode, {
    dynamic body,
    String? tag,
  }) {
    final emoji = statusCode >= 200 && statusCode < 300 ? '✅' : '⚠️';
    info('📥 $emoji $method $url [$statusCode]', tag: tag ?? 'API');
    if (body != null) {
      verbose('Response body: $body', tag: tag ?? 'API');
    }
  }

  /// Internal logging implementation
  void _log({
    required int level,
    required String tag,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    required String emoji,
  }) {
    if (level < _minLevel) return;

    // Build log message
    final buffer = StringBuffer();
    buffer.write('$emoji [$tag] $message');

    if (error != null) {
      buffer.write('\n❯ Error: $error');
    }

    if (stackTrace != null && level >= _levelError) {
      buffer.write('\n❯ Stack: ${_formatStackTrace(stackTrace)}');
    }

    // Output to console
    if (kDebugMode) {
      debugPrint(buffer.toString());
    }
  }

  /// Format stack trace for readability
  String _formatStackTrace(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n');
    // Return first few meaningful lines
    return lines.take(3).join('\n   ');
  }
}

/// Global logger instance for easy access
final logger = LoggerService();





