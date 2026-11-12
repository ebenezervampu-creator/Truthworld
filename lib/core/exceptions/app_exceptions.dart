import 'dart:async' as async;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/services.dart';

/// Severity level of an application exception for logging and analytics triage
enum ErrorSeverity {
  info,
  warning,
  error,
  fatal,
}

/// Base class for all application-specific exceptions in Truthworld.
/// Provides structured error codes, user-friendly messages, retry policies,
/// severity classification, and automatic translation from native/runtime exceptions.
abstract class AppException implements Exception {
  const AppException({
    required this.message,
    this.userMessage,
    this.code = 'UNKNOWN_ERROR',
    this.isRetryable = false,
    this.severity = ErrorSeverity.error,
    this.originalException,
    this.stackTrace,
  });

  /// Technical message for developers and diagnostics
  final String message;

  /// Human-friendly, non-technical message suitable for user display
  final String? userMessage;

  /// Standardized alphanumeric error code (e.g., 'NETWORK_OFFLINE', 'AUTH_EXPIRED')
  final String code;

  /// Whether the failed operation can be retried safely
  final bool isRetryable;

  /// The severity of this error for triage and monitoring
  final ErrorSeverity severity;

  /// The underlying platform, network, or runtime exception (if any)
  final dynamic originalException;

  /// Preserved stack trace for debugging
  final StackTrace? stackTrace;

  /// Returns the best message for user-facing display
  String get displayMessage => userMessage ?? message;

  @override
  String toString() => '[$code] $runtimeType: $message';

  /// Intelligent factory that parses ANY runtime error, Firebase exception,
  /// SocketException, PlatformException, or format error into a typed [AppException].
  factory AppException.from(
    Object error, [
    StackTrace? stackTrace,
    String? fallbackMessage,
  ]) {
    if (error is AppException) {
      return error;
    }

    final errorStr = error.toString();

    // 1. Network & Timeout Exceptions
    if (error is SocketException ||
        errorStr.contains('SocketException') ||
        errorStr.contains('Failed host lookup') ||
        errorStr.contains('Network is unreachable') ||
        errorStr.contains('Connection refused') ||
        errorStr.contains('Connection closed before full header was received') ||
        errorStr.contains('Software caused connection abort') ||
        error is HttpException ||
        error is HandshakeException) {
      return NetworkException(
        message: errorStr,
        userMessage: 'You appear to be offline. Please check your internet connection and try again.',
        code: 'NETWORK_OFFLINE',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    if (error is async.TimeoutException ||
        errorStr.contains('TimeoutException') ||
        errorStr.contains('timed out')) {
      return NetworkException(
        message: errorStr,
        userMessage: 'The request took too long to complete. Please check your connection and try again.',
        code: 'NETWORK_TIMEOUT',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // 2. Firebase Auth Exceptions
    if (error is fb_auth.FirebaseAuthException) {
      return AuthException.fromFirebaseAuth(error, stackTrace);
    }

    // 3. Firestore / Firebase Cloud Storage Exceptions
    if (error is FirebaseException) {
      return _mapFirebaseException(error, stackTrace);
    }

    // 4. Platform & Native Channel Exceptions
    if (error is PlatformException) {
      return PlatformBridgeException.fromPlatformException(error, stackTrace);
    }

    // 5. Format & Data Parsing Exceptions
    if (error is FormatException || errorStr.contains('FormatException')) {
      return ValidationException(
        message: errorStr,
        userMessage: 'Unable to process data due to an invalid format.',
        code: 'DATA_FORMAT_ERROR',
        originalException: error,
        stackTrace: stackTrace,
      );
    }

    // 6. HTTP / Server 5xx status codes
    final statusMatch = RegExp(r'status\s*([45]\d{2})', caseSensitive: false).firstMatch(errorStr);
    if (statusMatch != null) {
      final statusCode = int.tryParse(statusMatch.group(1) ?? '');
      if (statusCode != null && statusCode >= 500) {
        return ServerException(
          message: errorStr,
          statusCode: statusCode,
          originalException: error,
          stackTrace: stackTrace,
        );
      }
    }

    // 7. Generic Fallback
    return GenericAppException(
      message: fallbackMessage ?? errorStr,
      userMessage: fallbackMessage ?? 'An unexpected error occurred. Please try again.',
      originalException: error,
      stackTrace: stackTrace,
    );
  }

  static AppException _mapFirebaseException(
    FirebaseException e,
    StackTrace? stackTrace,
  ) {
    switch (e.code.toLowerCase()) {
      case 'permission-denied':
        return PermissionException(
          message: e.message ?? 'Permission denied to access this resource.',
          userMessage: 'You do not have permission to perform this action.',
          originalException: e,
          stackTrace: stackTrace,
        );
      case 'not-found':
        return NotFoundException(
          message: e.message ?? 'Requested document or resource was not found.',
          userMessage: 'The requested item could not be found.',
          code: 'RESOURCE_NOT_FOUND',
          originalException: e,
          stackTrace: stackTrace,
        );
      case 'unavailable':
        return NetworkException(
          message: e.message ?? 'Firebase service is currently unavailable.',
          userMessage: 'The server is temporarily unavailable. Please try again in a moment.',
          code: 'SERVICE_UNAVAILABLE',
          originalException: e,
          stackTrace: stackTrace,
        );
      case 'internal':
      case 'unknown':
        return ServerException(
          message: e.message ?? 'Internal server error.',
          userMessage: 'The service is temporarily unavailable. Please try again in a moment.',
          code: 'SERVICE_UNAVAILABLE',
          originalException: e,
          stackTrace: stackTrace,
        );
      case 'already-exists':
        return ValidationException(
          message: e.message ?? 'Document already exists.',
          userMessage: 'This item already exists.',
          code: 'RESOURCE_ALREADY_EXISTS',
          originalException: e,
          stackTrace: stackTrace,
        );
      case 'resource-exhausted':
      case 'quota-exceeded':
        return ServerException(
          message: e.message ?? 'Quota exceeded or resource exhausted.',
          userMessage: 'Server limit reached. Please try again shortly.',
          code: 'QUOTA_EXHAUSTED',
          originalException: e,
          stackTrace: stackTrace,
        );
      case 'unauthenticated':
        return AuthException(
          message: e.message ?? 'User is unauthenticated.',
          userMessage: 'Please sign in to continue.',
          code: 'UNAUTHENTICATED',
          originalException: e,
          stackTrace: stackTrace,
        );
      default:
        if (e.plugin == 'firebase_storage') {
          return StorageException(
            message: e.message ?? 'Storage error: ${e.code}',
            userMessage: 'Failed to upload or download file. Please try again.',
            code: 'STORAGE_${e.code.toUpperCase()}',
            originalException: e,
            stackTrace: stackTrace,
          );
        }
        if (e.plugin == 'cloud_functions' || e.toString().contains('FirebaseFunctionsException')) {
          return ServerException(
            message: e.message ?? 'Cloud functions error: ${e.code}',
            userMessage: 'The service is temporarily unavailable. Please try again in a moment.',
            code: 'FUNCTIONS_${e.code.toUpperCase()}',
            originalException: e,
            stackTrace: stackTrace,
          );
        }
        return FirestoreException(
          message: e.message ?? 'Firestore error [${e.code}]',
          userMessage: 'Unable to complete the operation. Please try again.',
          code: 'FIRESTORE_${e.code.toUpperCase()}',
          originalException: e,
          stackTrace: stackTrace,
        );
    }
  }
}

/// Network connectivity, DNS, HTTP, or timeout exception
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.userMessage,
    super.code = 'NETWORK_ERROR',
    super.isRetryable = true,
    super.severity = ErrorSeverity.warning,
    super.originalException,
    super.stackTrace,
  });
}

/// Authentication and session exception
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.userMessage,
    super.code = 'AUTH_ERROR',
    super.isRetryable = false,
    super.severity = ErrorSeverity.error,
    super.originalException,
    super.stackTrace,
  });

  factory AuthException.fromFirebaseAuth(
    fb_auth.FirebaseAuthException e,
    StackTrace? stackTrace,
  ) {
    String userMsg;
    var isRetryable = false;

    switch (e.code) {
      case 'network-request-failed':
        userMsg = 'Network error during authentication. Please check your internet connection.';
        isRetryable = true;
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        userMsg = 'Invalid email or password. Please verify your credentials.';
      case 'user-disabled':
        userMsg = 'This account has been suspended or disabled.';
      case 'email-already-in-use':
        userMsg = 'An account already exists with this email address.';
      case 'weak-password':
        userMsg = 'Password is too weak. Please choose a stronger password.';
      case 'too-many-requests':
        userMsg = 'Too many failed attempts. Please wait a few minutes before trying again.';
        isRetryable = true;
      case 'operation-not-allowed':
        userMsg = 'This sign-in method is currently disabled.';
      case 'requires-recent-login':
        userMsg = 'This sensitive action requires you to re-authenticate.';
      default:
        userMsg = e.message ?? 'Authentication failed. Please try again.';
    }

    return AuthException(
      message: e.message ?? 'FirebaseAuthException: ${e.code}',
      userMessage: userMsg,
      code: 'AUTH_${e.code.toUpperCase().replaceAll('-', '_')}',
      isRetryable: isRetryable,
      originalException: e,
      stackTrace: stackTrace,
    );
  }

  /// Get user-friendly display message for backwards compatibility
  String getDisplayMessage() => displayMessage;
}

/// Google Sign-In specific exception
class GoogleSignInException extends AuthException {
  const GoogleSignInException({
    required super.message,
    super.userMessage,
    super.code = 'GOOGLE_SIGNIN_ERROR',
    super.isRetryable = false,
    super.originalException,
    super.stackTrace,
  });
}

/// Thrown when the user cancels the Google Sign-In flow
class GoogleSignInUserCancelledException extends AuthException {
  const GoogleSignInUserCancelledException([
    String message = 'User cancelled sign-in',
  ]) : super(
         message: message,
         userMessage: 'Sign-in was cancelled.',
         code: 'GOOGLE_SIGNIN_CANCELLED',
         isRetryable: true,
         severity: ErrorSeverity.info,
       );
}

/// Thrown when Google Sign-In fails due to technical reasons
class GoogleSignInFailedException extends AuthException {
  const GoogleSignInFailedException([
    String? message,
    StackTrace? stackTrace,
  ]) : super(
         message: message ?? 'Google Sign-In failed',
         userMessage: 'Unable to sign in with Google. Please try again.',
         code: 'GOOGLE_SIGNIN_FAILED',
         isRetryable: true,
         stackTrace: stackTrace,
       );
}

/// Apple Sign-In specific exception
class AppleSignInException extends AuthException {
  const AppleSignInException({
    required super.message,
    super.userMessage,
    super.code = 'APPLE_SIGNIN_ERROR',
    super.isRetryable = false,
    super.originalException,
    super.stackTrace,
  });
}

/// Phone Authentication specific exception
class PhoneAuthException extends AuthException {
  const PhoneAuthException({
    required super.message,
    super.userMessage,
    super.code = 'PHONE_AUTH_ERROR',
    super.isRetryable = false,
    super.originalException,
    super.stackTrace,
  });
}

/// Resource not found (404) exception
class NotFoundException extends AppException {
  const NotFoundException({
    required super.message,
    super.userMessage = 'The requested content could not be found.',
    super.code = 'NOT_FOUND',
    super.isRetryable = false,
    super.severity = ErrorSeverity.warning,
    super.originalException,
    super.stackTrace,
  });
}

/// Form or input validation error
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.userMessage,
    super.code = 'VALIDATION_ERROR',
    super.isRetryable = false,
    super.severity = ErrorSeverity.warning,
    super.originalException,
    super.stackTrace,
    this.fieldName,
  });

  final String? fieldName;
}

/// Video/Audio playback, decoding, transcoding, or media capture exception
class MediaException extends AppException {
  const MediaException({
    required super.message,
    super.userMessage = 'Unable to play or process this media file.',
    super.code = 'MEDIA_ERROR',
    super.isRetryable = true,
    super.severity = ErrorSeverity.error,
    super.originalException,
    super.stackTrace,
  });
}

/// Cloud Storage, upload, download, or file caching exception
class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.userMessage = 'File storage operation failed. Please try again.',
    super.code = 'STORAGE_ERROR',
    super.isRetryable = true,
    super.severity = ErrorSeverity.error,
    super.originalException,
    super.stackTrace,
  });
}

/// Device or resource permissions exception (Camera, Mic, Storage, Notifications)
class PermissionException extends AppException {
  const PermissionException({
    required super.message,
    super.userMessage = 'Permission is required to perform this action.',
    super.code = 'PERMISSION_DENIED',
    super.isRetryable = false,
    super.severity = ErrorSeverity.warning,
    super.originalException,
    super.stackTrace,
    this.permissionName,
  });

  final String? permissionName;
}

/// Native platform bridge or plugin failure (e.g., ActivityNotFoundException)
class PlatformBridgeException extends AppException {
  const PlatformBridgeException({
    required super.message,
    super.userMessage = 'A device component error occurred. Please ensure required apps are installed.',
    super.code = 'PLATFORM_BRIDGE_ERROR',
    super.isRetryable = false,
    super.severity = ErrorSeverity.error,
    super.originalException,
    super.stackTrace,
  });

  factory PlatformBridgeException.fromPlatformException(
    PlatformException e,
    StackTrace? stackTrace,
  ) {
    var userMsg = 'A platform service error occurred.';
    var isRetryable = false;

    if (e.message != null && e.message!.contains('ActivityNotFoundException')) {
      userMsg = 'No compatible application or component found on your device to perform this action.';
    } else if (e.code == 'camera_access_denied') {
      userMsg = 'Camera access was denied. Please grant permission in device settings.';
    } else if (e.code == 'photo_access_denied') {
      userMsg = 'Photos access was denied. Please grant permission in device settings.';
    } else if (e.code.contains('MEDIA_ERR_SRC_NOT_SUPPORTED')) {
      userMsg = 'Video stream format is not supported by your browser or device.';
      isRetryable = true;
    }

    return PlatformBridgeException(
      message: '${e.code}: ${e.message ?? "No message"}',
      userMessage: userMsg,
      code: 'PLATFORM_${e.code.toUpperCase().replaceAll('-', '_')}',
      isRetryable: isRetryable,
      originalException: e,
      stackTrace: stackTrace,
    );
  }
}

/// Firestore database operation exception
class FirestoreException extends AppException {
  const FirestoreException({
    required super.message,
    super.userMessage = 'Database operation failed. Please try again.',
    super.code = 'FIRESTORE_ERROR',
    super.isRetryable = true,
    super.severity = ErrorSeverity.error,
    super.originalException,
    super.stackTrace,
  });

  factory FirestoreException.fromFirebase(FirebaseException e) {
    return FirestoreException(
      message: e.message ?? 'Firestore error [${e.code}]',
      code: 'FIRESTORE_${e.code.toUpperCase()}',
      originalException: e,
    );
  }
}

/// Server, Cloud Function, or backend 5xx exception
class ServerException extends AppException {
  const ServerException({
    required super.message,
    super.userMessage = 'The service is temporarily unavailable. Please try again shortly.',
    super.code = 'SERVER_ERROR',
    super.isRetryable = true,
    super.severity = ErrorSeverity.error,
    super.originalException,
    super.stackTrace,
    this.statusCode,
  });

  final int? statusCode;
}

/// Generic application fallback exception
class GenericAppException extends AppException {
  const GenericAppException({
    required super.message,
    super.userMessage = 'An unexpected error occurred. Please try again.',
    super.code = 'GENERIC_ERROR',
    super.isRetryable = true,
    super.severity = ErrorSeverity.error,
    super.originalException,
    super.stackTrace,
  });
}

/// Thrown when an asynchronous operation is explicitly cancelled
class OperationCancelledException extends AppException {
  const OperationCancelledException([
    String message = 'Operation was cancelled',
  ]) : super(
         message: message,
         userMessage: 'Operation cancelled.',
         code: 'OPERATION_CANCELLED',
         isRetryable: false,
         severity: ErrorSeverity.info,
       );
}

/// Custom Exception wrapper for user profile errors
class UserProfileException extends AppException {
  const UserProfileException({
    required super.message,
    super.userMessage = 'Unable to update profile. Please try again.',
    super.code = 'USER_PROFILE_ERROR',
    super.originalException,
    super.stackTrace,
    this.userId,
  });

  final String? userId;
}

/// TimeoutException custom wrapper for async cancellation
class AppTimeoutException extends NetworkException {
  const AppTimeoutException({
    required super.message,
    super.userMessage = 'The operation timed out. Please try again.',
    super.code = 'OPERATION_TIMEOUT',
    super.originalException,
    super.stackTrace,
  });
}

/// Alias for AppTimeoutException for backwards compatibility
typedef TimeoutException = AppTimeoutException;

/// Legacy helper for backwards compatibility
class FriendlyErrorTranslator {
  static String getFriendlyMessage(
    Object error, {
    String? defaultActionMessage,
  }) {
    final appException = AppException.from(error);
    if (defaultActionMessage != null && appException is GenericAppException) {
      return 'Failed to $defaultActionMessage. Please try again.';
    }
    return appException.displayMessage;
  }
}
